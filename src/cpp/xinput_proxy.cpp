#include "xinput_proxy.h"
#include "logger.h"

// Define XInput types ourselves to avoid #include <Xinput.h> which uses
// __declspec(dllimport) and conflicts with our exported function definitions.
#pragma pack(push, 8)

typedef struct _XINPUT_GAMEPAD {
    WORD  wButtons;
    BYTE  bLeftTrigger;
    BYTE  bRightTrigger;
    SHORT sThumbLX;
    SHORT sThumbLY;
    SHORT sThumbRX;
    SHORT sThumbRY;
} XINPUT_GAMEPAD;

typedef struct _XINPUT_STATE {
    DWORD          dwPacketNumber;
    XINPUT_GAMEPAD Gamepad;
} XINPUT_STATE;

typedef struct _XINPUT_VIBRATION {
    WORD wLeftMotorSpeed;
    WORD wRightMotorSpeed;
} XINPUT_VIBRATION;

typedef struct _XINPUT_CAPABILITIES {
    BYTE             Type;
    BYTE             SubType;
    WORD             Flags;
    XINPUT_GAMEPAD   Gamepad;
    XINPUT_VIBRATION Vibration;
} XINPUT_CAPABILITIES;

typedef struct _XINPUT_BATTERY_INFORMATION {
    BYTE BatteryType;
    BYTE BatteryLevel;
} XINPUT_BATTERY_INFORMATION;

typedef struct _XINPUT_KEYSTROKE {
    WORD  VirtualKey;
    WCHAR Unicode;
    WORD  Flags;
    BYTE  UserIndex;
    BYTE  HidCode;
} XINPUT_KEYSTROKE;

#pragma pack(pop)

// Real XInput DLL handle and function pointers
static HMODULE s_realXInput = nullptr;

using fn_XInputGetState           = DWORD(WINAPI*)(DWORD, XINPUT_STATE*);
using fn_XInputSetState           = DWORD(WINAPI*)(DWORD, XINPUT_VIBRATION*);
using fn_XInputGetCapabilities    = DWORD(WINAPI*)(DWORD, DWORD, XINPUT_CAPABILITIES*);
using fn_XInputEnable             = void(WINAPI*)(BOOL);
using fn_XInputGetAudioDeviceIds  = DWORD(WINAPI*)(DWORD, LPWSTR, UINT*, LPWSTR, UINT*);
using fn_XInputGetBatteryInformation = DWORD(WINAPI*)(DWORD, BYTE, XINPUT_BATTERY_INFORMATION*);
using fn_XInputGetKeystroke       = DWORD(WINAPI*)(DWORD, DWORD, XINPUT_KEYSTROKE*);

static fn_XInputGetState           s_GetState           = nullptr;
static fn_XInputSetState           s_SetState           = nullptr;
static fn_XInputGetCapabilities    s_GetCapabilities    = nullptr;
static fn_XInputEnable             s_Enable             = nullptr;
static fn_XInputGetAudioDeviceIds  s_GetAudioDeviceIds  = nullptr;
static fn_XInputGetBatteryInformation s_GetBatteryInfo  = nullptr;
static fn_XInputGetKeystroke       s_GetKeystroke       = nullptr;

// Separate function pointer for POLLING controller state (accessibility input tracking).
// The game uses XINPUT9_1_0.dll which Steam Input hooks. Our forwarded exports use
// System32\xinput1_4.dll which Steam Input does NOT hook, so it returns
// ERROR_DEVICE_NOT_CONNECTED. For polling, we find the game's already-loaded
// XINPUT9_1_0.dll and call through it to get the Steam-Input-hooked version.
static fn_XInputGetState s_PollGetState = nullptr;
static bool s_pollInitAttempted = false;

// Input source tracking: distinguishes left stick from D-pad for accessibility.
// The TraitTrayScreen needs to know if cursor movement came from stick/arrows
// (read traits) vs D-pad/WASD (reserved for mod menus).
// Uses timestamp-based tracking: records when stick/dpad were last active,
// and the most recent one wins. Polled continuously from pcallk hook.
static ULONGLONG s_lastStickTime = 0;
static ULONGLONG s_lastDpadTime = 0;
static const SHORT STICK_DEADZONE = 7849;

namespace XInputProxy {

bool Init()
{
    wchar_t sysPath[MAX_PATH];
    GetSystemDirectoryW(sysPath, MAX_PATH);
    lstrcatW(sysPath, L"\\xinput1_4.dll");

    s_realXInput = LoadLibraryW(sysPath);
    if (!s_realXInput)
        return false;

    s_GetState          = reinterpret_cast<fn_XInputGetState>(GetProcAddress(s_realXInput, "XInputGetState"));
    s_SetState          = reinterpret_cast<fn_XInputSetState>(GetProcAddress(s_realXInput, "XInputSetState"));
    s_GetCapabilities   = reinterpret_cast<fn_XInputGetCapabilities>(GetProcAddress(s_realXInput, "XInputGetCapabilities"));
    s_Enable            = reinterpret_cast<fn_XInputEnable>(GetProcAddress(s_realXInput, "XInputEnable"));
    s_GetAudioDeviceIds = reinterpret_cast<fn_XInputGetAudioDeviceIds>(GetProcAddress(s_realXInput, "XInputGetAudioDeviceIds"));
    s_GetBatteryInfo    = reinterpret_cast<fn_XInputGetBatteryInformation>(GetProcAddress(s_realXInput, "XInputGetBatteryInformation"));
    s_GetKeystroke      = reinterpret_cast<fn_XInputGetKeystroke>(GetProcAddress(s_realXInput, "XInputGetKeystroke"));

    return true;
}

void Shutdown()
{
    if (s_realXInput) {
        FreeLibrary(s_realXInput);
        s_realXInput = nullptr;
    }
}

// Lazy-init: find the game's already-loaded XINPUT9_1_0.dll for polling.
// Must be called after game has fully loaded (not during DllMain).
static fn_XInputGetState GetPollFunction()
{
    if (s_PollGetState) return s_PollGetState;
    if (s_pollInitAttempted) return s_GetState; // fallback to forwarded DLL

    s_pollInitAttempted = true;

    // Try the game's XINPUT9_1_0.dll first (Steam Input hooks this one)
    HMODULE gameXInput = GetModuleHandleW(L"XINPUT9_1_0.dll");
    if (gameXInput) {
        auto fn = reinterpret_cast<fn_XInputGetState>(GetProcAddress(gameXInput, "XInputGetState"));
        if (fn) {
            s_PollGetState = fn;
            Log::Info("XInput polling: using game's XINPUT9_1_0.dll at %p", (void*)fn);
            return s_PollGetState;
        }
    }

    // Try lowercase variant (in case GetModuleHandle is case-sensitive on some systems)
    gameXInput = GetModuleHandleW(L"xinput9_1_0");
    if (gameXInput) {
        auto fn = reinterpret_cast<fn_XInputGetState>(GetProcAddress(gameXInput, "XInputGetState"));
        if (fn) {
            s_PollGetState = fn;
            Log::Info("XInput polling: using game's xinput9_1_0 at %p", (void*)fn);
            return s_PollGetState;
        }
    }

    // Fallback to our forwarded xinput1_4.dll
    Log::Info("XInput polling: XINPUT9_1_0.dll not found, using xinput1_4.dll fallback");
    return s_GetState;
}

WORD GetButtons()
{
    auto pollFn = GetPollFunction();
    if (!pollFn) return 0;
    XINPUT_STATE state = {};
    DWORD result = pollFn(0, &state); // Player 0
    if (result != ERROR_SUCCESS) return 0;
    return state.Gamepad.wButtons;
}

bool WasLastInputStick() { return s_lastStickTime > s_lastDpadTime && s_lastStickTime > 0; }
bool WasLastInputDpad()  { return s_lastDpadTime > s_lastStickTime && s_lastDpadTime > 0; }

void UpdateInputTracking()
{
    auto pollFn = GetPollFunction();
    if (!pollFn) return;
    XINPUT_STATE state = {};
    DWORD result = pollFn(0, &state);
    if (result != 0) return;  // ERROR_SUCCESS = 0

    // Record timestamps of when each input source was last active
    ULONGLONG now = GetTickCount64();

    WORD dpadBits = state.Gamepad.wButtons & 0x000F;
    if (dpadBits != 0) {
        s_lastDpadTime = now;
    }

    bool stickActive = (state.Gamepad.sThumbLX > STICK_DEADZONE ||
                       state.Gamepad.sThumbLX < -STICK_DEADZONE ||
                       state.Gamepad.sThumbLY > STICK_DEADZONE ||
                       state.Gamepad.sThumbLY < -STICK_DEADZONE);
    if (stickActive) {
        s_lastStickTime = now;
    }
}

} // namespace XInputProxy

// ============================================================
// Exported functions — forwarded to real xinput1_4.dll
// These are declared extern "C" and match the .def ordinals
// ============================================================

extern "C" {

DWORD WINAPI XInputGetState(DWORD dwUserIndex, XINPUT_STATE* pState)
{
    if (!s_GetState) return ERROR_DEVICE_NOT_CONNECTED;
    DWORD result = s_GetState(dwUserIndex, pState);

    // Track input source for player 0 (accessibility: stick vs D-pad)
    if (result == 0 && dwUserIndex == 0) {  // ERROR_SUCCESS = 0
        ULONGLONG now = GetTickCount64();

        WORD dpadBits = pState->Gamepad.wButtons & 0x000F;
        if (dpadBits != 0) {
            s_lastDpadTime = now;
        }

        bool stickActive = (pState->Gamepad.sThumbLX > STICK_DEADZONE ||
                           pState->Gamepad.sThumbLX < -STICK_DEADZONE ||
                           pState->Gamepad.sThumbLY > STICK_DEADZONE ||
                           pState->Gamepad.sThumbLY < -STICK_DEADZONE);
        if (stickActive) {
            s_lastStickTime = now;
        }
    }

    return result;
}

DWORD WINAPI XInputSetState(DWORD dwUserIndex, XINPUT_VIBRATION* pVibration)
{
    if (s_SetState) return s_SetState(dwUserIndex, pVibration);
    return ERROR_DEVICE_NOT_CONNECTED;
}

DWORD WINAPI XInputGetCapabilities(DWORD dwUserIndex, DWORD dwFlags, XINPUT_CAPABILITIES* pCapabilities)
{
    if (s_GetCapabilities) return s_GetCapabilities(dwUserIndex, dwFlags, pCapabilities);
    return ERROR_DEVICE_NOT_CONNECTED;
}

void WINAPI XInputEnable(BOOL enable)
{
    if (s_Enable) s_Enable(enable);
}

DWORD WINAPI XInputGetAudioDeviceIds(DWORD dwUserIndex, LPWSTR pRenderDeviceId, UINT* pRenderCount,
                                      LPWSTR pCaptureDeviceId, UINT* pCaptureCount)
{
    if (s_GetAudioDeviceIds) return s_GetAudioDeviceIds(dwUserIndex, pRenderDeviceId, pRenderCount, pCaptureDeviceId, pCaptureCount);
    return ERROR_DEVICE_NOT_CONNECTED;
}

DWORD WINAPI XInputGetBatteryInformation(DWORD dwUserIndex, BYTE devType, XINPUT_BATTERY_INFORMATION* pBatteryInfo)
{
    if (s_GetBatteryInfo) return s_GetBatteryInfo(dwUserIndex, devType, pBatteryInfo);
    return ERROR_DEVICE_NOT_CONNECTED;
}

DWORD WINAPI XInputGetKeystroke(DWORD dwUserIndex, DWORD dwReserved, XINPUT_KEYSTROKE* pKeystroke)
{
    if (s_GetKeystroke) return s_GetKeystroke(dwUserIndex, dwReserved, pKeystroke);
    return ERROR_DEVICE_NOT_CONNECTED;
}

} // extern "C"
