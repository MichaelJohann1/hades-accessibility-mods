#pragma once
#include "lua_bindings.h"

namespace LuaWrappers {

// Register the Lua bridge functions (TolkSpeak, TolkSilence, AccessibilityEnabled)
void RegisterBridge(lua_State* L);

// Reset state for re-registration after Lua state reset
void ResetRefs();

}
