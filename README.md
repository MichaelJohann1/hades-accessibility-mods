# Making Hades Accessible

This guide will show you how to install and use the Hades accessibility mods.

Note: This guide assumes that you have Hades already installed. If you need help with Hades's installation, your search engine of choice is the answer.

Extra note: This guide will focus on the Steam build because it's the most used client among the blind.

## Requirements

- An official copy of Hades
- Your preferred screen reader

## Installing the Mods

### Using the Installer

Download the installer [here](https://github.com/MichaelJohann1/hades-accessibility-mods-installer/releases/latest/download/HadesAccessibilityInstaller.exe). Run the installer. It will ask you to browse for your game directory. If it already has your game directory shown, just tab to Install and press Enter. There are also 2 checkboxes for the readme and changelog if you'd like to save them to the folder the installer is in. Once the mods are installed, an Open Debug Log Folder button will be available to open the folder containing debug log files.

### Removing Old Mods

If you have any previous version of the accessibility mods installed that used the Content\Mods folder, the installer will automatically detect and remove these old files for you. This includes the Mods folder, modimporter.py, and mod.log. The new version embeds all mods directly in the DLL, so the Content\Mods folder is no longer needed. Having old mods present causes conflicts including game freezes on room transitions and mod menus not opening.

If you are installing manually, delete the following from your Hades game\Content folder:

- The Mods folder
- modimporter.py
- mod.log (if present)

### Manual Installation

Download the latest mod release [here](https://github.com/MichaelJohann1/hades-accessibility-mods/releases/latest). Copy all the DLL files (xinput1_4.dll, Tolk.dll, nvdaControllerClient64.dll) to your Hades install folder's x64 directory. For example: `C:\Program Files (x86)\Steam\steamapps\common\Hades\x64`

## Using the Mods

All in-game menus now have screen reader support through Tolk. When you navigate menus, items and descriptions will be spoken automatically by your screen reader.

Press the backslash key (\\) to toggle subtitle reading on or off. When enabled, all dialogue text will be spoken with the speaker's name (e.g. "Achilles: I hope you're well, lad.").

Subtitles are off by default. Your preference is saved automatically and will persist across game sessions. If you turn subtitles on, they will stay on the next time you launch the game.

The following menus are engine-level menus and are not accessible. These are not in-game menus and cannot be made accessible through modding:

- Main Menu / Title Screen
- Pause Menu
- Settings Menu
- Save File Select

For a guide on navigating these menus, click [here](https://blackscreengaming.com/hades/menus/index.php). If you are new to Hades, it is highly recommended that you read this guide before starting the game.

## Mod Keystrokes

### Game Controller

Hit the select button on your Xbox controller to get to the following menus:

- D-pad up to check your resources such as health, darkness, etc. Navigate items with D-pad up and down.
- D-pad down to open up the rewards menu to access rewards such as those that pop up after completing a chamber and god boons at the start of a run. You can also use this menu to access infernal troves, wells of Charon, pools of purging, and the curing poison fountains at the Temple of Styx during a chamber run. Note: each item in the rewards menu can be selected by pressing the A button on your controller. You'll be teleported to the item that you've chosen and you can interact with it by pressing the interact button (RB) on your controller.
- D-pad right to access the items in Charon's shop. Note: Press A to teleport to the selected item on the menu and interact with it by using the interact button (RB) on your controller.
- D-pad left to access the doors menu. Note: when a door is selected, you're automatically teleported to it.
- Open the Codex (LB) then press right trigger (RT) to access the relationships menu. Navigate items with D-pad up and down.

You can press B on your controller to exit out of a menu without selecting anything.

While in the House of Hades, hitting the select button instantly brings up the rewards menu, and hitting the special attack button (Y) on the controller brings up the resources menu. These keystrokes are specific only while within the House of Hades.

The rewards menu in the House of Hades now opens in the room you are currently in. Each room includes objects that are only available in that room. In the main hall, the Mirror of Night and a door to the bedroom are available. In the bedroom, the Bed, Orpheus's Lyre, the Scrying Pool, and doors to the main hall and courtyard are available when unlocked. In the admin office, the Run Tracker, Run History, Water Cooler, Office Posters, and a door to the main hall are available. Inspect points are now also included in the rewards menu.

### Keyboard

Press B on your keyboard and the following keys to access the following menus:

- W to check your resources such as health, darkness, etc. Navigate items with W and S.
- S to open up the rewards menu to access rewards such as those that pop up after completing a chamber. You can also use this menu to access god boons at the start of a run, infernal troves, wells of Charon, pools of purging, and the curing poison fountains at the Temple of Styx during a chamber run. Note: each item in the rewards menu can be selected by pressing the spacebar on your keyboard. You'll be teleported to the item that you've chosen and you can interact with it by pressing E.
- D to access the items in Charon's shop. Note: Press the spacebar to teleport to the selected item on the menu and interact with it by pressing E.
- A to access the doors menu. When a door is selected, you're automatically teleported to it.
- Open the Codex (C) then right click to access the relationships menu. Navigate items with W and S.

Note: You can press backspace to exit out of a menu without selecting anything.

While in the House of Hades, hitting the B key on the keyboard instantly brings up the rewards menu, and hitting the special attack key (Q) on the keyboard brings up the resources menu. These keystrokes are specific only while within the House of Hades.

Extra note: JAWS users: Note that JAWS intercepts the escape and backspace keys, so if you need to pause or cancel, either use key pass-through, or use shift-escape and shift-backspace instead.

## Passive Mods

There are two mods in the package which do not have keystrokes, as they work in the background:

- NoTrapDamage: Makes Zagreus immune to damage from traps and standing magma. It is near impossible for a blind player to avoid these, so the mod prevents them getting in the way of gameplay.
- GodGaugeSounds: Plays audible cues to indicate the charging status of the god gauge, which is used by Zagreus to evoke a god's aid. As the gauge charges, a ding is played to indicate one charge is available, 2 dings when 2 charges are available, etc., until the entire gauge is full to maximum, at which point a more prominent alert is played.

## Extra Resources

Aaron77 and hllf worked on an excellent Hades video tutorial which you can find [here](https://youtu.be/G05IHIRLAgE).

## Support

If you have bugs that make the game or the mod not playable, or you notice the mod is missing something, please send a log to the Hades support channel on [this Discord server](https://discord.gg/V8tvAN84Mr).

To find your log, go to the logs folder in your x64 folder in your Hades game directory and either copy the latest log or the log that the error was in. Logs are timestamped. Or you can open the installer and press the Open Log Folder button. This will only work if the game has been run at least once.

If you just have a suggestion, you don't need to include a log. Suggestions should also be posted to the Hades support channel, not the Hades general channel.

## Donate

If you enjoy this project and would like to support its development, you can donate [here](https://ko-fi.com/michaeljohann).

## Translation

If you would like the game's speech output to be translated into a language other than English, you can use the NVDA Instant Translate addon. This approach supports more languages than Hades ever could.

You can download the addon from the [NVDA Add-ons website](https://addons.nvda-project.org/addons/instantTranslate.en.html) or find it in the NVDA Add-on Store.

To set it up:

1. Open NVDA Preferences, then Settings.
2. Go to the Instant Translate section.
3. Set your source language to English.
4. Set your target language to the language you want to translate to.
5. Hit OK.
6. Press NVDA+Shift+T, then V to enable auto translate.

## Credits

This mod was made by Michael Johann with help from Claude.

Huge thanks to the original devs hllf and JLove. Without you this could not have been done!

Huge thanks to Hamada for showing that adding Tolk support to the in-game menus of Hades was possible and providing the skeleton for the DLL.

Menu guide: Smoke from Black Screen Gaming.

NVDA Instant Translate addon: Alexy Sadovoy, Beqa Gozalishvili, Mesar Hameed, Alberto Buffolino and other NVDA contributors.

ReadMe author: Ryok, updated by Michael Johann.
