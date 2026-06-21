# Debug Keys

Debug keys are developer tools for testing accessibility mods. They are disabled by default and require a `chaos.dat` gate file to activate (see below).

## Enabling Debug Keys

Debug keys are excluded from public release builds. To make a debug build:

1. Run **`scripts/build-debug.ps1`**. It generates a matched `chaos.dat` + `chaos_hash.h` (the SHA-256 is baked into the DLL automatically — no manual editing of `debug.cpp`), then builds the DLL with `ENABLE_DEBUG_KEYS` defined.
2. Deploy **both** the built `xinput1_4.dll` **and** `chaos.dat` to the game's `x64/` directory. They are a matched pair: the DLL only enables debug keys when the exact `chaos.dat` it was built against is present.

Without `chaos.dat` next to the DLL, debug keys stay silently disabled. `build-debug.ps1` regenerates `chaos.dat` if it's missing.

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

### Other Keys

| Key | Action |
|-----|--------|
| `]` | Grant all 6 companions (Megaera, Achilles, Thanatos, Sisyphus, Skelly, Dusa). First press sets them to level 1; each subsequent press raises every companion one level (cap 5). For testing the keepsake-case level text. |

### Notes

- Debug keys use edge detection — press and release to trigger; holding does not repeat.
- Key 6 effects partially reset on room transitions: resources and weapon unlocks persist (saved to GameState), but health resets (game recalculates from traits) and enemies spawn fresh. Press 6 again each room if needed.
- Keys 7/8 clear `GameState.TextLinesRecord` entries for the flashback text lines to bypass `PlayOnce = true` blocking, and use hardcoded bed object IDs (310036 default, 555810 fancy).
- The Lua side of debug keys is in `src/lua/DebugKeys/DebugKeys.lua` — a polling thread checks flag globals every 0.1 seconds.
- The C++ side is in `src/cpp/debug.cpp` — `CheckDebugKeys()` sets Lua globals via `lua_pushboolean` + `lua_setglobal`, protected by SEH.
