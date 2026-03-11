#include "lua_bindings.h"
#include "lua_state_capture.h"
#include "logger.h"
#include "path_resolver.h"
#include <Windows.h>
#include <Psapi.h>
#include <string>
#pragma comment(lib, "Psapi.lib")

LuaAPI lua;

static bool s_ready = false;
static HMODULE s_luaModule = nullptr;

// ============================================================
// Pattern scanning helpers (shared with lua_state_capture.cpp)
// ============================================================

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

// Follow JMP chains (E9 relative, FF 25 indirect) to find real function body
static void* FollowJumps(void* addr)
{
    unsigned char* p = (unsigned char*)addr;
    for (int i = 0; i < 8; i++) { // follow up to 8 jumps
        if (p[0] == 0xE9) {
            int32_t offset = *(int32_t*)(p + 1);
            p = p + 5 + offset;
            continue;
        }
        if (p[0] == 0xFF && p[1] == 0x25) {
            int32_t offset = *(int32_t*)(p + 2);
            void** target = (void**)(p + 6 + offset);
            p = (unsigned char*)*target;
            continue;
        }
        break;
    }
    return (void*)p;
}

// ============================================================
// Resolve a single Lua function from the engine
// ============================================================

// Read N prologue bytes from lua52.dll export (following JMP thunks),
// then find those bytes in EngineWin64s.dll .text section.
static void* FindEngineFunction(
    HMODULE hLuaDll,
    const char* exportName,
    void* engineTextStart,
    size_t engineTextSize,
    int patternLen = 16,
    bool verbose = true)
{
    // Get the export address from lua52.dll
    FARPROC exportAddr = GetProcAddress(hLuaDll, exportName);
    if (!exportAddr) {
        if (verbose) Log::Warn("  %s: not exported from lua52.dll", exportName);
        return nullptr;
    }

    // Follow JMP thunks to find the real function body
    void* realBody = FollowJumps((void*)exportAddr);

    // Read the first N bytes as a pattern
    unsigned char pattern[48];
    if (patternLen > 48) patternLen = 48;
    memcpy(pattern, realBody, patternLen);

    // Scan the engine's .text section for a match
    void* found = ScanForPattern(engineTextStart, engineTextSize, pattern, patternLen);
    if (!found) {
        // NOTE: Do NOT fall back to shorter patterns (e.g. 8 bytes).
        // Short patterns cause false matches — e.g. lua_pushcclosure matched
        // a completely unrelated engine function at offset 0x3E220 instead of
        // the real Lua function cluster at 0x377xxx-0x378xxx.
        if (verbose) Log::Warn("  %s: pattern not found in engine (tried %d bytes)", exportName, patternLen);
        return nullptr;
    }

    return found;
}

// ============================================================
// Public API
// ============================================================

namespace LuaBindings {

bool Init()
{
    if (s_ready) return true;

    static int s_attempts = 0;
    s_attempts++;
    bool verbose = (s_attempts == 1); // only log details on first attempt

    // Step 1: Verify EngineWin64s.dll is loaded (Phase 1 hooks run inside it).
    // We no longer scan its .text section — all engine functions come from the
    // Phase 1 MinHook trampolines stored in LuaStateCapture.
    if (!GetModuleHandleW(L"EngineWin64s.dll")) {
        if (verbose) Log::Debug("EngineWin64s.dll not found yet");
        return false;
    }

    // Step 2: Load lua52.dll for the FALLBACK_DLL functions (setglobal and everything
    // that is inlined / safe to use from the reference DLL).
    const std::wstring& exeDir = PathResolver::GetExecutableDir();
    if (exeDir.empty()) {
        if (verbose) Log::Debug("Exe directory not resolved yet");
        return false;
    }

    std::wstring luaPath = exeDir + L"\\lua52.dll";
    HMODULE hLuaDll = LoadLibraryW(luaPath.c_str());
    if (!hLuaDll) {
        if (verbose) Log::Warn("Cannot load lua52.dll: %lu", GetLastError());
        return false;
    }

    s_luaModule = hLuaDll; // keep for GetModule()

    if (verbose) {
        Log::Info("Resolving Lua API (Phase-1 trampolines + lua52.dll fallback):");
    }

    // Step 3: All engine functions are obtained via Phase 1 MinHook trampolines (below).
    //
    // We do NOT pattern-scan the engine using lua52.dll prologues for any function.
    // The engine and lua52.dll were compiled with different settings — their function
    // prologues differ, so every scan produces a false match against an unrelated engine
    // function.  False matches corrupt the Lua stack (top goes negative) and cause the
    // GC to crash during ScriptManager::InitLua (strncpy / luaC_step trace).
    //
    // Authoritative sources:
    //   pcallk / callk / getglobal  — Phase 1 MinHook trampolines (hardcoded correct patterns)
    //   setglobal + everything else — lua52.dll (struct layouts identical; safe for our usage)
    int resolved = 0;

    // Step 3b: Use the MinHook trampolines saved by LuaStateCapture (Phase 1).
    // Phase 1 found pcallk, callk, and getglobal via hardcoded verified patterns and
    // hooked them; the trampolines call the original engine code directly.
    {
        auto orig = LuaStateCapture::GetOriginalPcallk();
        if (orig) {
            lua.pcallk = orig;
            resolved++;
            if (verbose) Log::Info("  lua_pcallk: using Phase 1 hook trampoline at %p", (void*)orig);
        }
    }
    {
        auto orig = LuaStateCapture::GetOriginalCallk();
        if (orig) {
            lua.callk = orig;
            resolved++;
            if (verbose) Log::Info("  lua_callk: using Phase 1 hook trampoline at %p", (void*)orig);
        }
    }
    {
        auto orig = LuaStateCapture::GetOriginalGetglobal();
        if (orig) {
            lua.getglobal = orig;
            resolved++;
            if (verbose) Log::Info("  lua_getglobal: using Phase 1 hook trampoline at %p", (void*)orig);
        }
    }

    // Step 4: Fall back to lua52.dll for functions not found in engine.
    // Small functions like lua_type, lua_typename, lua_isstring, lua_isnumber,
    // lua_toboolean, lua_rawlen are likely inlined by the engine's compiler.
    // These are safe to call from lua52.dll — they only read from the lua_State*
    // struct and don't invoke the Lua VM or modify internal dispatch tables.
    int fallbacks = 0;

    #define FALLBACK_DLL(field, name) do { \
        if (!lua.field) { \
            FARPROC proc = GetProcAddress(hLuaDll, name); \
            if (proc) { \
                void* real = FollowJumps((void*)proc); \
                lua.field = reinterpret_cast<decltype(lua.field)>(real); \
                fallbacks++; \
                if (verbose) Log::Info("  %s: using lua52.dll fallback at %p", name, real); \
            } \
        } \
    } while(0)

    // VM entry points — prefer Phase 1 trampolines set above; these are fallbacks only.
    // setglobal is safe from lua52.dll: the game's global env has no __newindex metamethod.
    // getglobal fallback is a last resort; normally already set from Phase 1 trampoline.
    FALLBACK_DLL(getglobal,  "lua_getglobal");
    FALLBACK_DLL(setglobal,  "lua_setglobal");

    // Utility functions (read-only, no VM dispatch): definitely safe from lua52.dll
    FALLBACK_DLL(type,       "lua_type");
    FALLBACK_DLL(type_name,  "lua_typename");
    FALLBACK_DLL(isstring,   "lua_isstring");
    FALLBACK_DLL(isnumber,   "lua_isnumber");
    FALLBACK_DLL(toboolean,  "lua_toboolean");
    FALLBACK_DLL(rawlen,     "lua_rawlen");
    FALLBACK_DLL(insert,     "lua_insert");
    FALLBACK_DLL(remove,     "lua_remove");
    FALLBACK_DLL(tonumberx,  "lua_tonumberx");
    FALLBACK_DLL(tointegerx, "lua_tointegerx");
    FALLBACK_DLL(tolstring,  "lua_tolstring");
    FALLBACK_DLL(gettop,     "lua_gettop");
    FALLBACK_DLL(settop,     "lua_settop");
    FALLBACK_DLL(pushnil,    "lua_pushnil");
    FALLBACK_DLL(pushvalue,  "lua_pushvalue");
    FALLBACK_DLL(pushboolean,"lua_pushboolean");
    FALLBACK_DLL(pushinteger,"lua_pushinteger");
    FALLBACK_DLL(pushnumber, "lua_pushnumber");
    FALLBACK_DLL(pushcclosure,"lua_pushcclosure");
    FALLBACK_DLL(pushstring, "lua_pushstring");
    // Table access functions: operate on layout-identical Lua structs.
    // getfield/gettable/settable can trigger metamethods, but only for metatabled
    // objects — our use cases (reading Flag/Text from plain game tables) do not.
    FALLBACK_DLL(getfield,   "lua_getfield");
    FALLBACK_DLL(setfield,   "lua_setfield");
    FALLBACK_DLL(gettable,   "lua_gettable");
    FALLBACK_DLL(settable,   "lua_settable");
    FALLBACK_DLL(next,       "lua_next");
    FALLBACK_DLL(rawgeti,    "lua_rawgeti");
    FALLBACK_DLL(rawget,     "lua_rawget");
    FALLBACK_DLL(rawseti,    "lua_rawseti");
    FALLBACK_DLL(rawset,     "lua_rawset");
    FALLBACK_DLL(createtable,"lua_createtable");
    FALLBACK_DLL(ref,        "luaL_ref");
    FALLBACK_DLL(unref,      "luaL_unref");
    // Code loading: needed for embedded mod execution
    FALLBACK_DLL(loadbufferx,"luaL_loadbufferx");

    #undef FALLBACK_DLL

    if (verbose && fallbacks > 0) {
        Log::Info("Used lua52.dll for %d functions (inlined in engine or no reliable engine scan)", fallbacks);
    }

    // Critical VM entry points:
    //   pcallk / callk / getglobal — Phase 1 MinHook trampolines
    //   setglobal                  — lua52.dll fallback
    if (!lua.pcallk || !lua.callk || !lua.getglobal || !lua.setglobal) {
        if (verbose) Log::Error("Critical VM functions missing (pcallk/callk/getglobal/setglobal) — cannot proceed");
        return false;
    }

    // All other required functions (from engine scan or lua52.dll fallback)
    if (!lua.getfield || !lua.setfield || !lua.next || !lua.tolstring || !lua.type ||
        !lua.settop || !lua.gettop || !lua.pushstring || !lua.pushcclosure ||
        !lua.pushvalue || !lua.pushnil || !lua.rawgeti || !lua.createtable ||
        !lua.ref || !lua.insert || !lua.loadbufferx) {
        if (verbose) Log::Error("Required Lua API functions still missing — cannot proceed");
        return false;
    }

    s_ready = true;
    Log::Info("Lua API bindings ready (%d Phase-1 trampolines + %d lua52.dll)", resolved, fallbacks);
    return true;
}

bool IsReady() { return s_ready; }

HMODULE GetModule() { return s_luaModule; }

}
