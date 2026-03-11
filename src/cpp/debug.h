#pragma once
#include <Windows.h>

// Forward declare lua_State to avoid pulling in lua_bindings.h
typedef struct lua_State lua_State;

namespace Debug {

#ifdef ENABLE_DEBUG_KEYS
// Validate chaos.dat gate file (SHA-256 hash check).
// Can be called early during startup (before Lua is available).
// Returns true if debug keys are enabled. Result is cached.
bool ValidateGateFile();

// Returns true if debug keys are enabled (chaos.dat validated).
// Must call ValidateGateFile() first during startup.
bool AreDebugKeysEnabled();

// Poll keyboard for debug key presses and set corresponding Lua global flags.
// Must be called on the game thread (from PostPcallCallback) with a valid lua_State.
void CheckDebugKeys(lua_State* L);
#else
inline bool ValidateGateFile() { return false; }
inline bool AreDebugKeysEnabled() { return false; }
inline void CheckDebugKeys(lua_State*) {}
#endif

// Poll backslash key (\) to toggle subtitle reading on/off.
// NOT gated by chaos.dat — always active after bridge registration.
// Toggles the Lua global _SubtitleReadingEnabled (default false).
// State is persisted to subtitle_on.flag file next to the DLL.
void CheckSubtitleToggle(lua_State* L);

// Load saved subtitle toggle state from disk and set the Lua global.
// Call after bridge registration + mod loading (and after Lua state resets).
void LoadSubtitleState(lua_State* L);

// Poll Shift+backslash (pipe |) and L3 (left stick click) to cycle
// damage feedback mode: 0=Off, 1=Audible Healthbars, 2=Damage Dealt, 3=Combined.
// NOT gated by chaos.dat — always active after bridge registration.
// Toggles the Lua global _DamageFeedbackMode (default 0).
// State is persisted to damage_feedback_mode.flag file next to the DLL.
void CheckDamageFeedbackToggle(lua_State* L);

// Load saved damage feedback mode from disk and set the Lua global.
// Call after bridge registration + mod loading (and after Lua state resets).
void LoadDamageFeedbackState(lua_State* L);

// Load saved language state from disk and set the Lua global.
// Also attempts auto-detection from the game's Profile.sjson if no flag file exists.
// Call after bridge registration + mod loading (and after Lua state resets).
void LoadLanguageState(lua_State* L);

// Load a language .lua file from the languages/ subdirectory next to the DLL.
// The file is expected to define a local table and call _ApplyLanguageData().
// Returns true if the file was loaded and executed successfully.
bool LoadLanguageFile(lua_State* L, const char* langCode);

// Back up the current English tables (called once after all mods load).
// Executes the _BackupEnglishTables() Lua function defined by LocalizationCore.
void BackupEnglishTables(lua_State* L);

// Get the current language code (e.g. "en", "fr", "de").
const char* GetCurrentLanguage();

// Keyboard input source detection for accessibility TraitTray navigation.
// NOT gated by chaos.dat — always available.
bool IsArrowKeyDown();
bool IsWasdKeyDown();

}
