#pragma once
#include <cstdint>

// ============================================================
// Engine-menu accessibility (Title/Main, Pause, Settings, Save Select)
//
// These four menus are pure C++ engine screens (sgg::*Screen) with no Lua
// component table, so the OnMouseOverFunctionName + AttachLua mechanism used
// for in-game Lua menus cannot reach them. We locate their vtables via the
// MSVC RTTI walk of EngineWin64s.dll (resilient to codegen shifts — anchored
// on the stable class-name string, not raw prologue bytes) so we can later
// hook the selection path and narrate the highlighted item via Tolk.
//
// This module is currently READ-ONLY: it resolves and logs vtables. No engine
// functions are hooked yet.
// ============================================================

namespace EngineMenu {

// Resolve engine UI vtables via RTTI. Logs results. Returns count resolved.
int Init();

// Resolved vtable VA for an sgg class name (e.g. "PauseScreen"), or nullptr.
void* GetVtable(const char* className);

}
