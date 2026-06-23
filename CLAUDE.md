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
| `debug.h/cpp` | Subtitle toggle (backslash / R3 right-stick), damage feedback toggle (Shift+backslash / L3 left-stick), language detection, debug spawn keys (see `DEBUG_KEYS.md`) |
| `logger.h/cpp` | Thread-safe timestamped file logging |
| `path_resolver.h/cpp` | Finds exe dir, game root, speech DLLs |
| `tolk_loader.h/cpp` | Dynamic Tolk.dll loading |

### Key Scripts

| Script | Purpose | When to Run | Required? |
|--------|---------|-------------|-----------|
| `build.ps1` | Auto-detects Visual Studio, runs MSBuild (release; debug keys OFF) | Every build | Yes — builds the DLL |
| `build-debug.ps1` | Builds with debug keys ON (`ENABLE_DEBUG_KEYS`); auto-generates a matched `chaos.dat` + `chaos_hash.h` if missing | Only when you want debug keys for testing | No — developer tool |
| `generate_embedded_mods.py` | Reads all Lua mod source files from `src/lua/` and ModUtil from `src/modutil/`, generates `embedded_mods.cpp` with all mods as C++ raw string literals | After any Lua mod source change. Must run BEFORE `build.ps1`. | Yes — without this, the DLL has stale Lua code |
| `generate_language_files.py` | Combines game HelpText SJSON translations + manual UI translations (from `ui_translations/` JSON files) into `languages/{lang}.lua` files for 10 languages | After changing any hardcoded description table, UIStrings, or manual translation JSON. Requires game installed (reads HelpText SJSON from game directory). | Only for non-English users. English text is embedded in the Lua mods. Without these files, non-English players see English. |
| `generate_ui_translations.py` | Generates `ui_translations/{lang}.json` files containing manual translations for ~300 UI strings that don't exist in the game's HelpText (menu names, status labels, format strings, NPC names, etc.) | After adding new UIStrings entries or changing NPC/speaker name tables. Output is consumed by `generate_language_files.py`. | Only if you changed UI strings and need non-English support. Not needed at runtime — it feeds into `generate_language_files.py`. |
| `generate_subtitles.py` | Parses the game's subtitle CSV files from `Content/Subtitles/{lang}/` into `subtitles/{lang}.lua` lookup tables (~13K entries per language) | Only needs to run once (or after a game update that changes subtitle data). Requires game installed. | Only for expanded subtitle reading. Without these files, subtitles still work for on-screen dialogue but end-of-conversation remarks and ambient voice lines are silent. |
| `parse_game_text.py` | Parses `HelpText.en.sjson` to replace hardcoded descriptions in Lua mods with authoritative game text. Handles template variables (`{$Keywords.X}`, `{$TooltipData.X}`, etc.). | After adding new hardcoded descriptions or changing existing ones, to ensure they match the game's data. Run with `--apply` to update mod files in-place. | No — a developer tool. Descriptions are already baked into the Lua source. |

## Build & Deploy

1. **Generate embedded mods** (if any Lua source changed): `python scripts/generate_embedded_mods.py`
2. **Build**: `powershell -ExecutionPolicy Bypass -File scripts/build.ps1`
3. **Output**: `x64/Release/xinput1_4.dll`
4. **Deploy**: Copy DLL to `Steam\steamapps\common\Hades\x64\`. Game must be closed (DLL is locked while running).
5. **Speech DLLs**: `Tolk.dll` and `nvdaControllerClient64.dll` must also be in the game's `x64/` directory (not in this repo; obtain from a release or the Tolk project).
6. **Language files** (for non-English): `python scripts/generate_language_files.py`, then copy `languages/` folder to the game's `x64/` directory.
7. **Subtitle files** (for expanded voice line subtitles): `python scripts/generate_subtitles.py`, then copy `subtitles/` folder to the game's `x64/` directory. Requires the game to be installed (reads CSV files from `Content/Subtitles/`).

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

## Subtitle System

Hades has two separate dialogue pathways:

1. **`DisplayTextLine`** — shows text on screen with speaker portrait. The `line` parameter has `.Text` (localization key) and `.Cue` (audio path). Our Lua wrapper in AccessibleNotifications reads the text and speaks it. This covers all interactive NPC dialogue.

2. **`PlayVoiceLine`** — plays audio-only voice cues. The `line` parameter has ONLY `.Cue` (e.g. `/VO/Hades_0721`) with NO `.Text` field. This covers end-of-conversation remarks (EndCue/EndVoiceLines in Narrative.lua), ambient barks, quips, and standalone voice reactions.

### Why Lua Can't Resolve Voice Line Text

`PlayVoiceLine` voice cues cannot be resolved to text purely from Lua. Three approaches were tried and all fail:

1. **`GetDisplayName({Text = "Hades_0721"})`** — returns the key unchanged. Voice cue IDs are NOT localization keys. `GetDisplayName` only resolves keys that exist in the HelpText data; voice cue IDs are audio asset paths with no HelpText entries.

2. **Reading `line.Text`** — the `line` table passed to `PlayVoiceLine` has only a `.Cue` field. There is no `.Text`, `.Speaker`, or any other text-carrying field. The game's voice line data structures in AudioData.lua are pure audio metadata (cue path, cooldowns, requirements, animations) with no dialogue text.

3. **Looking up text from the parent dialogue system** — `PlayVoiceLine` is called independently from `DisplayTextLine`. End-of-conversation voice lines (EndCue/EndVoiceLines) fire AFTER the dialogue screen closes. There is no back-reference from the voice cue to the text line that preceded it, and EndCue lines are entirely separate dialogue entries with their own unique cue IDs.

The text for these voice cues exists only in the game's subtitle CSV files at `Content/Subtitles/{lang}/*.csv`, which are read by the game's C++ audio/subtitle engine but never exposed to Lua. The solution is to parse these CSV files at build time into a Lua lookup table and load it at runtime from C++.

### Subtitle Data Pipeline

1. **`generate_subtitles.py`** parses all CSV files from `Content/Subtitles/{lang}/` (37 files per language, ~13K entries) into `subtitles/{lang}.lua` files. Each file defines a `SubtitleData` global table mapping cue IDs to text strings.

2. **C++ `LoadSubtitleData()`** (debug.cpp) loads `x64/subtitles/{lang}.lua` at startup after language detection, with English fallback. Uses the same `luaL_loadbufferx` + `lua_pcallk` pattern as language file loading. Also reloads on Lua state reset (room transitions).

3. **Lua `PlayVoiceLine` wrapper** (AccessibleNotifications.lua) looks up `SubtitleData[dialogueId]` for each voice cue. If text is found and subtitles are enabled (`_SubtitleReadingEnabled`), speaks "Speaker: text". Speaker determined from the `source` parameter or `CuePrefixToSpeaker` table (maps cue prefixes like `ZagreusField` → `Zagreus`, `Storyteller` → `Narrator`).

### Key Details

- **CSV format**: `Status,Prefix,Number,FullID,,,,Text,,,Notes`. Column index 3 = cue ID, column index 7 = text. "Unused" status lines are skipped.
- **Deduplication**: 1-second cooldown on the same cue ID prevents double-speaking when both `DisplayTextLine` and `PlayVoiceLine` fire for the same dialogue line.
- **Translation**: `CuePrefixToSpeaker` is in `_LocalizableTables` (ZLocalizationCore.lua) so speaker names are translated. The subtitle text itself comes from the game's own per-language CSV files, so it's automatically in the correct language.
- **File sizes**: ~727 KB per language (English), ~13K entries each. All 11 languages total ~8.5 MB on disk.
- **Without subtitle files**: The `PlayVoiceLine` wrapper silently skips (SubtitleData is nil/empty). Only `DisplayTextLine` subtitles work. No errors.

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

**Companion descriptions use a local copy** — the global `KeepsakeDescriptions` companion entries can be reverted to old strings at runtime by an as-yet-unidentified mechanism (the old text exists in no loaded file, and English sessions load no language overlay). AccessibleKeepsakes therefore keeps the 6 companion entries in a `local CompanionDescriptions` upvalue that `BuildKeepsakeSpeech` reads from (immune to the global being clobbered) and mirrors them into the global only for cross-mod reads. Only the four PropertyChange companions (Battie/Mort/Shady/Antos) have rarity-scaled damage: their extracted `TooltipDamage` (off `button.TraitData`) is the BASE, multiplied by the companion level (`GetKeepsakeLevel` = the rarity multiplier 1–5). Rib's decoy Health (`TooltipHealth`) and Fidi's duration + hard-coded 70 damage (`TooltipDuration`) come from FIXED summon units — `SkellyAssist`/`DusaAssist` spawn fixed enemies (`TrainingMeleeSummon`/`DusaSummon`, `SkipModifiers`) with no rarity scaling — so they are shown unscaled. Root cause of the global revert is still open.

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
