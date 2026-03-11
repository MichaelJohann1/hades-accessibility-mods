# Hades Accessibility Project

> **IMPORTANT**: Read this entire file before making changes. It contains critical architecture decisions, crash history, and conventions that you must understand.

## Overview

Native C++ accessibility layer for Hades (Supergiant Games) that hooks the game's Lua 5.2 runtime via DLL proxy injection to provide universal screen reader support via Tolk.

## Project Structure

```
src/cpp/          C++ DLL source (xinput1_4.dll proxy)
src/lua/          Lua accessibility mods (29 mods)
src/modutil/      ModUtil v2.10.0 (dependency, loaded first)
vendor/MinHook/   MinHook hooking library (BSD 2-Clause)
scripts/          Build and code generation scripts
```

### Key C++ Files

| File | Purpose |
|------|---------|
| `dllmain.cpp` | DLL entry, worker thread launch |
| `xinput_proxy.h/cpp` | Loads real xinput1_4.dll from System32, forwards XInput calls |
| `accessibility_core.h/cpp` | Worker thread orchestrator (8-phase init + embedded mod loading) |
| `lua_state_capture.h/cpp` | MinHook detour on engine Lua functions + re-entrancy guard |
| `lua_bindings.h/cpp` | Lua 5.2 API resolution: Phase 1 trampolines + lua52.dll |
| `lua_wrappers.h/cpp` | C closures replacing 6 Lua globals + 8 bridge functions |
| `embedded_mods.h` | Header for embedded Lua mod data (cpp is auto-generated) |
| `audio_feedback.h/cpp` | waveOut tone synthesis for damage feedback |
| `debug.h/cpp` | Subtitle toggle, damage feedback toggle, language detection |
| `logger.h/cpp` | Thread-safe timestamped file logging |
| `path_resolver.h/cpp` | Finds exe dir, game root, speech DLLs |
| `tolk_loader.h/cpp` | Dynamic Tolk.dll loading |

### Key Scripts

| Script | Purpose |
|--------|---------|
| `generate_embedded_mods.py` | Reads all Lua source → generates `embedded_mods.cpp` |
| `build.ps1` | Auto-detects Visual Studio, runs MSBuild |
| `generate_language_files.py` | Generates `languages/{lang}.lua` from game text + manual translations |
| `generate_ui_translations.py` | Generates UI string translation JSON files |
| `parse_game_text.py` | Parses HelpText.en.sjson to update mod descriptions |

## Build & Deploy

1. **Generate embedded mods** (if any Lua source changed): `python scripts/generate_embedded_mods.py`
2. **Build**: `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`
3. **Output**: `x64/Release/xinput1_4.dll`
4. **Deploy**: Copy DLL to `Steam\steamapps\common\Hades\x64\`. Game must be closed (DLL is locked while running).
5. **Speech DLLs**: `Tolk.dll` and `nvdaControllerClient64.dll` must also be in the game's `x64/` directory (not in this repo; obtain from a release or the Tolk project).

## Architecture

### DLL Proxy Injection

The DLL masquerades as `xinput1_4.dll`. The game loads it for XInput; it forwards all 7 XInput calls to the real System32 DLL while running the accessibility layer on a worker thread.

### CRITICAL: Two Lua Copies

Hades has TWO copies of Lua 5.2:

1. **Engine's Lua**: Statically linked inside `EngineWin64s.dll`. The engine's `lua_State*` belongs here.
2. **lua52.dll**: A separate DLL loaded by the .NET/NLua layer. Has extra `luanet_*` exports.

**Rules:**
- **MUST use engine's Lua for VM dispatch** (`pcallk`, `callk`, `getglobal`): calling lua52.dll versions on the engine's `lua_State*` crashes.
- **Everything else is safe from lua52.dll**: struct layouts are identical. Push/pop, table access, etc. work fine.
- **NEVER re-add engine pattern scanning** using lua52.dll prologues. They have different compiler settings and ALWAYS produce false matches that corrupt the Lua stack. This was tried extensively and caused multiple crashes (see Crash History below).

### Initialization Sequence (8 phases)

1. Hook `lua_pcallk`, `lua_callk`, `lua_getglobal` in `EngineWin64s.dll` via hardcoded patterns + MinHook
2. Wait 3s for game init
3. PathResolver::Init() — finds exe dir, game root
4. TolkLoader::Init() — loads Tolk.dll, speaks startup message
5. LuaBindings::Init() — Phase 1 trampolines for pcallk/callk/getglobal; lua52.dll for all other functions
6. Wait for Lua state capture via hook callbacks
7. Install Lua wrappers (deferred retry until game scripts are loaded)
8. Main loop — piggybacks on pcallk hook for ongoing work

### Lua Function Wrapping

Six game functions are wrapped via `lua_getglobal` → `luaL_ref` → `lua_pushcclosure` → `lua_setglobal`:

| Function | Purpose |
|----------|---------|
| `OnScreenOpened` | Screen tracking |
| `OnScreenClosed` | Screen tracking |
| `DisplayTextLine` | Pass-through in C++; Lua handles subtitle speech |
| `CreateTextBox` | Text capture + selective speech |
| `ModifyTextBox` | Text update capture |
| `TeleportCursor` | Focus tracking |

### Lua Bridge (8 global functions for mods)

| Function | Purpose |
|----------|---------|
| `TolkSpeak(text)` | Speak text (interrupts current speech) |
| `TolkSpeakQueue(text)` | Speak text (queues, doesn't interrupt) |
| `TolkSilence()` | Stop current speech |
| `AccessibilityEnabled()` | Returns true if Tolk is available |
| `LogEvent(text)` | Write to log file (no speech) |
| `IsTraitNavInput()` | Returns true if arrow/WASD pressed |
| `DamageBeep(freq, dur)` | Play synthesized tone |
| `ArmorHitSound()` | Play embedded armor hit WAV |

### Thread Safety

- Lua is NOT thread-safe. All Lua access happens on the game thread via the pcallk/callk hooks.
- SpeechManager::Speak() is thread-safe (mutex), callable from any thread.
- Worker thread handles initialization only; ongoing work piggybacks on hook callbacks.

### Embedded Mods

All 29 Lua mods + ModUtil v2.10.0 are compiled into the DLL as C++ raw string literals. No external `.lua` files needed. `generate_embedded_mods.py` generates `embedded_mods.cpp`. MSVC raw strings are chunked at 15000 bytes to avoid C2026.

After a Lua state reset (room transitions, save loads), the bridge and all mods are automatically re-installed via periodic probing (every 50 pcallk calls).

## Critical Conventions

### Lua Mod Patterns

**Nil-safety guard** — ALL mods must use this pattern:
```lua
if not AccessibilityEnabled or not AccessibilityEnabled() then return end
```
NOT `if not AccessibilityEnabled()` — that crashes when the bridge hasn't registered yet.

**OnMouseOverFunctionName** — the CORRECT mechanism for cursor navigation callbacks. `OnHighlightedFunctionName` does NOT exist in Hades.

**AttachLua is REQUIRED** — after setting `OnMouseOverFunctionName` on a component, you MUST call:
```lua
AttachLua({ Id = comp.Id, Table = comp })
```
Without it, the engine can't find the Lua table and OnMouseOver never fires.

**No table.concat** — ModUtil v2.10.0 overrides `table.concat` with a buggy version (weak-value cache with `rawnext` returns key instead of value). Use manual `ipairs` loops for string concatenation.

**StripFormatting** — must replace health icon tags with readable text BEFORE the generic `{![^}]*}` strip. Also strip `\\n` (literal) and `\n` (actual newlines).

**Hardcoded descriptions required** — `GetDisplayName`, `GetTraitTooltip`, and `GetTraitTooltipTitle` return unresolvable localization keys for most game content. The engine resolves descriptions via `UseDescription = true` in `CreateTextBoxWithFormat` at C++ render time — not accessible from Lua. All descriptions must be hardcoded from game data.

**Cross-mod global tables** — these tables are made global for cross-mod access: `BoonDisplayNames`, `GodBoonDescriptions`, `HammerDescriptions`, `ChaosBlessingDescriptions`, `ChaosCurseDescriptions`, `WellItemNames`, `WellItemDescriptions`, `KeepsakeDescriptions`.

### Menu Mod Pattern

Custom accessibility menus follow this pattern:
- Local `_menuOpen` tracking variable (NOT `IsScreenOpen` — has false positives on some saves)
- Bridge guard on control handler
- FreeFormSelect for cursor movement with specific config (StepDistance=8, SuccessDistanceStep=80)
- `OnMouseOverFunctionName` + `AttachLua` on all buttons
- `screen.justOpened` flag to suppress first OnMouseOver
- `_AccessibleNavUp`/`_AccessibleNavDown` boundary enforcement threads
- `FreeFormSelectWrapY = false` (no cursor wrapping)

### C++ Conventions

- All Lua string pointers must be copied to `std::string` before any stack manipulation (dangling pointer risk)
- `LUA_TNONE = -1`, `LUA_TNIL = 0` — these are DIFFERENT. Guards must check both.
- `thread_local int s_callDepth` prevents hook re-entrancy
- SEH (`__try/__except`) around all callback invocations
- RegisterBridge/Install have inner SEH with retry-on-crash + backoff (500 callbacks)
- Use callback's L (guaranteed alive), NOT `GetState()` which may return a GC'd dangling pointer

## Crash History (Critical Lessons)

These are the most important crashes to understand — they inform why the code is structured the way it is:

1. **False engine pattern matches**: Engine pattern scanning using lua52.dll prologues consistently matched wrong functions (different compiler settings). Calling them corrupted the Lua stack (top went negative, GC crashed). **Solution**: Removed engine scanning entirely. Use Phase 1 MinHook trampolines for pcallk/callk/getglobal; lua52.dll for everything else.

2. **Dangling Lua state pointer**: `LuaStateCapture::GetState()` returns the first L captured, which was a short-lived engine coroutine that got GC'd. Using it always crashed. **Solution**: Use callback's L parameter (guaranteed alive).

3. **RegisterBridge on tiny-stack coroutine**: Early pcallk callbacks come from engine-internal coroutines with tiny stacks. `lua_pushcclosure` crashes on them. **Solution**: Only register when `OnScreenOpened` is non-nil (game scripts loaded, safe coroutine).

4. **ModUtil v2.10.0 freeze**: Old ModUtil (pre-2.10.0) caused game hard-freeze on room transitions after Hades Patch 057. It overrides global `next` function and replaces `_G`'s metatable. **Solution**: Use ModUtil v2.10.0 from GitHub, never the old single-file version.

5. **WrapGlobalFunction rejecting tables**: ModUtil wraps functions into `LUA_TTABLE` (5) callable dispatch tables. `WrapGlobalFunction` must accept both `LUA_TFUNCTION` (6) and `LUA_TTABLE` (5).

6. **PurchaseConsumableItem parameter mismatch**: `ModUtil.WrapBaseFunction` prepends `baseFunc` to the parameter list. If the wrapper has wrong parameter names, all args shift and nil crashes result downstream.

## Hades Game Internals

### Key Lua Globals

- `ActiveScreens` — screen flag → screen object mapping
- `ScreenAnchors` — screen instances with `.Components`
- `GameState`, `CurrentRun` — game state
- `GetDisplayName({ Text = key })` — resolves localization keys (limited — many keys unresolvable)
- `OnScreenOpened`, `OnScreenClosed` — defined by game scripts, nil during early init
- `MetaUpgradeOrder`, `MetaUpgradeData` — Mirror of Night data

### Screen Flags

| Screen | Flag |
|--------|------|
| Mirror of Night | `MetaUpgrade` |
| Pact of Punishment | `ShrineUpgrade` |
| House Contractor | `GhostAdmin` |
| Codex | `Codex` |
| Boon Selection | `BoonMenu` |
| Keepsake Display | `AwardMenu` |
| Wretched Broker | `Market` |
| Well of Charon | `Store` |
| Fated List | `QuestLog` |
| Run Tracker | `GameStats` |

### Navigation System

- `OnMouseOverFunctionName` — set on component tables. Global handler in UIScripts.lua fires for ALL components.
- `FreeFormSelect` — engine cursor system for gamepad navigation.
- `HandleWASDInput` — polling loop for keyboard navigation on most screens.
- Handler signature: `function(button)` — receives ONLY the button table, NOT `(screen, button)`.

## External Dependencies

| Dependency | License | Integration |
|-----------|---------|-------------|
| MinHook | BSD 2-Clause | Compiled in-tree (`vendor/MinHook/`) |
| ModUtil v2.10.0 | MIT | Embedded in DLL (`src/modutil/`) |
| Tolk.dll | LGPL | Runtime LoadLibrary (not in repo) |
| nvdaControllerClient64.dll | GPL | Loaded by Tolk (not in repo) |
