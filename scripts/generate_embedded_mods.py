#!/usr/bin/env python3
"""
Generate embedded_mods.cpp from Lua mod source files.

Reads all accessibility mod Lua files and ModUtil v2.10.0, then generates
a C++ source file with the Lua source embedded as raw string literals.
The generated file is compiled into the DLL so no external .lua files are needed.

Large files are split into chunks of ~60000 bytes to stay under MSVC's
65535 byte string literal limit (C2026). Adjacent string literals are
concatenated by the compiler into a single contiguous char array.

Usage:
    python generate_embedded_mods.py

Output:
    hades/embedded_mods.cpp
"""

import os
import re
import sys

# ============================================================
# Configuration
# ============================================================

# ModUtil v2.10.0 (local copy, 5 files, load first)
MODUTIL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "modutil")

# Accessibility mods
MODS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "lua")

# Output files
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "cpp", "embedded_mods.cpp")
VERSION_HEADER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "cpp", "version.h")

# Changelog file (source of truth for version)
CHANGELOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "changelog.txt")

# Raw string delimiter - verified no Lua file contains ")MODLUA""
DELIMITER = "MODLUA"

# MSVC raw string literal limit is 65535 bytes, but in practice MSVC
# hits C2026 much earlier with raw strings. Use 15000 to be safe.
MAX_CHUNK_BYTES = 15000

# ============================================================
# Load order (matches modimporter behavior)
# ============================================================

# ModUtil v2.10.0 files in correct order (Top Import, Priority 0)
MODUTIL_FILES = [
    ("ModUtil",         "ModUtil.lua"),
    ("ModUtil.Extra",   "ModUtil.Extra.lua"),
    ("ModUtil.Main",    "ModUtil.Main.lua"),
    ("ModUtil.Compat",  "ModUtil.Compat.lua"),
    ("ModUtil.Hades",   "ModUtil.Hades.lua"),
]

# Top imports (loaded before regular mods)
TOP_IMPORTS = [
    ("NoTrapDamage", "NoTrapDamage", "NoTrapDamage.lua"),
]

# Regular mods (alphabetical by folder name, matching modimporter)
REGULAR_MODS = [
    ("AccesibilityDoor",       "AccesibilityDoor-MenuVer",  "AccesibilityDoor-MenuVer.lua"),
    ("AccesibilityResource",   "AccesibilityResourceMenu",  "AccesibilityResourceMenu.lua"),
    ("AccesibilityStore",      "AccesibilityStoreMenu",     "AccesibilityStoreMenu.lua"),
    ("AccessibleBoonInfo",     "AccessibleBoonInfo",        "AccessibleBoonInfo.lua"),
    ("AccessibleBoons",        "AccessibleBoons",           "AccessibleBoons.lua"),
    ("AccessibleBroker",       "AccessibleBroker",          "AccessibleBroker.lua"),
    ("AccessibleCodex",        "AccessibleCodex",           "AccessibleCodex.lua"),
    ("AccessibleContractor",   "AccessibleContractor",      "AccessibleContractor.lua"),
    ("AccessibleGameStats",    "AccessibleGameStats",       "AccessibleGameStats.lua"),
    ("AccessibleKeepsakes",    "AccessibleKeepsakes",       "AccessibleKeepsakes.lua"),
    ("AccessibleMirror",       "AccessibleMirror",          "AccessibleMirror.lua"),
    ("AccessibleMusicPlayer",  "AccessibleMusicPlayer",     "AccessibleMusicPlayer.lua"),
    ("AccessibleNotifications","AccessibleNotifications",   "AccessibleNotifications.lua"),
    ("AccessiblePact",         "AccessiblePact",            "AccessiblePact.lua"),
    ("AccessiblePool",         "AccessiblePool",            "AccessiblePool.lua"),
    ("AccessibleQuestLog",     "AccessibleQuestLog",        "AccessibleQuestLog.lua"),
    ("AccessibleRunClear",     "AccessibleRunClear",        "AccessibleRunClear.lua"),
    ("AccessibleRunHistory",   "AccessibleRunHistory",      "AccessibleRunHistory.lua"),
    ("AccessibleScrying",      "AccessibleScrying",         "AccessibleScrying.lua"),
    ("AccessibleTraitTray",    "AccessibleTraitTray",       "AccessibleTraitTray.lua"),
    ("AccessibleWeaponUpgrade","AccessibleWeaponUpgrade",   "AccessibleWeaponUpgrade.lua"),
    ("AccessibleWell",         "AccessibleWell",            "AccessibleWell.lua"),
    ("DamageFeedback",         "DamageFeedback",            "DamageFeedback.lua"),
    ("DebugKeys",              "DebugKeys",                 "DebugKeys.lua"),
    ("GodGaugeSounds",         "GodGaugeSounds",            "GodGaugeSounds.lua"),
    ("RelationshipMenu",       "RelationshipMenu",          "RelationshipMenu.lua"),
    ("RewardMenu",             "RewardMenu",                "RewardMenu.lua"),
    ("ZLocalizationCore",      "ZLocalizationCore",         "ZLocalizationCore.lua"),
]


def parse_version_from_changelog(changelog_path):
    """Parse the latest version from changelog.txt.

    Looks for the first line matching '*Version X.Y:' or '*Version X:' and
    returns the version string (e.g. '34.1' or '34').
    """
    if not os.path.exists(changelog_path):
        print(f"WARNING: {changelog_path} not found, using fallback version")
        return None
    with open(changelog_path, "r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\*Version\s+([\d.]+)", line)
            if m:
                return m.group(1)
    print(f"WARNING: No version found in {changelog_path}, using fallback version")
    return None


def generate_version_header(version_str):
    """Generate version.h with the version string from changelog.txt."""
    content = (
        "// AUTO-GENERATED by generate_embedded_mods.py — DO NOT EDIT MANUALLY\n"
        "// Version parsed from changelog.txt\n"
        "#pragma once\n\n"
        f'#define MOD_VERSION "v{version_str}"\n'
    )
    with open(VERSION_HEADER, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"Generated {VERSION_HEADER} with MOD_VERSION = \"v{version_str}\"")


def sanitize_var_name(name):
    """Convert a mod name to a valid C++ variable name."""
    return "s_mod_" + name.replace(".", "_").replace("-", "_").replace(" ", "_")


def read_file(path):
    """Read a file and return its contents as a string."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def validate_content(name, content):
    """Check that content doesn't contain the raw string closing delimiter."""
    closing = f"){DELIMITER}\""
    if closing in content:
        print(f"ERROR: {name} contains closing delimiter '{closing}' - change DELIMITER!")
        sys.exit(1)


def split_into_chunks(content, max_bytes):
    """Split content into chunks at newline boundaries, each under max_bytes.

    Returns a list of strings, each under max_bytes when encoded as UTF-8.
    """
    if len(content.encode("utf-8")) <= max_bytes:
        return [content]

    chunks = []
    lines = content.split("\n")
    current_lines = []
    current_size = 0

    for line in lines:
        line_with_nl = line + "\n"
        line_bytes = len(line_with_nl.encode("utf-8"))

        if current_size + line_bytes > max_bytes and current_lines:
            # Flush current chunk
            chunks.append("\n".join(current_lines) + "\n")
            current_lines = []
            current_size = 0

        current_lines.append(line)
        current_size += line_bytes

    # Flush remaining
    if current_lines:
        chunk_text = "\n".join(current_lines)
        # Preserve original trailing newline behavior
        if content.endswith("\n") and not chunk_text.endswith("\n"):
            chunk_text += "\n"
        chunks.append(chunk_text)

    return chunks


def write_string_literal(f, var_name, content):
    """Write a (possibly chunked) raw string literal for a mod."""
    chunks = split_into_chunks(content, MAX_CHUNK_BYTES)

    if len(chunks) == 1:
        # Single chunk - simple case
        f.write(f"static const char {var_name}[] = R\"{DELIMITER}(\n")
        f.write(chunks[0])
        if not chunks[0].endswith("\n"):
            f.write("\n")
        f.write(f"){DELIMITER}\";\n\n")
    else:
        # Multiple chunks - adjacent string literals concatenated by compiler
        f.write(f"static const char {var_name}[] =\n")
        for i, chunk in enumerate(chunks):
            f.write(f"    R\"{DELIMITER}(")
            f.write(chunk)
            if not chunk.endswith("\n"):
                f.write("\n")
            if i < len(chunks) - 1:
                f.write(f"){DELIMITER}\"\n")
            else:
                f.write(f"){DELIMITER}\";\n\n")


def main():
    # 0. Parse version from changelog.txt and generate version.h
    version = parse_version_from_changelog(CHANGELOG_FILE)
    if version:
        generate_version_header(version)
    else:
        print("WARNING: Could not parse version — version.h not updated")

    entries = []  # list of (display_name, var_name, source_content)

    # 1. ModUtil v2.10.0 (from game folder)
    print(f"Reading ModUtil v2.10.0 from: {MODUTIL_DIR}")
    for display_name, filename in MODUTIL_FILES:
        path = os.path.join(MODUTIL_DIR, filename)
        if not os.path.exists(path):
            print(f"  ERROR: {path} not found!")
            sys.exit(1)
        content = read_file(path)
        validate_content(display_name, content)
        var_name = sanitize_var_name(display_name)
        entries.append((display_name, var_name, content))
        chunks = split_into_chunks(content, MAX_CHUNK_BYTES)
        chunk_info = f" ({len(chunks)} chunks)" if len(chunks) > 1 else ""
        print(f"  {display_name}: {len(content):,} bytes{chunk_info}")

    # 2. Top imports (NoTrapDamage)
    print(f"\nReading top imports from: {MODS_DIR}")
    for display_name, folder, filename in TOP_IMPORTS:
        path = os.path.join(MODS_DIR, folder, filename)
        if not os.path.exists(path):
            print(f"  ERROR: {path} not found!")
            sys.exit(1)
        content = read_file(path)
        validate_content(display_name, content)
        var_name = sanitize_var_name(display_name)
        entries.append((display_name, var_name, content))
        print(f"  {display_name}: {len(content):,} bytes")

    # 3. Regular mods (alphabetical)
    print(f"\nReading accessibility mods from: {MODS_DIR}")
    for display_name, folder, filename in REGULAR_MODS:
        path = os.path.join(MODS_DIR, folder, filename)
        if not os.path.exists(path):
            print(f"  ERROR: {path} not found!")
            sys.exit(1)
        content = read_file(path)
        validate_content(display_name, content)
        var_name = sanitize_var_name(display_name)
        entries.append((display_name, var_name, content))
        chunks = split_into_chunks(content, MAX_CHUNK_BYTES)
        chunk_info = f" ({len(chunks)} chunks)" if len(chunks) > 1 else ""
        print(f"  {display_name}: {len(content):,} bytes{chunk_info}")

    total_bytes = sum(len(e[2]) for e in entries)
    print(f"\nTotal: {len(entries)} mods, {total_bytes:,} bytes ({total_bytes/1024:.1f} KB)")

    # Generate C++ source
    print(f"\nGenerating: {OUTPUT_FILE}")

    with open(OUTPUT_FILE, "w", encoding="utf-8", newline="\n") as f:
        f.write("// AUTO-GENERATED by generate_embedded_mods.py — DO NOT EDIT MANUALLY\n")
        f.write(f"// {len(entries)} embedded Lua mods, {total_bytes:,} bytes total\n")
        f.write("//\n")
        f.write("// To regenerate: python generate_embedded_mods.py\n\n")
        f.write('#include "embedded_mods.h"\n')
        f.write('#include "logger.h"\n')
        f.write('#include <cstring>\n\n')

        # Write each mod as a raw string literal (possibly chunked)
        for display_name, var_name, content in entries:
            f.write(f"// --- {display_name} ({len(content):,} bytes) ---\n")
            write_string_literal(f, var_name, content)

        # Write the load order table
        f.write("// ============================================================\n")
        f.write("// Load order table\n")
        f.write("// ============================================================\n\n")
        f.write("struct ModEntry {\n")
        f.write("    const char* name;\n")
        f.write("    const char* source;\n")
        f.write("    size_t sourceSize;\n")
        f.write("};\n\n")
        f.write("static const ModEntry s_mods[] = {\n")
        for display_name, var_name, content in entries:
            f.write(f"    {{ \"{display_name}\", {var_name}, {len(content)} }},\n")
        f.write("};\n\n")
        f.write(f"static const int s_modCount = {len(entries)};\n\n")

        # Write the loader functions
        f.write("// ============================================================\n")
        f.write("// Loader\n")
        f.write("// ============================================================\n\n")
        f.write("static bool LoadOneMod(lua_State* L, const char* name, const char* source)\n")
        f.write("{\n")
        f.write("    int savedTop = lua.gettop(L);\n")
        f.write("    __try {\n")
        f.write("        size_t len = strlen(source);\n")
        f.write("        int loadResult = lua.loadbufferx(L, source, len, name, nullptr);\n")
        f.write("        if (loadResult != 0) {\n")
        f.write("            const char* err = lua.tolstring(L, -1, nullptr);\n")
        f.write('            Log::Error("Mod \'%s\': load error: %s", name, err ? err : "?");\n')
        f.write("            lua_pop(L, 1);\n")
        f.write("            return false;\n")
        f.write("        }\n")
        f.write("        int callResult = lua_pcall(L, 0, 0, 0);\n")
        f.write("        if (callResult != 0) {\n")
        f.write("            const char* err = lua.tolstring(L, -1, nullptr);\n")
        f.write('            Log::Error("Mod \'%s\': runtime error: %s", name, err ? err : "?");\n')
        f.write("            lua_pop(L, 1);\n")
        f.write("            return false;\n")
        f.write("        }\n")
        f.write("        return true;\n")
        f.write("    } __except(EXCEPTION_EXECUTE_HANDLER) {\n")
        f.write('        Log::Error("Mod \'%s\': CRASH 0x%08X", name, GetExceptionCode());\n')
        f.write("        lua.settop(L, savedTop);\n")
        f.write("        return false;\n")
        f.write("    }\n")
        f.write("}\n\n")

        f.write("namespace EmbeddedMods {\n\n")
        f.write("int GetModCount()\n")
        f.write("{\n")
        f.write("    return s_modCount;\n")
        f.write("}\n\n")
        f.write("int LoadAll(lua_State* L)\n")
        f.write("{\n")
        f.write('    Log::Info("Loading %d embedded mods...", s_modCount);\n')
        f.write("    int loaded = 0;\n")
        f.write("    for (int i = 0; i < s_modCount; i++) {\n")
        f.write("        if (LoadOneMod(L, s_mods[i].name, s_mods[i].source)) {\n")
        f.write("            loaded++;\n")
        f.write('            Log::Info("  [%d/%d] %s OK (%zu bytes)", i+1, s_modCount, s_mods[i].name, s_mods[i].sourceSize);\n')
        f.write("        } else {\n")
        f.write('            Log::Error("  [%d/%d] %s FAILED - continuing", i+1, s_modCount, s_mods[i].name);\n')
        f.write("        }\n")
        f.write("    }\n")
        f.write('    Log::Info("Embedded mods loaded: %d/%d", loaded, s_modCount);\n')
        f.write("    return loaded;\n")
        f.write("}\n\n")
        f.write("} // namespace EmbeddedMods\n")

    print(f"Generated {OUTPUT_FILE} successfully!")
    print(f"File size: {os.path.getsize(OUTPUT_FILE):,} bytes")


if __name__ == "__main__":
    main()
