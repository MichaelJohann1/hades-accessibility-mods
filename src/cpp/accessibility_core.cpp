#include "accessibility_core.h"
#include "logger.h"
#include "path_resolver.h"
#include "tolk_loader.h"
#include "lua_bindings.h"
#include "lua_state_capture.h"
#include "lua_wrappers.h"
#include "xinput_proxy.h"
#include "embedded_mods.h"
#include "debug.h"
#include "audio_feedback.h"
#include "version.h"
#include <cstdio>
#include <atomic>
#include <string>
#include <vector>
#include <dxgi.h>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "version.lib")

#define MODUTIL_VERSION "v2.10.0"

// From dllmain.cpp
HANDLE GetShutdownEvent();

static bool s_initialized = false;

// Probe OnScreenOpened type on the callback's L via SEH.
// IMPORTANT: We use the callback's L (not the initially-captured state) because:
//   - LuaStateCapture::GetState() captures the FIRST lua_callk, which is often a
//     short-lived engine-internal coroutine. By the time we need it (3+ seconds
//     later), that coroutine has been GC'd -> dangling pointer -> SEH catches
//     lua.getglobal crash -> returns LUA_TNONE forever -> bridge never registers.
//   - The callback's L is guaranteed alive: it just fired lua_pcallk.
//   - All Lua coroutines share the same global namespace, so any live L sees the
//     same OnScreenOpened value as any other.
// Returns LUA_TNONE if the probe crashes (L's stack is full), otherwise the type.
static int ProbeOnScreenOpened(lua_State* L)
{
    int fnType = LUA_TNONE;
    __try {
        lua.getglobal(L, "OnScreenOpened");
        fnType = lua.type(L, -1);
        lua_pop(L, 1);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        static int s_probeFailures = 0;
        if (++s_probeFailures <= 10) {
            Log::Warn("Probe crashed on L=%p (failure #%d): 0x%08X",
                      L, s_probeFailures, GetExceptionCode());
        }
        fnType = LUA_TNONE;
    }
    return fnType;
}

// Attempt RegisterBridge with inner SEH. Returns true on success.
// Saves and restores the Lua stack top so a crash never leaves garbage values
// on the stack (which would corrupt lua_State and cause later GC crashes).
static bool TryRegisterBridge(lua_State* L)
{
    int savedTop = lua.gettop(L);
    __try {
        LuaWrappers::RegisterBridge(L);
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        static int s_crashCount = 0;
        s_crashCount++;
        if (s_crashCount <= 3 || (s_crashCount % 50 == 0)) {
            Log::Warn("RegisterBridge crashed #%d on L=%p (0x%08X) top=%d->%d - will retry",
                      s_crashCount, L, GetExceptionCode(), savedTop, lua.gettop(L));
        }
        // Restore stack to pre-call state to prevent lua_State corruption
        lua.settop(L, savedTop);
        return false;
    }
}

// Probe TolkSpeak to detect if Lua globals were reset (e.g. App::Reset).
// Returns true if TolkSpeak is nil or missing (i.e. state was reset).
static bool IsLuaStateReset(lua_State* L)
{
    int bridgeType = LUA_TNONE;
    __try {
        lua.getglobal(L, "TolkSpeak");
        bridgeType = lua.type(L, -1);
        lua_pop(L, 1);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        bridgeType = LUA_TNONE;
    }
    return (bridgeType == LUA_TNIL || bridgeType == LUA_TNONE);
}

// ============================================================
// System info gathering for diagnostic banner
// ============================================================

static void LogOSVersion()
{
    // Read directly from HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion
    HKEY hKey = nullptr;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
        Log::Info("  OS: Windows (registry unreadable)");
        return;
    }

    auto readVal = [&](const char* name) -> std::string {
        char buf[256] = {};
        DWORD size = sizeof(buf);
        DWORD type = 0;
        if (RegQueryValueExA(hKey, name, nullptr, &type, reinterpret_cast<LPBYTE>(buf), &size) == ERROR_SUCCESS) {
            if (type == REG_SZ) return buf;
            if (type == REG_DWORD && size == sizeof(DWORD)) {
                DWORD val = *reinterpret_cast<DWORD*>(buf);
                char num[32];
                snprintf(num, sizeof(num), "%lu", val);
                return num;
            }
        }
        return "";
    };

    std::string productName    = readVal("ProductName");
    std::string displayVersion = readVal("DisplayVersion");
    std::string currentBuild   = readVal("CurrentBuild");
    std::string ubr            = readVal("UBR");
    std::string editionId      = readVal("EditionID");

    RegCloseKey(hKey);

    // Format: "Windows 11 Home 24H2 (Build 26100.3194)" or similar
    std::string os = productName.empty() ? "Windows" : productName;
    if (!displayVersion.empty()) {
        os += " " + displayVersion;
    }
    if (!currentBuild.empty()) {
        os += " (Build " + currentBuild;
        if (!ubr.empty()) {
            os += "." + ubr;
        }
        os += ")";
    }
    if (!editionId.empty()) {
        os += " [" + editionId + "]";
    }
    Log::Info("  OS: %s", os.c_str());
}

static std::string GetCPUName()
{
    char cpuName[256] = {};
    HKEY hKey = nullptr;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD size = sizeof(cpuName);
        RegQueryValueExA(hKey, "ProcessorNameString", nullptr, nullptr, reinterpret_cast<LPBYTE>(cpuName), &size);
        RegCloseKey(hKey);
    }
    return cpuName[0] ? cpuName : "Unknown CPU";
}

static void GetMemoryInfo(DWORD& totalMB, DWORD& availMB)
{
    MEMORYSTATUSEX mem = {};
    mem.dwLength = sizeof(mem);
    if (GlobalMemoryStatusEx(&mem)) {
        totalMB = static_cast<DWORD>(mem.ullTotalPhys / (1024 * 1024));
        availMB = static_cast<DWORD>(mem.ullAvailPhys / (1024 * 1024));
    } else {
        totalMB = availMB = 0;
    }
}

static std::string GetGPUName()
{
    IDXGIFactory* factory = nullptr;
    if (FAILED(CreateDXGIFactory(__uuidof(IDXGIFactory), reinterpret_cast<void**>(&factory)))) {
        return "Unknown GPU";
    }

    IDXGIAdapter* adapter = nullptr;
    if (FAILED(factory->EnumAdapters(0, &adapter))) {
        factory->Release();
        return "Unknown GPU";
    }

    DXGI_ADAPTER_DESC desc = {};
    adapter->GetDesc(&desc);
    adapter->Release();
    factory->Release();

    // Convert wide GPU name to narrow
    char name[256] = {};
    WideCharToMultiByte(CP_UTF8, 0, desc.Description, -1, name, sizeof(name), nullptr, nullptr);

    size_t vramMB = desc.DedicatedVideoMemory / (1024 * 1024);

    char buf[512];
    snprintf(buf, sizeof(buf), "%s (%zu MB VRAM)", name, vramMB);
    return buf;
}

static std::string GetFileVersionString(const wchar_t* filePath)
{
    DWORD verHandle = 0;
    DWORD verSize = GetFileVersionInfoSizeW(filePath, &verHandle);
    if (verSize == 0) return "";

    std::vector<BYTE> verData(verSize);
    if (!GetFileVersionInfoW(filePath, verHandle, verSize, verData.data())) return "";

    VS_FIXEDFILEINFO* fileInfo = nullptr;
    UINT len = 0;
    if (!VerQueryValueW(verData.data(), L"\\", reinterpret_cast<LPVOID*>(&fileInfo), &len)) return "";

    char buf[64];
    snprintf(buf, sizeof(buf), "%d.%d.%d.%d",
             HIWORD(fileInfo->dwFileVersionMS), LOWORD(fileInfo->dwFileVersionMS),
             HIWORD(fileInfo->dwFileVersionLS), LOWORD(fileInfo->dwFileVersionLS));
    return buf;
}

static uint64_t GetFileSize64(const wchar_t* filePath)
{
    WIN32_FILE_ATTRIBUTE_DATA fad = {};
    if (GetFileAttributesExW(filePath, GetFileExInfoStandard, &fad)) {
        ULARGE_INTEGER size;
        size.HighPart = fad.nFileSizeHigh;
        size.LowPart = fad.nFileSizeLow;
        return size.QuadPart;
    }
    return 0;
}

static void LogStartupBanner()
{
    SYSTEMTIME st;
    GetLocalTime(&st);
    char dateStr[64];
    snprintf(dateStr, sizeof(dateStr), "%04d-%02d-%02d %02d:%02d:%02d",
             st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

    Log::Info("============================================================");
    Log::Info("  Hades Accessibility Mod %s", MOD_VERSION);
    Log::Info("  Date: %s", dateStr);
    Log::Info("============================================================");

    // [System]
    Log::Info("[System]");
    LogOSVersion();
    Log::Info("  CPU: %s", GetCPUName().c_str());
    DWORD totalMB = 0, availMB = 0;
    GetMemoryInfo(totalMB, availMB);
    Log::Info("  RAM: %lu MB total, %lu MB available", totalMB, availMB);
    Log::Info("  GPU: %s", GetGPUName().c_str());

    // [Game]
    Log::Info("[Game]");
    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    char exePathNarrow[MAX_PATH] = {};
    WideCharToMultiByte(CP_UTF8, 0, exePath, -1, exePathNarrow, MAX_PATH, nullptr, nullptr);
    Log::Info("  Executable: %s", exePathNarrow);

    std::string exeVer = GetFileVersionString(exePath);
    if (!exeVer.empty()) {
        Log::Info("  Game version: %s", exeVer.c_str());
    }

    // DLL location
    HMODULE hSelf = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       reinterpret_cast<LPCWSTR>(&LogStartupBanner), &hSelf);
    if (hSelf) {
        wchar_t dllPath[MAX_PATH] = {};
        GetModuleFileNameW(hSelf, dllPath, MAX_PATH);
        char dllPathNarrow[MAX_PATH] = {};
        WideCharToMultiByte(CP_UTF8, 0, dllPath, -1, dllPathNarrow, MAX_PATH, nullptr, nullptr);
        Log::Info("  DLL location: %s", dllPathNarrow);
    }

    // Engine DLL info
    HMODULE hEngine = GetModuleHandleW(L"EngineWin64s.dll");
    if (hEngine) {
        wchar_t enginePath[MAX_PATH] = {};
        GetModuleFileNameW(hEngine, enginePath, MAX_PATH);
        uint64_t engineSize = GetFileSize64(enginePath);
        std::string engineVer = GetFileVersionString(enginePath);
        if (!engineVer.empty()) {
            Log::Info("  Engine: EngineWin64s.dll v%s (%llu KB)", engineVer.c_str(), engineSize / 1024);
        } else {
            Log::Info("  Engine: EngineWin64s.dll (%llu KB)", engineSize / 1024);
        }
    }

    // [Accessibility] — debug keys status logged after PathResolver::Init + ValidateGateFile

    // [Mods]
    Log::Info("[Mods]");
    Log::Info("  Mod version: %s", MOD_VERSION);
    Log::Info("  Embedded mods: %d", EmbeddedMods::GetModCount());
    Log::Info("  ModUtil version: %s", MODUTIL_VERSION);

    Log::Info("============================================================");
}

namespace AccessibilityCore {

DWORD WINAPI WorkerThread(LPVOID)
{
    Log::Init();
    LogStartupBanner();

    // Phase 1: Install hooks on EngineWin64s.dll's internal Lua functions
    if (!LuaStateCapture::InstallHook()) {
        Log::Error("Failed to hook game engine - aborting");
        return 0;
    }

    // Phase 2: Wait for game to initialize
    Sleep(3000);

    if (WaitForSingleObject(GetShutdownEvent(), 0) == WAIT_OBJECT_0) {
        return 0;
    }

    // Phase 3: Path resolution
    PathResolver::Init();

#ifdef ENABLE_DEBUG_KEYS
    // Chaos.dat gate file check (must be after PathResolver::Init)
    if (Debug::ValidateGateFile()) {
        Log::Info("how chaotic!");
        Log::Info("[Accessibility]");
        Log::Info("  Debug keys: enabled (chaos.dat)");
    }
#endif

    // Phase 4: Tolk integration
    SpeechDllPaths speechPaths = PathResolver::FindSpeechDlls();

    if (speechPaths.tolkFound) {
        if (TolkLoader::Init(speechPaths.tolkDll.c_str())) {
            TolkLoader::Load();

            if (TolkLoader::IsLoaded()) {
                Log::Info("Screen reader connected");
                TolkLoader::Output(L"Hades accessibility ready", true);
            }
        }
    } else {
        Log::Warn("Tolk.dll not found - speech output disabled");
    }

    // Phase 4b: Audio feedback (waveOut for damage tones)
    if (AudioFeedback::Init()) {
        Log::Info("Audio feedback initialized");
    }

    // Phase 5: Lua bindings
    bool luaReady = false;
    for (int attempt = 0; attempt < 240; attempt++) {
        if (WaitForSingleObject(GetShutdownEvent(), 500) == WAIT_OBJECT_0) {
            return 0;
        }
        if (LuaBindings::Init()) {
            luaReady = true;
            break;
        }
    }

    if (!luaReady) {
        Log::Error("Failed to connect to game scripts after 120 seconds - aborting");
        return 0;
    }

    // Phase 6: Wait for Lua state capture
    if (!LuaStateCapture::WaitForState(120000)) {
        Log::Error("Timed out waiting for game scripts - aborting");
        LuaStateCapture::RemoveHook();
        return 0;
    }

    lua_State* L = LuaStateCapture::GetState();

    // Phase 7: Register Lua bridge (happens on the NEXT pcall via the hook)

    static std::atomic<bool> s_bridgeRegistered{false};

    // Backoff counter: after a crash in RegisterBridge, skip N callbacks
    // before retrying. This lets the engine move on to a different (safe) coroutine.
    static std::atomic<int> s_retryBackoff{0};

    // Counter for periodic Lua state reset detection
    static std::atomic<int> s_resetCheckCount{0};

    LuaStateCapture::SetPostPcallCallback([](lua_State* L) {
        // Backoff: skip callbacks after a crash to let the engine switch coroutines.
        if (s_retryBackoff.load() > 0) {
            --s_retryBackoff;
            return;
        }

        // After bridge is registered, periodically check if Lua state was reset
        // (e.g. sgg::App::Reset on save load / starting a run).
        // If TolkSpeak is nil, globals were reinitialized - re-register bridge.
        if (s_bridgeRegistered.load()) {
            int checkCount = ++s_resetCheckCount;
            if (checkCount % 50 == 0) {
                if (IsLuaStateReset(L)) {
                    Log::Info("[RELOAD] Lua state reset detected (TolkSpeak gone) - re-registering bridge + reloading mods");
                    LuaWrappers::ResetRefs();
                    s_bridgeRegistered.store(false);
                    s_resetCheckCount.store(0);
                    if (TolkLoader::IsAvailable()) {
                        TolkLoader::Output(L"Re-initializing accessibility", true);
                    }
                }
            }
            // DEBUG: Check F1-F12 / number keys for spawning test items (runs on game thread)
            Debug::CheckDebugKeys(L);
            // Subtitle toggle: backslash key (always active, not gated by chaos.dat)
            Debug::CheckSubtitleToggle(L);
            // Damage feedback toggle: Shift+\ (pipe) or L3 (always active)
            Debug::CheckDamageFeedbackToggle(L);
            // Language auto-detection handled by LoadLanguageState at startup (no manual toggle)
            // Continuously poll XInput for stick/dpad tracking (rate-limited to ~120fps)
            {
                static ULONGLONG s_lastInputPoll = 0;
                ULONGLONG now = GetTickCount64();
                if (now - s_lastInputPoll >= 8) {
                    XInputProxy::UpdateInputTracking();
                    s_lastInputPoll = now;
                }
            }
            return;  // Bridge already registered, nothing more to do
        }

        // Bridge not yet registered. Probe OnScreenOpened to check if game scripts loaded.
        int fnType = ProbeOnScreenOpened(L);
        if (fnType == LUA_TNONE || fnType == LUA_TNIL) return;

        // Atomically claim the registration slot.
        if (!s_bridgeRegistered.exchange(true)) {
            if (!TryRegisterBridge(L)) {
                // Crash: reset flag so we retry on a different L next time.
                s_bridgeRegistered.store(false);
                s_retryBackoff.store(500);
                return;
            }
            Log::Info("Game scripts connected");

            // Load all embedded Lua mods (ModUtil + accessibility mods)
            int loaded = EmbeddedMods::LoadAll(L);
            Log::Info("Loaded %d mods", loaded);

            // Restore saved subtitle toggle state from disk
            Debug::LoadSubtitleState(L);

            // Restore saved damage feedback mode from disk
            Debug::LoadDamageFeedbackState(L);

            // Load saved language (or auto-detect) and apply language file
            Debug::LoadLanguageState(L);

            if (TolkLoader::IsAvailable()) {
                TolkLoader::Output(L"Mods ready", true);
            }
        }
    });

    // Phase 8: Main loop
    s_initialized = true;

    while (WaitForSingleObject(GetShutdownEvent(), 100) == WAIT_TIMEOUT) {
        // Worker thread idle loop — waiting for shutdown signal.
    }

    Log::Info("Shutdown signal received");
    return 0;
}

void Shutdown()
{
    if (!s_initialized) return;

    Log::Info("=== Hades Accessibility Layer shutting down ===");

    LuaStateCapture::SetPostPcallCallback(nullptr);
    LuaStateCapture::RemoveHook();
    AudioFeedback::Shutdown();
    TolkLoader::Shutdown();
    Log::Info("Shutdown complete");
    Log::Shutdown();

    s_initialized = false;
}

}
