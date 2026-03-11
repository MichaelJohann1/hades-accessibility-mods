#include "lua_wrappers.h"
#include "tolk_loader.h"
#include "logger.h"
#include "xinput_proxy.h"
#include "debug.h"
#include "audio_feedback.h"
#include <string>
#include <Windows.h>

// ============================================================
// Lua Bridge functions (registered as Lua globals)
// ============================================================

// LogEvent: write to log file without speaking (for verbose mod diagnostics)
static int Bridge_LogEvent(lua_State* L)
{
    const char* text = lua.tolstring(L, 1, nullptr);
    if (text) {
        Log::Info("[EVENT] %s", text);
    }
    return 0;
}

static int Bridge_TolkSpeak(lua_State* L)
{
    const char* text = lua.tolstring(L, 1, nullptr);
    if (text) {
        Log::Info("[SPEECH] %s", text);
        int wideLen = MultiByteToWideChar(CP_UTF8, 0, text, -1, nullptr, 0);
        if (wideLen > 0) {
            std::wstring wide(wideLen - 1, L'\0');
            MultiByteToWideChar(CP_UTF8, 0, text, -1, wide.data(), wideLen);
            TolkLoader::Output(wide.c_str(), true);
        }
    }
    return 0;
}

// TolkSpeakQueue: same as TolkSpeak but queues instead of interrupting.
// Use for notifications (resource pickups, boon acquisition) that shouldn't
// cut off other speech. Menu navigation still uses TolkSpeak (interrupt).
static int Bridge_TolkSpeakQueue(lua_State* L)
{
    const char* text = lua.tolstring(L, 1, nullptr);
    if (text) {
        Log::Info("[SPEECH-Q] %s", text);
        int wideLen = MultiByteToWideChar(CP_UTF8, 0, text, -1, nullptr, 0);
        if (wideLen > 0) {
            std::wstring wide(wideLen - 1, L'\0');
            MultiByteToWideChar(CP_UTF8, 0, text, -1, wide.data(), wideLen);
            TolkLoader::Output(wide.c_str(), false);
        }
    }
    return 0;
}

static int Bridge_TolkSilence(lua_State* L)
{
    (void)L;
    Log::Info("[SILENCE]");
    TolkLoader::Silence();
    return 0;
}

static int Bridge_AccessibilityEnabled(lua_State* L)
{
    lua.pushboolean(L, TolkLoader::IsAvailable() ? 1 : 0);
    return 1;
}

// IsTraitNavInput: returns true if the most recent directional input was from
// the left stick (controller) or arrow keys (keyboard). Returns false for D-pad
// or WASD, which are reserved for opening mod menus on the TraitTrayScreen.
static int Bridge_IsTraitNavInput(lua_State* L)
{
    // Actively poll controller — the engine may use XINPUT9_1_0.dll instead of
    // our xinput1_4.dll proxy, so the exported XInputGetState may never be called.
    XInputProxy::UpdateInputTracking();

    bool wasStick = XInputProxy::WasLastInputStick();
    bool wasDpad  = XInputProxy::WasLastInputDpad();
    bool arrowKey = Debug::IsArrowKeyDown();
    bool wasdKey  = Debug::IsWasdKeyDown();

    bool stickOrArrow = wasStick || arrowKey;
    bool dpadOrWasd   = wasDpad  || wasdKey;
    bool result = stickOrArrow && !dpadOrWasd;

    // Diagnostic logging (throttled to avoid flooding)
    static ULONGLONG s_lastDiagLog = 0;
    ULONGLONG now = GetTickCount64();
    if (now - s_lastDiagLog >= 500) {  // Log at most every 500ms
        WORD buttons = XInputProxy::GetButtons();
        Log::Debug("[TRAIT-NAV] stick=%d dpad=%d arrow=%d wasd=%d buttons=0x%04X result=%d",
            wasStick ? 1 : 0, wasDpad ? 1 : 0, arrowKey ? 1 : 0, wasdKey ? 1 : 0,
            buttons, result ? 1 : 0);
        s_lastDiagLog = now;
    }

    lua.pushboolean(L, result ? 1 : 0);
    return 1;
}

// DamageBeep: play a synthesized tone at given frequency and duration
static int Bridge_DamageBeep(lua_State* L)
{
    int freq = static_cast<int>(lua.tonumberx(L, 1, nullptr));
    int dur = static_cast<int>(lua.tonumberx(L, 2, nullptr));
    if (freq > 0 && dur > 0) {
        AudioFeedback::PlayTone(freq, dur);
    }
    return 0;
}

// DamageBeepArmor: play a noise-mixed tone for armor damage feedback
static int Bridge_DamageBeepArmor(lua_State* L)
{
    int freq = static_cast<int>(lua.tonumberx(L, 1, nullptr));
    int dur = static_cast<int>(lua.tonumberx(L, 2, nullptr));
    if (freq > 0 && dur > 0) {
        AudioFeedback::PlayNoiseTone(freq, dur);
    }
    return 0;
}

// ============================================================
// Public API
// ============================================================

namespace LuaWrappers {

void RegisterBridge(lua_State* L)
{
    Log::Debug("RegisterBridge: pushcclosure=%p setglobal=%p L=%p top=%d",
               (void*)lua.pushcclosure, (void*)lua.setglobal, L, lua.gettop(L));

    Log::Debug("RegisterBridge: step 1 - pushcclosure(TolkSpeak)");
    lua.pushcclosure(L, Bridge_TolkSpeak, 0);
    Log::Debug("RegisterBridge: step 2 - setglobal(TolkSpeak)");
    lua.setglobal(L, "TolkSpeak");

    Log::Debug("RegisterBridge: step 2b - pushcclosure(TolkSpeakQueue)");
    lua.pushcclosure(L, Bridge_TolkSpeakQueue, 0);
    Log::Debug("RegisterBridge: step 2c - setglobal(TolkSpeakQueue)");
    lua.setglobal(L, "TolkSpeakQueue");

    Log::Debug("RegisterBridge: step 3 - pushcclosure(TolkSilence)");
    lua.pushcclosure(L, Bridge_TolkSilence, 0);
    Log::Debug("RegisterBridge: step 4 - setglobal(TolkSilence)");
    lua.setglobal(L, "TolkSilence");

    Log::Debug("RegisterBridge: step 5 - pushcclosure(AccessibilityEnabled)");
    lua.pushcclosure(L, Bridge_AccessibilityEnabled, 0);
    Log::Debug("RegisterBridge: step 6 - setglobal(AccessibilityEnabled)");
    lua.setglobal(L, "AccessibilityEnabled");

    Log::Debug("RegisterBridge: step 7 - pushcclosure(LogEvent)");
    lua.pushcclosure(L, Bridge_LogEvent, 0);
    Log::Debug("RegisterBridge: step 8 - setglobal(LogEvent)");
    lua.setglobal(L, "LogEvent");

    Log::Debug("RegisterBridge: step 9 - pushcclosure(IsTraitNavInput)");
    lua.pushcclosure(L, Bridge_IsTraitNavInput, 0);
    Log::Debug("RegisterBridge: step 10 - setglobal(IsTraitNavInput)");
    lua.setglobal(L, "IsTraitNavInput");

    Log::Debug("RegisterBridge: step 11 - pushcclosure(DamageBeep)");
    lua.pushcclosure(L, Bridge_DamageBeep, 0);
    lua.setglobal(L, "DamageBeep");

    Log::Debug("RegisterBridge: step 12 - pushcclosure(DamageBeepArmor)");
    lua.pushcclosure(L, Bridge_DamageBeepArmor, 0);
    lua.setglobal(L, "DamageBeepArmor");

    Log::Info("Lua bridge registered (TolkSpeak, TolkSpeakQueue, TolkSilence, AccessibilityEnabled, LogEvent, IsTraitNavInput, DamageBeep, DamageBeepArmor)");
}

void ResetRefs()
{
    // No refs to reset - bridge functions are just globals, not registry refs.
    Log::Debug("ResetRefs called (no-op in simplified bridge)");
}

}
