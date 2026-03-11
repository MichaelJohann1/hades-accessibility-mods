#pragma once
#include <cstdint>
#include <cstddef>
#include <Windows.h>

// ============================================================
// Lua 5.2 type definitions (matching ABI)
// ============================================================

typedef struct lua_State lua_State;
typedef int (*lua_CFunction)(lua_State* L);
typedef ptrdiff_t lua_Integer;
typedef double lua_Number;
typedef int (*lua_KFunction)(lua_State* L, int status, intptr_t ctx);

// Lua 5.2 type constants
#define LUA_OK              0
#define LUA_YIELD           1
#define LUA_ERRRUN          2
#define LUA_ERRSYNTAX       3
#define LUA_ERRMEM          4
#define LUA_ERRGCMM         5
#define LUA_ERRERR          6

// Lua type tags
#define LUA_TNONE          (-1)
#define LUA_TNIL            0
#define LUA_TBOOLEAN        1
#define LUA_TLIGHTUSERDATA  2
#define LUA_TNUMBER         3
#define LUA_TSTRING         4
#define LUA_TTABLE          5
#define LUA_TFUNCTION       6
#define LUA_TUSERDATA       7
#define LUA_TTHREAD         8

// Lua 5.2 pseudo-indices
#define LUA_REGISTRYINDEX   (-1001000)

// ============================================================
// Function pointer typedefs (Lua 5.2 signatures)
// ============================================================

using fn_lua_pcallk      = int(*)(lua_State*, int, int, int, intptr_t, lua_KFunction);
using fn_lua_callk       = void(*)(lua_State*, int, int, intptr_t, lua_KFunction);
using fn_lua_getglobal   = void(*)(lua_State*, const char*);
using fn_lua_setglobal   = void(*)(lua_State*, const char*);
using fn_lua_getfield    = void(*)(lua_State*, int, const char*);
using fn_lua_setfield    = void(*)(lua_State*, int, const char*);
using fn_lua_gettable    = void(*)(lua_State*, int);
using fn_lua_settable    = void(*)(lua_State*, int);
using fn_lua_next        = int(*)(lua_State*, int);
using fn_lua_tolstring   = const char*(*)(lua_State*, int, size_t*);
using fn_lua_type        = int(*)(lua_State*, int);
using fn_lua_typename    = const char*(*)(lua_State*, int);
using fn_lua_settop      = void(*)(lua_State*, int);
using fn_lua_gettop      = int(*)(lua_State*);
using fn_lua_pushstring  = const char*(*)(lua_State*, const char*);
using fn_lua_pushcclosure = void(*)(lua_State*, lua_CFunction, int);
using fn_lua_pushvalue   = void(*)(lua_State*, int);
using fn_lua_pushnil     = void(*)(lua_State*);
using fn_lua_pushinteger = void(*)(lua_State*, lua_Integer);
using fn_lua_pushnumber  = void(*)(lua_State*, lua_Number);
using fn_lua_pushboolean = void(*)(lua_State*, int);
using fn_lua_rawgeti     = void(*)(lua_State*, int, int);
using fn_lua_rawseti     = void(*)(lua_State*, int, int);
using fn_lua_rawget      = void(*)(lua_State*, int);
using fn_lua_rawset      = void(*)(lua_State*, int);
using fn_lua_createtable = void(*)(lua_State*, int, int);
using fn_luaL_ref        = int(*)(lua_State*, int);
using fn_luaL_unref      = void(*)(lua_State*, int, int);
using fn_lua_isstring    = int(*)(lua_State*, int);
using fn_lua_isnumber    = int(*)(lua_State*, int);
using fn_lua_tonumberx   = lua_Number(*)(lua_State*, int, int*);
using fn_lua_tointegerx  = lua_Integer(*)(lua_State*, int, int*);
using fn_lua_toboolean   = int(*)(lua_State*, int);
using fn_lua_objlen      = size_t(*)(lua_State*, int); // lua_rawlen in 5.2
using fn_lua_insert      = void(*)(lua_State*, int);
using fn_lua_remove      = void(*)(lua_State*, int);
using fn_luaL_loadbufferx = int(*)(lua_State*, const char*, size_t, const char*, const char*);

// ============================================================
// Global function pointer table
// ============================================================

struct LuaAPI {
    fn_lua_pcallk       pcallk       = nullptr;
    fn_lua_callk        callk        = nullptr;
    fn_lua_getglobal    getglobal    = nullptr;
    fn_lua_setglobal    setglobal    = nullptr;
    fn_lua_getfield     getfield     = nullptr;
    fn_lua_setfield     setfield     = nullptr;
    fn_lua_gettable     gettable     = nullptr;
    fn_lua_settable     settable     = nullptr;
    fn_lua_next         next         = nullptr;
    fn_lua_tolstring    tolstring    = nullptr;
    fn_lua_type         type         = nullptr;
    fn_lua_typename     type_name    = nullptr;
    fn_lua_settop       settop       = nullptr;
    fn_lua_gettop       gettop       = nullptr;
    fn_lua_pushstring   pushstring   = nullptr;
    fn_lua_pushcclosure pushcclosure = nullptr;
    fn_lua_pushvalue    pushvalue    = nullptr;
    fn_lua_pushnil      pushnil      = nullptr;
    fn_lua_pushinteger  pushinteger  = nullptr;
    fn_lua_pushnumber   pushnumber   = nullptr;
    fn_lua_pushboolean  pushboolean  = nullptr;
    fn_lua_rawgeti      rawgeti      = nullptr;
    fn_lua_rawseti      rawseti      = nullptr;
    fn_lua_rawget       rawget       = nullptr;
    fn_lua_rawset       rawset       = nullptr;
    fn_lua_createtable  createtable  = nullptr;
    fn_luaL_ref         ref          = nullptr;
    fn_luaL_unref       unref        = nullptr;
    fn_lua_isstring     isstring     = nullptr;
    fn_lua_isnumber     isnumber     = nullptr;
    fn_lua_tonumberx    tonumberx    = nullptr;
    fn_lua_tointegerx   tointegerx   = nullptr;
    fn_lua_toboolean    toboolean    = nullptr;
    fn_lua_objlen       rawlen       = nullptr; // lua_rawlen
    fn_lua_insert       insert       = nullptr;
    fn_lua_remove       remove       = nullptr;
    fn_luaL_loadbufferx loadbufferx  = nullptr;
};

// ============================================================
// Public API
// ============================================================

namespace LuaBindings {

bool Init();
bool IsReady();
HMODULE GetModule();  // Returns the discovered Lua module handle (after Init succeeds)

}

// Global Lua API table — accessible from all modules
extern LuaAPI lua;

// Convenience macros
#define lua_pop(L, n)    lua.settop(L, -(n)-1)
#define lua_pcall(L, n, r, ef) lua.pcallk(L, n, r, ef, 0, nullptr)
#define lua_call(L, n, r)      lua.callk(L, n, r, 0, nullptr)
