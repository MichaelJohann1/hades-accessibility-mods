# Debug Keys

Debug keys are developer tools for testing accessibility mods. They are disabled by default and require a `chaos.dat` gate file to activate (see below).

## Enabling Debug Keys

Debug keys require two things:

1. **Build with `ENABLE_DEBUG_KEYS` defined** — add `/D ENABLE_DEBUG_KEYS` to your MSBuild command or define it in the project settings. Public release builds do NOT define this flag, so debug key code is excluded from the DLL entirely.

2. **Generate and deploy `chaos.dat`** — run `python scripts/generate_chaos_dat.py` from the repo root. This creates a `chaos.dat` file (8 KB) that must be placed in the game's `x64/` directory alongside the DLL. The file contains a random key validated via SHA-256 hash at runtime. The hash is baked into the DLL at compile time, so the DLL and `chaos.dat` must be a matched pair — regenerating `chaos.dat` requires rebuilding the DLL.

Without both of these, debug keys are silently disabled.

## Key Bindings

### Function Keys (Spawn Boons)

| Key | Action |
|-----|--------|
| F1 | Spawn Zeus boon |
| F2 | Spawn Poseidon boon |
| F3 | Spawn Athena boon |
| F4 | Spawn Ares boon |
| F5 | Spawn Aphrodite boon |
| F6 | Spawn Artemis boon |
| F7 | Spawn Dionysus boon |
| F8 | Spawn Hermes boon |
| F9 | Spawn Demeter boon |
| F10 | Spawn Daedalus Hammer upgrade |
| F11 | Spawn Pom of Power |
| F12 | Spawn Well of Charon |

### Number Keys (Utilities)

| Key | Action |
|-----|--------|
| 0 | Spawn healing fountain (biome-appropriate) |
| 1 | Spawn Chaos Gate |
| 2 | Spawn NPC room (Sisyphus/Eurydice/Patroclus, biome-appropriate) |
| 3 | Open Weapon Upgrade screen |
| 4 | Open Sell Trait (Pool of Purging) screen |
| 5 | Trigger Run Clear screen |
| 6 | Grant 1M of each resource + 1M Obols + max Adamant Rail + 1B health |
| 7 | Trigger flashback 1 (clears PlayOnce flags, re-triggers bed prompt) |
| 8 | Trigger flashback 2 (same as 7 + sets Mother_01 prerequisite) |
| 9 | Spawn fishing point in current room |

### Notes

- Debug keys use edge detection — press and release to trigger; holding does not repeat.
- Key 6 effects partially reset on room transitions: resources and weapon unlocks persist (saved to GameState), but health resets (game recalculates from traits) and enemies spawn fresh. Press 6 again each room if needed.
- Keys 7/8 clear `GameState.TextLinesRecord` entries for the flashback text lines to bypass `PlayOnce = true` blocking, and use hardcoded bed object IDs (310036 default, 555810 fancy).
- The Lua side of debug keys is in `src/lua/DebugKeys/DebugKeys.lua` — a polling thread checks flag globals every 0.1 seconds.
- The C++ side is in `src/cpp/debug.cpp` — `CheckDebugKeys()` sets Lua globals via `lua_pushboolean` + `lua_setglobal`, protected by SEH.
