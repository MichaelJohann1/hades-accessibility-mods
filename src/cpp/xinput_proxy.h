#pragma once
#include <Windows.h>

namespace XInputProxy {

bool Init();
void Shutdown();

// Poll the real XInput controller (player 0) and return the wButtons bitmask.
// Returns 0 if no controller is connected.
// Bits: DPAD_UP=0x0001, DPAD_DOWN=0x0002, DPAD_LEFT=0x0004, DPAD_RIGHT=0x0008,
//       START=0x0010, BACK=0x0020, A=0x1000, B=0x2000, X=0x4000, Y=0x8000
WORD GetButtons();

// Input source tracking for accessibility: distinguishes left stick from D-pad.
// Updated automatically by XInputGetState forwarding (player 0 only).
bool WasLastInputStick();
bool WasLastInputDpad();

// Actively poll controller state and update input source tracking.
// Call this before checking WasLastInputStick/Dpad if the exported XInputGetState
// may not be called by the game (engine uses XINPUT9_1_0.dll instead).
void UpdateInputTracking();

}
