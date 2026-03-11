#pragma once
#include "lua_bindings.h"

namespace EmbeddedMods {

// Load all embedded Lua mods in correct order.
// Returns number of mods successfully loaded.
// Must be called on game thread with valid L after bridge is registered.
int LoadAll(lua_State* L);

// Returns total number of embedded mods (available before LoadAll).
int GetModCount();

}
