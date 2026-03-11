#include "lua_state_capture.h"
#include "logger.h"
#include <Windows.h>
#include <atomic>

// MinHook
#include "vendor/MinHook/MinHook.h"

static lua_State*       s_luaState = nullptr;
static HANDLE           s_readyEvent = nullptr;
static std::atomic<bool> s_captured{false};
static bool              s_hookInstalled = false;

static LuaStateCapture::PostPcallCallback s_postPcallCallback = nullptr;

// Track which hooks are installed so we can remove them
struct HookEntry {
    void* target;
    const char* name;
    bool installed;
};
static constexpr int MAX_HOOKS = 16;
static HookEntry s_hooks[MAX_HOOKS] = {};
static int s_hookCount = 0;

static std::atomic<int> s_interceptCount{0};
static std::atomic<int> s_pcallkCount{0};
static std::atomic<int> s_callkCount{0};

// Re-entrancy guard: prevents callback from firing when our own code
// calls lua_pcallk/lua_callk (e.g. from CallOriginal or OnPostPcall).
// Uses thread-local storage since hooks run on the game thread.
static thread_local int s_callDepth = 0;

// Capture state helper — called from any hooked function
static void CaptureState(lua_State* L, const char* source) {
    if (!s_captured.exchange(true)) {
        s_luaState = L;
        Log::Info("Lua state captured via %s: %p", source, L);
        if (s_readyEvent) {
            SetEvent(s_readyEvent);
        }
    }
}

// ============================================================
// Hook trampolines — intercept the engine's internal Lua functions
// ============================================================

// lua_pcallk(L, nargs, nresults, errfunc, ctx, k)
static fn_lua_pcallk s_originalPcallk = nullptr;
static int Hooked_lua_pcallk(lua_State* L, int nargs, int nresults, int errfunc,
                              intptr_t ctx, lua_KFunction k)
{
    CaptureState(L, "lua_pcallk");
    int count = ++s_pcallkCount;
    if (count == 1 || count == 100 || count == 1000 || (count % 10000 == 0)) {
        Log::Debug("lua_pcallk hook fired (count=%d)", count);
    }
    s_callDepth++;
    int result = s_originalPcallk(L, nargs, nresults, errfunc, ctx, k);
    s_callDepth--;

    // Only fire callback at top-level calls (not from our own Lua API usage)
    if (s_callDepth == 0) {
        auto cb = s_postPcallCallback;
        if (cb) {
            __try {
                cb(L);
            } __except(EXCEPTION_EXECUTE_HANDLER) {
                // Log but do NOT clear the callback — a single bad frame (e.g. a
                // coroutine state with a full stack) must not permanently disable
                // the callback. The main-state check in the callback guards us.
                static int s_exceptionCount = 0;
                if (++s_exceptionCount <= 10) {
                    Log::Error("Exception in PostPcallCallback (pcallk) #%d: 0x%08X (L=%p)",
                               s_exceptionCount, GetExceptionCode(), L);
                }
            }
        }
    }
    return result;
}

// lua_callk(L, nargs, nresults, ctx, k)
static fn_lua_callk s_originalCallk = nullptr;
static void Hooked_lua_callk(lua_State* L, int nargs, int nresults,
                              intptr_t ctx, lua_KFunction k)
{
    CaptureState(L, "lua_callk");
    int count = ++s_callkCount;
    if (count == 1 || count == 100 || count == 1000 || (count % 10000 == 0)) {
        Log::Debug("lua_callk hook fired (count=%d)", count);
    }
    s_callDepth++;
    s_originalCallk(L, nargs, nresults, ctx, k);
    s_callDepth--;

    // NOTE: Do NOT fire PostPcallCallback from callk.
    // lua_callk is an unprotected call — if it errors, it longjmps and never
    // returns here. When it DOES return, the stack may be in an unexpected state.
    // We only fire the callback from pcallk which has proper error handling and
    // a predictable post-call stack state.
}

// lua_getglobal — signature: void(lua_State*, const char*)
static fn_lua_getglobal s_originalGetglobal = nullptr;
static void Hooked_lua_getglobal(lua_State* L, const char* name)
{
    CaptureState(L, "lua_getglobal");
    s_originalGetglobal(L, name);
}

// ============================================================
// Pattern scanning — find functions inside EngineWin64s.dll
// ============================================================

// Search a memory region for a byte pattern
static void* ScanForPattern(void* start, size_t size, const unsigned char* pattern, size_t patternLen)
{
    unsigned char* p = (unsigned char*)start;
    unsigned char* end = p + size - patternLen;

    for (; p <= end; p++) {
        bool match = true;
        for (size_t j = 0; j < patternLen; j++) {
            if (p[j] != pattern[j]) {
                match = false;
                break;
            }
        }
        if (match) return (void*)p;
    }
    return nullptr;
}

// Get PE .text section info for a module
static bool GetTextSection(HMODULE hModule, void** outStart, size_t* outSize)
{
    auto* dosHeader = (IMAGE_DOS_HEADER*)hModule;
    if (dosHeader->e_magic != IMAGE_DOS_SIGNATURE) return false;

    auto* ntHeaders = (IMAGE_NT_HEADERS*)((unsigned char*)hModule + dosHeader->e_lfanew);
    if (ntHeaders->Signature != IMAGE_NT_SIGNATURE) return false;

    auto* section = IMAGE_FIRST_SECTION(ntHeaders);
    for (WORD i = 0; i < ntHeaders->FileHeader.NumberOfSections; i++) {
        if (memcmp(section[i].Name, ".text", 5) == 0) {
            *outStart = (unsigned char*)hModule + section[i].VirtualAddress;
            *outSize = section[i].Misc.VirtualSize;
            return true;
        }
    }
    return false;
}

// ============================================================
// Hook installation helper
// ============================================================
static bool InstallHookAt(void* target, const char* funcName, void* hookFunc, void** originalFunc)
{
    MH_STATUS status = MH_CreateHook(target, hookFunc, originalFunc);
    if (status != MH_OK) {
        Log::Warn("  %s: MH_CreateHook failed (%d)", funcName, status);
        return false;
    }

    status = MH_EnableHook(target);
    if (status != MH_OK) {
        Log::Warn("  %s: MH_EnableHook failed (%d)", funcName, status);
        MH_RemoveHook(target);
        return false;
    }

    if (s_hookCount < MAX_HOOKS) {
        s_hooks[s_hookCount] = { target, funcName, true };
        s_hookCount++;
    }

    Log::Info("  %s: hooked at %p", funcName, target);
    return true;
}

namespace LuaStateCapture {

bool InstallHook()
{
    if (s_hookInstalled) return true;

    // Create event for signaling state capture
    s_readyEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);

    // Initialize MinHook
    MH_STATUS status = MH_Initialize();
    if (status != MH_OK && status != MH_ERROR_ALREADY_INITIALIZED) {
        Log::Error("MH_Initialize failed: %d", status);
        return false;
    }

    // ============================================================
    // Strategy: Pattern-scan EngineWin64s.dll's .text section
    // for the engine's statically-linked Lua 5.2 functions.
    //
    // The engine has Lua compiled in — same compiler, same bytes
    // as lua52.dll. We use the first N bytes of each function body
    // (from lua52.dll) as search patterns.
    // ============================================================

    HMODULE hEngine = GetModuleHandleW(L"EngineWin64s.dll");
    if (!hEngine) {
        Log::Error("Cannot find EngineWin64s.dll — aborting");
        return false;
    }

    void* textStart = nullptr;
    size_t textSize = 0;
    if (!GetTextSection(hEngine, &textStart, &textSize)) {
        Log::Error("Cannot find .text section in EngineWin64s.dll");
        return false;
    }

    Log::Info("EngineWin64s.dll .text section: %p, size: 0x%zX (%zu KB)",
              textStart, textSize, textSize / 1024);

    // Patterns from lua52.dll real function bodies (first 16 bytes)
    // These are byte-identical in the engine's statically linked copy.

    // lua_pcallk: 48 89 74 24 18 57 48 83 EC 40 33 F6 48 89 6C 24
    static const unsigned char pat_pcallk[] = {
        0x48, 0x89, 0x74, 0x24, 0x18, 0x57, 0x48, 0x83,
        0xEC, 0x40, 0x33, 0xF6, 0x48, 0x89, 0x6C, 0x24
    };

    // lua_callk: 48 89 5C 24 08 57 48 83 EC 20 8D 42 01 48 8B D9
    static const unsigned char pat_callk[] = {
        0x48, 0x89, 0x5C, 0x24, 0x08, 0x57, 0x48, 0x83,
        0xEC, 0x20, 0x8D, 0x42, 0x01, 0x48, 0x8B, 0xD9
    };

    // lua_getglobal: 48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 57
    //               48 83 EC 20 48 8B 41 18 48 8B FA 48 8B E9 BA 02
    // Use 32 bytes to differentiate from lua_getfield
    static const unsigned char pat_getglobal[] = {
        0x48, 0x89, 0x5C, 0x24, 0x08, 0x48, 0x89, 0x6C,
        0x24, 0x10, 0x48, 0x89, 0x74, 0x24, 0x18, 0x57,
        0x48, 0x83, 0xEC, 0x20, 0x48, 0x8B, 0x41, 0x18,
        0x48, 0x8B, 0xFA, 0x48, 0x8B, 0xE9, 0xBA, 0x02
    };

    int hooked = 0;

    Log::Info("Scanning EngineWin64s.dll for Lua 5.2 function patterns:");

    // Find and hook lua_pcallk
    void* addr = ScanForPattern(textStart, textSize, pat_pcallk, sizeof(pat_pcallk));
    if (addr) {
        Log::Info("  lua_pcallk found at %p (offset 0x%zX)",
                  addr, (size_t)((unsigned char*)addr - (unsigned char*)hEngine));
        if (InstallHookAt(addr, "lua_pcallk",
                (void*)&Hooked_lua_pcallk, (void**)&s_originalPcallk))
            hooked++;
    } else {
        Log::Warn("  lua_pcallk pattern NOT FOUND in engine");
    }

    // Find and hook lua_callk
    addr = ScanForPattern(textStart, textSize, pat_callk, sizeof(pat_callk));
    if (addr) {
        Log::Info("  lua_callk found at %p (offset 0x%zX)",
                  addr, (size_t)((unsigned char*)addr - (unsigned char*)hEngine));
        if (InstallHookAt(addr, "lua_callk",
                (void*)&Hooked_lua_callk, (void**)&s_originalCallk))
            hooked++;
    } else {
        Log::Warn("  lua_callk pattern NOT FOUND in engine");
    }

    // Find and hook lua_getglobal (use 32-byte pattern to avoid matching lua_getfield)
    addr = ScanForPattern(textStart, textSize, pat_getglobal, sizeof(pat_getglobal));
    if (addr) {
        Log::Info("  lua_getglobal found at %p (offset 0x%zX)",
                  addr, (size_t)((unsigned char*)addr - (unsigned char*)hEngine));
        if (InstallHookAt(addr, "lua_getglobal",
                (void*)&Hooked_lua_getglobal, (void**)&s_originalGetglobal))
            hooked++;
    } else {
        Log::Warn("  lua_getglobal pattern NOT FOUND in engine");
    }

    if (hooked == 0) {
        Log::Error("Failed to hook any Lua functions in engine");
        return false;
    }

    s_hookInstalled = true;
    Log::Info("Installed %d hooks on engine-internal Lua functions — waiting for any to fire", hooked);
    return true;
}

void RemoveHook()
{
    if (s_hookInstalled) {
        for (int i = 0; i < s_hookCount; i++) {
            if (s_hooks[i].installed && s_hooks[i].target) {
                MH_DisableHook(s_hooks[i].target);
                MH_RemoveHook(s_hooks[i].target);
                s_hooks[i].installed = false;
            }
        }
        s_hookCount = 0;
        s_hookInstalled = false;
    }

    if (s_readyEvent) {
        CloseHandle(s_readyEvent);
        s_readyEvent = nullptr;
    }

    MH_Uninitialize();
}

bool WaitForState(DWORD timeoutMs)
{
    if (s_captured) return true;
    if (!s_readyEvent) return false;

    DWORD result = WaitForSingleObject(s_readyEvent, timeoutMs);
    return (result == WAIT_OBJECT_0);
}

lua_State* GetState()
{
    return s_luaState;
}

bool IsReady()
{
    return s_captured.load();
}

int GetInterceptCount()
{
    return s_interceptCount.load();
}

void SetPostPcallCallback(PostPcallCallback callback)
{
    s_postPcallCallback = callback;
}

fn_lua_pcallk    GetOriginalPcallk()    { return s_originalPcallk; }
fn_lua_callk     GetOriginalCallk()     { return s_originalCallk; }
fn_lua_getglobal GetOriginalGetglobal() { return s_originalGetglobal; }

}
