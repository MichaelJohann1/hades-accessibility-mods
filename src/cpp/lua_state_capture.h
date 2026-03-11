#pragma once
#include <Windows.h>
#include "lua_bindings.h"

namespace LuaStateCapture {

bool InstallHook();
void RemoveHook();
bool WaitForState(DWORD timeoutMs);

lua_State* GetState();
bool IsReady();

// How many GetProcAddress calls for Lua functions we intercepted
int GetInterceptCount();

// Callback registration — called on the game thread after each lua_pcallk
using PostPcallCallback = void(*)(lua_State* L);
void SetPostPcallCallback(PostPcallCallback callback);

// MinHook trampolines for the engine's pcallk/callk/getglobal.
// Phase 1 finds these functions via hardcoded correct patterns and hooks them —
// which patches their prologues, causing Phase 5's lua52.dll-based scan to either
// miss them (pcallk/callk) or find a false match (getglobal). These trampolines
// call the original engine code directly and are the authoritative pointers.
fn_lua_pcallk    GetOriginalPcallk();
fn_lua_callk     GetOriginalCallk();
fn_lua_getglobal GetOriginalGetglobal();

}
