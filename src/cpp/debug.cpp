#include "debug.h"
#include "logger.h"
#include "lua_bindings.h"
#include "path_resolver.h"
#include "tolk_loader.h"
#include "xinput_proxy.h"
#include <bcrypt.h>
#include <fstream>
#include <vector>
#include <string>

#pragma comment(lib, "bcrypt.lib")

#ifdef ENABLE_DEBUG_KEYS

// DEBUG: F1-F12 spawn god boons, hammer, pom, and well during a run.
//        Number keys 1-6 open debug screens, spawn encounters, and set test state.
// Sets Lua global flags; the DebugKeys Lua mod polls them on game thread for safe execution.
//
// GATING: Requires chaos.dat in the same directory as the DLL.
//         The file is SHA-256 hashed and compared against a hardcoded hash.
//         Even with the file present, the exact contents (key + cipher) must match.

static const uint8_t CHAOS_HASH[] = {
    0xcd, 0x3c, 0x10, 0xd6, 0xe7, 0x5c, 0x77, 0xdc,
    0xad, 0x52, 0x85, 0xfe, 0x68, 0x37, 0xd8, 0x97,
    0x93, 0xc5, 0x30, 0xe5, 0x63, 0xd7, 0xe6, 0x92,
    0x16, 0x47, 0xc1, 0x9b, 0x44, 0x9e, 0x52, 0x8d
};
static const size_t CHAOS_FILE_SIZE = 8192;

// Tri-state: 0 = not checked yet, 1 = validated OK, -1 = validation failed
static int s_chaosValidated = 0;

static bool ValidateChaosFile()
{
    // Build path: <DLL directory>\chaos.dat
    std::wstring path = PathResolver::GetInjectedDllDir() + L"\\chaos.dat";

    // Read file
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        return false;
    }

    auto size = file.tellg();
    if (static_cast<size_t>(size) != CHAOS_FILE_SIZE) {
        Log::Info("DEBUG: chaos.dat wrong size (%lld) — debug keys disabled", (long long)size);
        return false;
    }

    file.seekg(0);
    std::vector<uint8_t> data(CHAOS_FILE_SIZE);
    file.read(reinterpret_cast<char*>(data.data()), CHAOS_FILE_SIZE);
    if (!file.good()) {
        Log::Info("DEBUG: chaos.dat read error — debug keys disabled");
        return false;
    }
    file.close();

    // SHA-256 hash using Windows BCrypt
    BCRYPT_ALG_HANDLE hAlg = nullptr;
    BCRYPT_HASH_HANDLE hHash = nullptr;
    uint8_t hash[32] = {};
    bool ok = false;

    if (BCryptOpenAlgorithmProvider(&hAlg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0) {
        if (BCryptCreateHash(hAlg, &hHash, nullptr, 0, nullptr, 0, 0) == 0) {
            if (BCryptHashData(hHash, data.data(), (ULONG)data.size(), 0) == 0) {
                if (BCryptFinishHash(hHash, hash, 32, 0) == 0) {
                    ok = (memcmp(hash, CHAOS_HASH, 32) == 0);
                }
            }
            BCryptDestroyHash(hHash);
        }
        BCryptCloseAlgorithmProvider(hAlg, 0);
    }

    if (ok) {
        Log::Info("DEBUG: chaos.dat validated — debug keys enabled");
    } else {
        Log::Info("DEBUG: chaos.dat hash mismatch — debug keys disabled");
    }
    return ok;
}

struct DebugKeyEntry {
    int vk;
    const char* luaFlag;
    const char* label;
};

static const DebugKeyEntry s_debugKeys[] = {
    { VK_F1,  "_DebugSpawnZeus",      "Zeus"      },
    { VK_F2,  "_DebugSpawnPoseidon",  "Poseidon"  },
    { VK_F3,  "_DebugSpawnAthena",    "Athena"    },
    { VK_F4,  "_DebugSpawnAres",      "Ares"      },
    { VK_F5,  "_DebugSpawnAphrodite", "Aphrodite" },
    { VK_F6,  "_DebugSpawnArtemis",   "Artemis"   },
    { VK_F7,  "_DebugSpawnDionysus",  "Dionysus"  },
    { VK_F8,  "_DebugSpawnHermes",    "Hermes"    },
    { VK_F9,  "_DebugSpawnDemeter",   "Demeter"   },
    { VK_F10, "_DebugSpawnHammer",    "Hammer"    },
    { VK_F11, "_DebugSpawnPom",       "Pom"       },
    { VK_F12, "_DebugSpawnStore",     "Well"      },
    { 0x31,   "_DebugSpawnChaos",     "Chaos"     },  // Number key 1
    { 0x32,   "_DebugSpawnNPC",       "NPC"       },  // Number key 2
    { 0x33,   "_DebugOpenWeaponUpgrade", "WeaponUpgrade" },  // Number key 3
    { 0x34,   "_DebugOpenSellTrait",  "SellTrait" },  // Number key 4
    { 0x35,   "_DebugOpenRunClear",   "RunClear"  },  // Number key 5
    { 0x36,   "_DebugMaxGun",         "MaxGun"    },  // Number key 6
    { 0x37,   "_DebugFlashback",      "Flashback" },  // Number key 7
    { 0x38,   "_DebugFlashback2",     "Flashback2"},  // Number key 8
    { 0x39,   "_DebugSpawnFish",     "Fish"      },  // Number key 9
    { 0x30,   "_DebugSpawnFountain", "Fountain"  },  // Number key 0
};
static const int s_debugKeyCount = sizeof(s_debugKeys) / sizeof(s_debugKeys[0]);
static bool s_wasDown[32] = {};

#endif // ENABLE_DEBUG_KEYS

namespace Debug {

#ifdef ENABLE_DEBUG_KEYS

bool ValidateGateFile()
{
    if (s_chaosValidated == 0) {
        s_chaosValidated = ValidateChaosFile() ? 1 : -1;
    }
    return s_chaosValidated == 1;
}

bool AreDebugKeysEnabled()
{
    return s_chaosValidated == 1;
}

void CheckDebugKeys(lua_State* L)
{
    // One-time validation of chaos.dat gate file (usually already done by ValidateGateFile at startup)
    if (s_chaosValidated == 0) {
        s_chaosValidated = ValidateChaosFile() ? 1 : -1;
    }
    if (s_chaosValidated != 1) return;

    int savedTop = lua.gettop(L);

    for (int i = 0; i < s_debugKeyCount; i++) {
        bool down = (GetAsyncKeyState(s_debugKeys[i].vk) & 0x8000) != 0;
        if (down && !s_wasDown[i]) {
            __try {
                lua.pushboolean(L, 1);
                lua.setglobal(L, s_debugKeys[i].luaFlag);
                Log::Info("DEBUG: F%d — set %s flag (%s)", i + 1, s_debugKeys[i].luaFlag, s_debugKeys[i].label);
            } __except(EXCEPTION_EXECUTE_HANDLER) {
                Log::Warn("DEBUG: F%d flag set crashed: 0x%08X", i + 1, GetExceptionCode());
                lua.settop(L, savedTop);
            }
        }
        s_wasDown[i] = down;
    }
}

#endif // ENABLE_DEBUG_KEYS

// ==================== Localized UI string helper ====================
// Reads a key from the UIStrings Lua global table and returns it as a wide string
// for Tolk speech. Falls back to the provided default if the key is missing.
// Uses a static buffer (not thread-safe, but all callers are on the game thread).
static wchar_t s_uiStringBuf[512];

static const wchar_t* GetUIString(lua_State* L, const char* key, const wchar_t* fallback)
{
    lua.getglobal(L, "UIStrings");
    if (lua.type(L, -1) != LUA_TTABLE) {
        lua_pop(L, 1);
        return fallback;
    }
    lua.getfield(L, -1, key);
    if (lua.type(L, -1) != LUA_TSTRING) {
        lua_pop(L, 2);
        return fallback;
    }
    const char* utf8 = lua.tolstring(L, -1, nullptr);
    lua_pop(L, 2);
    if (!utf8 || utf8[0] == '\0') return fallback;

    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, s_uiStringBuf, 512);
    if (len <= 0) return fallback;
    return s_uiStringBuf;
}

// Subtitle toggle: backslash key (\) toggles _SubtitleReadingEnabled Lua global.
// State persisted to subtitle_on.flag file next to the DLL.
static bool s_subtitleKeyWasDown = false;

static std::wstring GetSubtitleFlagPath()
{
    return PathResolver::GetInjectedDllDir() + L"\\subtitle_on.flag";
}

static bool IsSubtitleFlagSet()
{
    DWORD attrs = GetFileAttributesW(GetSubtitleFlagPath().c_str());
    return (attrs != INVALID_FILE_ATTRIBUTES);
}

static void SaveSubtitleFlag(bool enabled)
{
    std::wstring path = GetSubtitleFlagPath();
    if (enabled) {
        // Create empty flag file
        HANDLE h = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
    } else {
        // Delete flag file
        DeleteFileW(path.c_str());
    }
}

void CheckSubtitleToggle(lua_State* L)
{
    bool shiftDown = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    bool down = (GetAsyncKeyState(VK_OEM_5) & 0x8000) != 0 && !shiftDown;  // backslash without shift
    if (down && !s_subtitleKeyWasDown) {
        int savedTop = lua.gettop(L);
        __try {
            // Read current state
            lua.getglobal(L, "_SubtitleReadingEnabled");
            int currentType = lua.type(L, -1);
            bool currentVal = false;
            if (currentType == LUA_TBOOLEAN) {
                currentVal = lua.toboolean(L, -1) != 0;
            }
            lua_pop(L, 1);

            // Toggle
            bool newVal = !currentVal;
            lua.pushboolean(L, newVal ? 1 : 0);
            lua.setglobal(L, "_SubtitleReadingEnabled");

            // Persist to disk
            SaveSubtitleFlag(newVal);

            // Speak confirmation via Tolk (localized from UIStrings)
            const wchar_t* msg = newVal
                ? GetUIString(L, "SubtitlesOn", L"Subtitles on")
                : GetUIString(L, "SubtitlesOff", L"Subtitles off");
            TolkLoader::Output(msg, true);
            Log::Info("[SUBTITLE] Toggle: %s", newVal ? "on" : "off");
        } __except(EXCEPTION_EXECUTE_HANDLER) {
            Log::Warn("[SUBTITLE] Toggle crashed: 0x%08X", GetExceptionCode());
            lua.settop(L, savedTop);
        }
    }
    s_subtitleKeyWasDown = down;
}

void LoadSubtitleState(lua_State* L)
{
    bool enabled = IsSubtitleFlagSet();
    int savedTop = lua.gettop(L);
    __try {
        lua.pushboolean(L, enabled ? 1 : 0);
        lua.setglobal(L, "_SubtitleReadingEnabled");
        if (enabled) {
            Log::Info("[SUBTITLE] Restored saved state: on");
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[SUBTITLE] LoadSubtitleState crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
    }
}

// Damage feedback toggle: Shift+\ (pipe |) on keyboard, L3 on controller.
// Cycles mode: 0=Off -> 1=Progress Bar -> 2=Hitmarker -> 0=Off.
// State persisted to damage_feedback_mode.flag file next to the DLL.
static bool s_damageFeedbackKeyWasDown = false;
static bool s_damageFeedbackL3WasDown = false;

static std::wstring GetDamageFeedbackFlagPath()
{
    return PathResolver::GetInjectedDllDir() + L"\\damage_feedback_mode.flag";
}

static int ReadDamageFeedbackMode()
{
    std::wstring path = GetDamageFeedbackFlagPath();
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return 0;

    char buf[4] = {};
    DWORD bytesRead = 0;
    ReadFile(h, buf, 3, &bytesRead, nullptr);
    CloseHandle(h);

    if (bytesRead > 0) {
        int mode = buf[0] - '0';
        if (mode >= 0 && mode <= 3) return mode;
    }
    return 0;
}

static void SaveDamageFeedbackMode(int mode)
{
    std::wstring path = GetDamageFeedbackFlagPath();
    HANDLE h = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return;

    char buf[2] = { static_cast<char>('0' + mode), '\0' };
    DWORD written = 0;
    WriteFile(h, buf, 1, &written, nullptr);
    CloseHandle(h);
}

static void CycleDamageFeedbackMode(lua_State* L)
{
    int savedTop = lua.gettop(L);
    __try {
        // Read current mode from Lua global
        lua.getglobal(L, "_DamageFeedbackMode");
        int currentType = lua.type(L, -1);
        int currentMode = 0;
        if (currentType == LUA_TNUMBER) {
            currentMode = static_cast<int>(lua.tonumberx(L, -1, nullptr));
        }
        lua_pop(L, 1);

        // Cycle: 0 -> 1 -> 2 -> 3 -> 0
        int newMode = (currentMode + 1) % 4;

        // Set Lua global
        lua.pushnumber(L, static_cast<double>(newMode));
        lua.setglobal(L, "_DamageFeedbackMode");

        // Persist to disk
        SaveDamageFeedbackMode(newMode);

        // Speak confirmation via Tolk (localized from UIStrings)
        const wchar_t* msg = nullptr;
        switch (newMode) {
            case 0: msg = GetUIString(L, "DamageFeedbackOff", L"Damage feedback off"); break;
            case 1: msg = GetUIString(L, "DamageFeedbackAudible", L"Damage feedback audible healthbars"); break;
            case 2: msg = GetUIString(L, "DamageFeedbackDealt", L"Damage feedback damage dealt"); break;
            case 3: msg = GetUIString(L, "DamageFeedbackCombined", L"Damage feedback combined"); break;
        }
        if (msg) TolkLoader::Output(msg, true);
        Log::Info("[DAMAGE-FB] Toggle: mode %d", newMode);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[DAMAGE-FB] Toggle crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
    }
}

void CheckDamageFeedbackToggle(lua_State* L)
{
    // Keyboard: Shift + backslash (VK_OEM_5)
    bool shiftDown = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    bool bsDown = (GetAsyncKeyState(VK_OEM_5) & 0x8000) != 0;
    bool keyDown = shiftDown && bsDown;

    if (keyDown && !s_damageFeedbackKeyWasDown) {
        CycleDamageFeedbackMode(L);
    }
    s_damageFeedbackKeyWasDown = keyDown;

    // Controller: L3 (left stick click) = XINPUT_GAMEPAD_LEFT_THUMB = 0x0040
    bool l3Down = (XInputProxy::GetButtons() & 0x0040) != 0;
    if (l3Down && !s_damageFeedbackL3WasDown) {
        CycleDamageFeedbackMode(L);
    }
    s_damageFeedbackL3WasDown = l3Down;
}

void LoadDamageFeedbackState(lua_State* L)
{
    int mode = ReadDamageFeedbackMode();
    int savedTop = lua.gettop(L);
    __try {
        lua.pushnumber(L, static_cast<double>(mode));
        lua.setglobal(L, "_DamageFeedbackMode");
        if (mode != 0) {
            Log::Info("[DAMAGE-FB] Restored saved state: mode %d", mode);
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[DAMAGE-FB] LoadDamageFeedbackState crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
    }
}

// ==================== Language auto-detection ====================
// Auto-detects language from game's Profile.sjson on first load.
// Loads external language .lua files from <dll_dir>/languages/<code>.lua.

struct LangEntry {
    const char* code;
    const wchar_t* displayName;  // Name in that language (for TTS announcement)
};

static const LangEntry s_supportedLanguages[] = {
    { "en",    L"English"                 },
    { "de",    L"Deutsch"                 },
    { "es",    L"Espa\x00f1ol"            },  // Español
    { "fr",    L"Fran\x00e7""ais"         },  // Français
    { "it",    L"Italiano"                },
    { "ja",    L"\x65e5\x672c\x8a9e"      },  // 日本語
    { "ko",    L"\xd55c\xad6d\xc5b4"      },  // 한국어
    { "pl",    L"Polski"                  },
    { "pt-BR", L"Portugu\x00eas"          },  // Português
    { "ru",    L"\x0420\x0443\x0441\x0441\x043a\x0438\x0439" },  // Русский
    { "zh-CN", L"\x7b80\x4f53\x4e2d\x6587" },  // 简体中文
};
static const int s_langCount = sizeof(s_supportedLanguages) / sizeof(s_supportedLanguages[0]);

static int s_currentLangIndex = 0;  // Default to English

static std::wstring GetLanguageFlagPath()
{
    return PathResolver::GetInjectedDllDir() + L"\\language.flag";
}

static std::string ReadLanguageFlag()
{
    std::wstring path = GetLanguageFlagPath();
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return "";

    char buf[16] = {};
    DWORD bytesRead = 0;
    ReadFile(h, buf, 15, &bytesRead, nullptr);
    CloseHandle(h);

    if (bytesRead > 0) {
        // Trim trailing whitespace/newlines
        std::string code(buf, bytesRead);
        while (!code.empty() && (code.back() == '\n' || code.back() == '\r' || code.back() == ' '))
            code.pop_back();
        return code;
    }
    return "";
}

static int FindLangIndex(const char* code)
{
    for (int i = 0; i < s_langCount; i++) {
        if (_stricmp(s_supportedLanguages[i].code, code) == 0) return i;
    }
    return 0;  // Default to English
}

// Try to detect game language from Profile.sjson in the user's save folder.
// Returns language code (e.g. "fr") or empty string if detection fails.
static std::string DetectGameLanguage()
{
    // Build save path: %USERPROFILE%/Documents/Saved Games/Hades/
    wchar_t userProfile[MAX_PATH] = {};
    DWORD len = GetEnvironmentVariableW(L"USERPROFILE", userProfile, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return "";

    std::wstring saveDir = std::wstring(userProfile) + L"\\Documents\\Saved Games\\Hades\\";

    // Read activeProfile to determine which profile number
    std::wstring activeProfilePath = saveDir + L"activeProfile";
    std::ifstream apf(activeProfilePath);
    if (!apf.is_open()) return "";

    std::string apLine;
    std::getline(apf, apLine);
    apf.close();

    // Parse profile name (e.g. "SGB1   Profile1" -> "Profile1")
    std::string profileName;
    auto spacePos = apLine.find("Profile");
    if (spacePos != std::string::npos) {
        profileName = apLine.substr(spacePos);
        // Trim trailing whitespace
        while (!profileName.empty() && (profileName.back() == ' ' || profileName.back() == '\r' || profileName.back() == '\n'))
            profileName.pop_back();
    }
    if (profileName.empty()) profileName = "Profile1";

    // Read ProfileX.sjson
    std::wstring profilePath = saveDir;
    for (char c : profileName) profilePath += static_cast<wchar_t>(c);
    profilePath += L".sjson";

    std::ifstream pf(profilePath);
    if (!pf.is_open()) return "";

    // Simple line-by-line parsing for Language = "XX"
    std::string line;
    while (std::getline(pf, line)) {
        // Look for: Language = "XX" (but NOT UiLanguage)
        auto eqPos = line.find('=');
        if (eqPos == std::string::npos) continue;

        std::string key = line.substr(0, eqPos);
        // Trim whitespace from key
        while (!key.empty() && key.back() == ' ') key.pop_back();
        while (!key.empty() && key.front() == ' ') key.erase(key.begin());

        if (key != "Language") continue;

        // Extract value between quotes
        auto q1 = line.find('"', eqPos);
        auto q2 = line.find('"', q1 + 1);
        if (q1 != std::string::npos && q2 != std::string::npos && q2 > q1 + 1) {
            std::string lang = line.substr(q1 + 1, q2 - q1 - 1);
            // Verify it's a known language
            if (FindLangIndex(lang.c_str()) >= 0) {
                return lang;
            }
        }
    }

    return "";
}

// Inner SEH-protected function for loading a language chunk (no C++ objects — avoids C2712)
static bool TryLoadLanguageChunk(lua_State* L, const char* buf, size_t size, const char* chunkName, const char* langCode)
{
    int savedTop = lua.gettop(L);
    __try {
        // Restore English baseline first
        lua.getglobal(L, "_RestoreEnglish");
        int fnType = lua.type(L, -1);
        if (fnType == LUA_TFUNCTION || fnType == LUA_TTABLE) {
            lua.pcallk(L, 0, 0, 0, 0, nullptr);
        } else {
            lua_pop(L, 1);
        }

        // Load the language chunk
        int loadResult = lua.loadbufferx(L, buf, size, chunkName, nullptr);
        if (loadResult != 0) {
            const char* err = lua.tolstring(L, -1, nullptr);
            Log::Warn("[LANGUAGE] Failed to load %s.lua: %s", langCode, err ? err : "unknown error");
            lua_pop(L, 1);
            return false;
        }

        // Execute it
        int callResult = lua.pcallk(L, 0, 0, 0, 0, nullptr);
        if (callResult != 0) {
            const char* err = lua.tolstring(L, -1, nullptr);
            Log::Warn("[LANGUAGE] Failed to execute %s.lua: %s", langCode, err ? err : "unknown error");
            lua_pop(L, 1);
            return false;
        }

        Log::Info("[LANGUAGE] Loaded language file: %s.lua", langCode);
        return true;
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[LANGUAGE] LoadLanguageFile crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
        return false;
    }
}

bool LoadLanguageFile(lua_State* L, const char* langCode)
{
    if (!langCode || strcmp(langCode, "en") == 0) return true;  // English is embedded, no file needed

    // Build path: <dll_dir>/languages/<langCode>.lua (file I/O with C++ objects outside __try)
    std::wstring dir = PathResolver::GetInjectedDllDir() + L"\\languages\\";
    std::wstring path = dir;
    for (const char* p = langCode; *p; ++p) path += static_cast<wchar_t>(*p);
    path += L".lua";

    // Read file into memory
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        Log::Warn("[LANGUAGE] Language file not found: languages/%s.lua", langCode);
        return false;
    }

    auto size = static_cast<size_t>(file.tellg());
    if (size == 0 || size > 4 * 1024 * 1024) {  // Max 4MB
        Log::Warn("[LANGUAGE] Language file invalid size: %zu", size);
        return false;
    }

    file.seekg(0);
    std::vector<char> buffer(size);
    file.read(buffer.data(), size);
    file.close();

    // Build chunk name (C++ string, outside __try)
    char chunkName[64];
    snprintf(chunkName, sizeof(chunkName), "@lang/%s.lua", langCode);

    // Call SEH-protected inner function (no C++ objects)
    return TryLoadLanguageChunk(L, buffer.data(), size, chunkName, langCode);
}

void BackupEnglishTables(lua_State* L)
{
    int savedTop = lua.gettop(L);
    __try {
        lua.getglobal(L, "_BackupEnglishTables");
        int fnType = lua.type(L, -1);
        if (fnType == LUA_TFUNCTION || fnType == LUA_TTABLE) {
            lua.pcallk(L, 0, 0, 0, 0, nullptr);
            Log::Info("[LANGUAGE] English tables backed up");
        } else {
            lua_pop(L, 1);
            Log::Warn("[LANGUAGE] _BackupEnglishTables function not found");
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[LANGUAGE] BackupEnglishTables crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
    }
}

// Inner SEH-protected function for loading language state (no C++ objects — avoids C2712)
static void TryLoadLanguageStateInner(lua_State* L, const char* code)
{
    int savedTop = lua.gettop(L);
    __try {
        // Set Lua global
        lua.pushstring(L, code);
        lua.setglobal(L, "_CurrentLanguage");

        // Backup English tables BEFORE loading any language overlay
        BackupEnglishTables(L);

        // Load language file if not English
        if (strcmp(code, "en") != 0) {
            if (LoadLanguageFile(L, code)) {
                Log::Info("[LANGUAGE] Restored saved language: %s", code);
            } else {
                // Fall back to English
                s_currentLangIndex = 0;
                lua.pushstring(L, "en");
                lua.setglobal(L, "_CurrentLanguage");
                Log::Info("[LANGUAGE] Language file missing, defaulting to English");
            }
        }
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        Log::Warn("[LANGUAGE] LoadLanguageState crashed: 0x%08X", GetExceptionCode());
        lua.settop(L, savedTop);
    }
}

void LoadLanguageState(lua_State* L)
{
    // Determine language code (C++ objects outside __try — avoids C2712)
    std::string savedLang = ReadLanguageFlag();

    // If no flag file, try auto-detection from game profile
    if (savedLang.empty()) {
        savedLang = DetectGameLanguage();
        if (!savedLang.empty() && savedLang != "en") {
            Log::Info("[LANGUAGE] Auto-detected game language: %s", savedLang.c_str());
        }
    }

    // Default to English if nothing found
    if (savedLang.empty()) savedLang = "en";

    s_currentLangIndex = FindLangIndex(savedLang.c_str());
    const char* code = s_supportedLanguages[s_currentLangIndex].code;

    // Call SEH-protected inner function (no C++ objects)
    TryLoadLanguageStateInner(L, code);
}

const char* GetCurrentLanguage()
{
    return s_supportedLanguages[s_currentLangIndex].code;
}

// Keyboard input source detection for TraitTray accessibility.
// Arrow keys = trait navigation (like left stick), WASD = mod menus (like D-pad).
bool IsArrowKeyDown()
{
    return (GetAsyncKeyState(VK_UP) & 0x8000) != 0 ||
           (GetAsyncKeyState(VK_DOWN) & 0x8000) != 0 ||
           (GetAsyncKeyState(VK_LEFT) & 0x8000) != 0 ||
           (GetAsyncKeyState(VK_RIGHT) & 0x8000) != 0;
}

bool IsWasdKeyDown()
{
    return (GetAsyncKeyState(0x57) & 0x8000) != 0 ||  // W
           (GetAsyncKeyState(0x41) & 0x8000) != 0 ||  // A
           (GetAsyncKeyState(0x53) & 0x8000) != 0 ||  // S
           (GetAsyncKeyState(0x44) & 0x8000) != 0;    // D
}

} // namespace Debug
