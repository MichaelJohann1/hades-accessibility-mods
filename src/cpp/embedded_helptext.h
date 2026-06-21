#pragma once
// Resolve a Hades HelpText id (e.g. "MiscSettingsScreen_EasyModeLabel") to its
// on-screen display text (e.g. "God Mode"). Returns nullptr if not found.
// Backed by embedded_helptext.cpp, generated from the game's HelpText.en.sjson
// by generate_helptext.py.
namespace HelpText {
const char* Lookup(const char* id);
}
