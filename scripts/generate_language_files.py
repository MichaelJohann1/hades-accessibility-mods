#!/usr/bin/env python3
"""
Generate per-language Lua files for Hades accessibility mod localization.

For each supported language, reads:
  - HelpText.{lang}.sjson — translated game text with template variables
  - TraitData.lua — numeric tooltip values (language-independent)
  - ui_translations/{lang}.json — manual translations for UI strings, NPC names, etc.
  - English mod files — to extract table keys

Generates:
  - languages/{lang}.lua — overlay files that call _ApplyLanguageData()

Usage:
    python generate_language_files.py [--game-dir PATH] [--lang CODE]

Output:
    languages/{lang}.lua for each language
"""

import os
import re
import sys
import json
import argparse
import io

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GAME_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Hades"
MODS_DIR = os.path.join(SCRIPT_DIR, "..", "src", "lua")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "languages")
UI_TRANSLATIONS_DIR = os.path.join(SCRIPT_DIR, "ui_translations")

SUPPORTED_LANGUAGES = ["de", "es", "fr", "it", "ja", "ko", "pl", "pt-BR", "ru", "zh-CN"]

# ============================================================
# Table configuration
# ============================================================

# Tables where keys ARE HelpText IDs — auto-extractable from game text.
# Format: table_name -> (mod_file_relative_to_MODS_DIR, helptext_field)
# helptext_field: "DisplayName" or "Description"
HELPTEXT_TABLES = {
    # DisplayName tables (key -> name)
    "BoonDisplayNames":          ("AccessibleBoons/AccessibleBoons.lua", "DisplayName"),
    "WellItemNames":             ("AccessibleWell/AccessibleWell.lua", "DisplayName"),
    "ContractorItemNames":       ("AccessibleContractor/AccessibleContractor.lua", "DisplayName"),
    "MetaUpgradeDisplayNames":   ("AccessibleMirror/AccessibleMirror.lua", "DisplayName"),
    # Description tables (key -> description)
    "GodBoonDescriptions":       ("AccessibleBoons/AccessibleBoons.lua", "Description"),
    "HammerDescriptions":        ("AccessibleBoons/AccessibleBoons.lua", "Description"),
    "ChaosBlessingDescriptions": ("AccessibleBoons/AccessibleBoons.lua", "Description"),
    "ChaosCurseDescriptions":    ("AccessibleBoons/AccessibleBoons.lua", "Description"),
    "WellItemDescriptions":      ("AccessibleWell/AccessibleWell.lua", "Description"),
    "ContractorItemDescriptions":("AccessibleContractor/AccessibleContractor.lua", "Description"),
    "KeepsakeDescriptions":      ("AccessibleKeepsakes/AccessibleKeepsakes.lua", "Description"),
    "QuestDescriptions":         ("AccessibleQuestLog/AccessibleQuestLog.lua", "Description"),
}

# Tables to try HelpText lookup first, fall back to manual translations.
# Keys may or may not be HelpText IDs.
HYBRID_TABLES = {
    "GodDisplayNames":      ("AccessibleBoons/AccessibleBoons.lua", "DisplayName"),
    "SlotDescriptions":     ("AccessibleBoons/AccessibleBoons.lua", "DisplayName"),
    "LocationDisplayNames": ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "NPCDisplayNames":      ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "WeaponDisplayNames":   ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "KeepsakeDisplayNames": ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "KeepsakeGiftNames":    ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "FishDisplayNames":     ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "ResourceDisplayNames": ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "ChoiceDisplayNames":   ("AccessibleNotifications/AccessibleNotifications.lua", "DisplayName"),
    "AspectDisplayNames":   ("AccessibleTraitTray/AccessibleTraitTray.lua", "DisplayName"),
    "TrackDisplayNames":    ("AccessibleMusicPlayer/AccessibleMusicPlayer.lua", "DisplayName"),
}

# Manual-only tables — no HelpText lookup possible.
# Format: table_name -> (mod_file_relative_to_MODS_DIR,)
MANUAL_ONLY_TABLES = {
    "UIStrings":       ("ZLocalizationCore/ZLocalizationCore.lua",),
    "GodFlavorText":   ("AccessibleBoons/AccessibleBoons.lua",),
    "DuoBoonGods":     ("AccessibleBoons/AccessibleBoons.lua",),
    "MirrorFlavorText":("AccessibleMirror/AccessibleMirror.lua",),
    "PactFlavorText":  ("AccessibleMirror/AccessibleMirror.lua",),
    "ObjectiveDescriptions": ("AccessibleNotifications/AccessibleNotifications.lua",),
}


# ============================================================
# SJSON Parser (adapted from parse_game_text.py)
# ============================================================
def parse_sjson(filepath):
    """Parse SJSON file into dict: {Id: {DisplayName?, Description?, InheritFrom?}}"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    entries = {}
    current_id = None
    current = {}
    in_comment = False

    for line in lines:
        s = line.strip()

        if in_comment:
            if '*/' in s:
                in_comment = False
            continue
        if '/*' in s and '*/' in s:
            continue
        if '/*' in s:
            in_comment = True
            continue
        if s.startswith('//'):
            continue

        m = re.match(r'Id\s*=\s*"([^"]*)"', s)
        if m:
            if current_id is not None:
                entries[current_id] = current
            current_id = m.group(1)
            current = {}
            continue

        m = re.match(r'DisplayName\s*=\s*"(.*)"$', s)
        if m:
            current['DisplayName'] = m.group(1)
            continue

        m = re.match(r'Description\s*=\s*"(.*)"$', s)
        if m:
            current['Description'] = m.group(1)
            continue

        m = re.match(r'InheritFrom\s*=\s*"([^"]*)"', s)
        if m:
            current['InheritFrom'] = m.group(1)
            continue

    if current_id is not None:
        entries[current_id] = current

    return entries


def resolve_inheritance(entries):
    """Resolve InheritFrom chains so every entry has own DisplayName/Description."""
    for entry_id, entry in entries.items():
        if 'InheritFrom' in entry:
            parent_id = entry['InheritFrom']
            if parent_id in entries:
                parent = entries[parent_id]
                if 'DisplayName' not in entry and 'DisplayName' in parent:
                    entry['DisplayName'] = parent['DisplayName']
                if 'Description' not in entry and 'Description' in parent:
                    entry['Description'] = parent['Description']


def build_keywords(entries):
    """Build keyword name -> resolved display text from HelpText entries."""
    keywords = {}
    for entry_id, entry in entries.items():
        if 'DisplayName' in entry:
            dn = strip_formatting(entry['DisplayName'])
            keywords[entry_id] = dn
    return keywords


# ============================================================
# TraitData Parser (adapted from parse_game_text.py)
# ============================================================
def parse_trait_data(filepath):
    """Extract tooltip data from TraitData.lua using regex.

    Returns dict: {trait_name: {extract_as_name: formatted_value_string}}
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    tooltip_data = {}

    trait_starts = []
    for m in re.finditer(r'\n\t(\w+)\s*=\s*\n?\t*\{', content):
        trait_starts.append((m.group(1), m.start(), m.end()))

    for i, (trait_name, start, block_start) in enumerate(trait_starts):
        if i + 1 < len(trait_starts):
            block_end = trait_starts[i + 1][1]
        else:
            block_end = len(content)

        block = content[block_start:block_end]
        values = {}

        for ev_match in re.finditer(r'ExtractAs\s*=\s*"(\w+)"', block):
            extract_as = ev_match.group(1)
            search_region = block[max(0, ev_match.start() - 300):ev_match.end() + 200]
            fmt_match = re.search(r'Format\s*=\s*"(\w+)"', search_region)
            fmt = fmt_match.group(1) if fmt_match else None

            key_match = re.search(r'Key\s*=\s*"(\w+)"', search_region)
            if key_match:
                key_name = key_match.group(1)
                val_patterns = [
                    rf'{key_name}\s*=\s*(-?[0-9]+\.?[0-9]*)\s*[,\n}}]',
                    rf'{key_name}\s*=\s*\{{\s*BaseValue\s*=\s*(-?[0-9]+\.?[0-9]*)',
                ]
                raw_value = None
                for vp in val_patterns:
                    vm = re.search(vp, block)
                    if vm:
                        raw_value = float(vm.group(1))
                        break

                if raw_value is not None:
                    formatted = format_tooltip_value(raw_value, fmt)
                    values[extract_as] = formatted

            base_region = block[max(0, ev_match.start() - 500):ev_match.start()]
            base_match = re.search(r'BaseMin\s*=\s*(-?[0-9]+\.?[0-9]*)', base_region)
            if not base_match:
                base_match = re.search(r'BaseMax\s*=\s*(-?[0-9]+\.?[0-9]*)', base_region)
            if base_match and extract_as not in values:
                raw_value = float(base_match.group(1))
                formatted = format_tooltip_value(raw_value, fmt)
                values[extract_as] = formatted

        ru_match = re.search(r'RemainingUses\s*=\s*(\d+)', block)
        if ru_match:
            values['RemainingUses'] = ru_match.group(1)

        if values:
            tooltip_data[trait_name] = values

    return tooltip_data


def build_extract_index(filepath):
    """Build DisplayDelta/NewTotal/OldTotal index mapping for each trait.

    The game's SetTraitTextData (TraitScripts.lua:2094) creates runtime
    indirection variables like DisplayDelta1, NewTotal1 that map to the
    ExtractAs values of non-skipped ExtractValue entries, numbered sequentially.

    Returns dict: {trait_name: [extract_as_name_1, extract_as_name_2, ...]}
    where list index 0 = index 1 in the game (DisplayDelta1, NewTotal1, etc.)
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    extract_index = {}

    # Find trait block boundaries (same as parse_trait_data)
    trait_starts = []
    for m in re.finditer(r'\n\t(\w+)\s*=\s*\n?\t*\{', content):
        trait_starts.append((m.group(1), m.start(), m.end()))

    for i, (trait_name, start, block_start) in enumerate(trait_starts):
        if i + 1 < len(trait_starts):
            block_end = trait_starts[i + 1][1]
        else:
            block_end = len(content)

        block = content[block_start:block_end]

        # Find all ExtractAs entries with their positions, Format, and SkipAutoExtract
        entries = []
        for ev_match in re.finditer(r'ExtractAs\s*=\s*"(\w+)"', block):
            extract_as = ev_match.group(1)
            pos = ev_match.start()

            # Check nearby context for SkipAutoExtract and Format
            # Look within the same {} block (up to 300 chars before, 200 after)
            context = block[max(0, pos - 300):pos + 200]
            skip = bool(re.search(r'SkipAutoExtract\s*=\s*true', context))
            fmt_m = re.search(r'Format\s*=\s*"(\w+)"', context)
            fmt = fmt_m.group(1) if fmt_m else None

            entries.append((pos, extract_as, skip, fmt))

        # Sort by position (matches source order, which approximates game traversal)
        entries.sort(key=lambda e: e[0])

        # Filter out SkipAutoExtract, build ordered list
        ordered = [name for (_, name, skip, _) in entries if not skip]

        if ordered:
            extract_index[trait_name] = ordered

    return extract_index


def format_tooltip_value(value, fmt):
    """Format a numeric value according to TraitData Format type."""
    if fmt == "PercentDelta":
        pct = round((value - 1) * 100)
        return f"+{pct}%" if pct > 0 else f"{pct}%"
    elif fmt == "NegativePercentDelta":
        pct = round((1 - value) * 100)
        return f"{pct}%"
    elif fmt == "Percent":
        pct = round(value * 100)
        return f"{pct}%"
    elif fmt == "PercentOfBase":
        return str(round(value))
    else:
        if value == int(value):
            return str(int(value))
        return f"{value:g}"


# ============================================================
# Template Resolution
# ============================================================
def strip_formatting(text):
    """Strip all formatting/style tags from text."""
    if not text:
        return ""
    # Remove [BracketText] that precedes {$Keywords.X} (non-English inline translations)
    text = re.sub(r'\[[^\]]*\]\s*(?=\{\$Keywords\.)', '', text)
    text = re.sub(r'\{#\w+\}', '', text)
    text = re.sub(r'\{!\w+(\.\w+)*\}', '', text)
    text = re.sub(r'\\n', ' ', text)
    text = re.sub(r'\\Column\s+\d+', ' ', text)
    text = re.sub(r'\{[A-Z][A-Z0-9]*\}', '', text)
    text = re.sub(r'\\\[', '[', text)
    text = re.sub(r'\\\]', ']', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def resolve_template(text, trait_id=None, keywords=None, tooltip_data=None,
                     extract_index=None):
    """Resolve template variables in a description string."""
    if not text:
        return ""

    result = text

    # Remove [BracketText] before {$Keywords.X} (non-English inline translations)
    result = re.sub(r'\[[^\]]*\]\s*(?=\{\$Keywords\.)', '', result)

    # Keywords: {$Keywords.X} -> keyword display name
    def replace_keyword(m):
        kw_name = m.group(1)
        if keywords and kw_name in keywords:
            return keywords[kw_name]
        return kw_name

    result = re.sub(r'\{\$Keywords\.(\w+)\}', replace_keyword, result)

    # TempTextData — remove
    result = re.sub(r'\{\$TempTextData\.\w+(:\w+)?\}', '', result)

    # TooltipData: {$TooltipData.X} or {$TooltipData.X:P}
    def replace_tooltip(m):
        var_name = m.group(1)
        if tooltip_data and trait_id and trait_id in tooltip_data:
            trait_vals = tooltip_data[trait_id]
            # Direct lookup first (ExtractAs name matches variable name)
            val = trait_vals.get(var_name)
            if val:
                return val

            # Indirection lookup: DisplayDelta{N}, NewTotal{N}, OldTotal{N},
            # PercentTotal{N}, Total{N}, Increase{N}, etc. all map to
            # the Nth ExtractAs value via build_extract_index()
            if extract_index and trait_id in extract_index:
                ordered = extract_index[trait_id]
                idx_match = re.match(
                    r'(?:DisplayDelta|NewTotal|OldTotal|PercentTotal|'
                    r'PercentNewTotal|PercentOldTotal|Total|Increase|'
                    r'PercentIncrease|Additional)(\d+)$', var_name)
                if idx_match:
                    idx = int(idx_match.group(1)) - 1  # 1-based -> 0-based
                    if 0 <= idx < len(ordered):
                        extract_as = ordered[idx]
                        val = trait_vals.get(extract_as)
                        if val:
                            return val

        return f"[?{var_name}]"

    result = re.sub(r'\{\$TooltipData\.(\w+)(:\w+)?\}', replace_tooltip, result)

    # Format/style tags
    result = re.sub(r'\{#\w+\}', '', result)

    # Icons — common ones with text equivalents
    result = re.sub(r'\{!Icons\.Currency_Small\}', ' Obols', result)
    result = re.sub(r'\{!Icons\.Ammo\}', ' Bloodstones', result)
    result = re.sub(r'\{!Icons\.RightArrow\}', ' to ', result)
    result = re.sub(r'\{!Icons\.Bullet\}', '', result)
    result = re.sub(r'\{!Icons\.Health\w*\}', ' Health', result)
    result = re.sub(r'\{!Icons\.HealthRestore\w*\}', ' Healing', result)
    result = re.sub(r'\{!Icons\.HealthUp\w*\}', ' Max Health', result)
    result = re.sub(r'\{!Icons\.HealthDown\w*\}', ' Health', result)
    result = re.sub(r'\{!\w+(\.\w+)*\}', '', result)  # catch-all

    # Controller bindings
    result = re.sub(r'\{[A-Z][A-Z0-9]*\}', '', result)

    # Column alignment
    result = re.sub(r'\\Column\s+\d+', ' ', result)

    # Newlines
    result = result.replace('\\n', '. ')

    # Escaped brackets
    result = result.replace('\\[', '[').replace('\\]', ']')

    # Percent literal
    result = result.replace('%%', '%')

    # Fix double signs
    result = re.sub(r'--(\d)', r'-\1', result)
    result = re.sub(r'\+\+(\d)', r'+\1', result)
    result = re.sub(r'\+-(\d)', r'-\1', result)
    result = re.sub(r'-\+(\d)', r'+\1', result)

    # Clean whitespace/punctuation
    result = re.sub(r'\s+', ' ', result)
    result = re.sub(r'\.\s*\.', '.', result)
    result = re.sub(r'\s+\.', '.', result)
    result = re.sub(r'\.\s*,', ',', result)
    result = re.sub(r',\s*\.', '.', result)
    result = re.sub(r':\s+:', ':', result)
    result = result.strip()
    if result.endswith('.'):
        result = result[:-1].strip()

    return result


# ============================================================
# Mod File Key Extraction (from parse_game_text.py)
# ============================================================
def extract_table_keys(filepath, table_name):
    """Extract keys from a Lua table definition in a mod file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = rf'(?:local\s+)?{re.escape(table_name)}\s*=\s*\{{'
    m = re.search(pattern, content)
    if not m:
        return []

    start = m.end()
    depth = 1
    pos = start
    while pos < len(content) and depth > 0:
        if content[pos] == '{':
            depth += 1
        elif content[pos] == '}':
            depth -= 1
        pos += 1

    table_body = content[start:pos - 1]

    keys = []
    skip_keys = {'text', 'values', 'base', 'perLevel', 'static',
                 'usesLevel', 'formatFunc', 'baseValue', 'local',
                 'function', 'if', 'then', 'end', 'return', 'for'}
    for line in table_body.split('\n'):
        stripped = line.strip()
        # Match bare keys: Key = "value"
        km = re.match(r'(\w+)\s*=', stripped)
        if km:
            key = km.group(1)
            if key not in skip_keys:
                keys.append(key)
            continue
        # Match bracket-quoted keys: ["Key-Name"] = "value"
        km = re.match(r'\["([^"]+)"\]\s*=', stripped)
        if km:
            keys.append(km.group(1))

    return keys


# ============================================================
# Language File Generation
# ============================================================
def escape_lua_string(s):
    """Escape a string for Lua double-quoted string literal."""
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    s = s.replace('\r', '')
    return s


def lua_key(k):
    """Format a Lua table key — bare identifier or ["bracket-quoted"]."""
    if re.match(r'^[A-Za-z_]\w*$', k):
        return k
    return f'["{k}"]'


def _strip_unresolved(text):
    """Strip [?VarName] placeholders from partially-resolved description text.

    Many boon descriptions have numeric values as separate appended fragments
    (e.g. "Your Attack emits chain-lightning. [?DisplayDelta1]"). Stripping the
    unresolved placeholder keeps the meaningful translated description text.
    """
    # Remove [?VarName] placeholders
    result = re.sub(r'\[\?\w+\]', '', text)
    # Clean up resulting punctuation/whitespace artifacts
    result = re.sub(r'\s+', ' ', result)
    result = re.sub(r'\.\s*\.', '.', result)
    result = re.sub(r'\s+\.', '.', result)
    result = re.sub(r',\s*,', ',', result)
    result = re.sub(r'\.\s*,', ',', result)
    result = re.sub(r',\s*\.', '.', result)
    result = re.sub(r':\s+:', ':', result)
    result = re.sub(r'\s*\.\s*$', '', result)
    result = result.strip()
    return result


def generate_table_entries(keys, helptext, field, keywords, tooltip_data,
                           manual_fallback, en_helptext=None, extract_index=None):
    """Generate translated entries for a single table.

    For each key:
    1. Try target language HelpText lookup (if field is not None)
    2. Try English HelpText as secondary source — resolve templates with target keywords
    3. Fall back to manual_fallback dict
    4. Skip if none found (English fallback at runtime)

    Returns ordered dict of {key: resolved_string}.
    """
    entries = {}

    for key in keys:
        # Try target language HelpText lookup
        if field:
            entry = helptext.get(key, {})
            raw = entry.get(field, '')
            if raw:
                if field == "Description":
                    resolved = resolve_template(raw, key, keywords, tooltip_data,
                                                extract_index)
                else:
                    resolved = resolve_template(raw, key, keywords, None)

                if '[?' not in resolved and resolved:
                    entries[key] = resolved
                    continue

                # Fallback: strip unresolved [?VarName] placeholders and accept
                # if meaningful text remains. Numbers are language-independent,
                # so translated text without some values is still useful.
                if '[?' in resolved and field == "Description":
                    stripped = _strip_unresolved(resolved)
                    if stripped and len(stripped) >= 10:
                        entries[key] = stripped
                        continue

            # Try English HelpText as secondary source — the entry may only
            # exist in the English file (e.g. MetaUpgrade entries use keyword
            # references that resolve in any language's keyword dict).
            if en_helptext and key not in helptext:
                en_entry = en_helptext.get(key, {})
                en_raw = en_entry.get(field, '')
                if en_raw:
                    if field == "Description":
                        resolved = resolve_template(en_raw, key, keywords, tooltip_data,
                                                    extract_index)
                    else:
                        resolved = resolve_template(en_raw, key, keywords, None)

                    if '[?' not in resolved and resolved:
                        entries[key] = resolved
                        continue

                    if '[?' in resolved and field == "Description":
                        stripped = _strip_unresolved(resolved)
                        if stripped and len(stripped) >= 10:
                            entries[key] = stripped
                            continue

        # Try manual fallback
        if key in manual_fallback:
            entries[key] = manual_fallback[key]

    return entries


def generate_language_file(lang_code, helptext, keywords, tooltip_data,
                           table_keys, manual_translations, en_helptext=None,
                           extract_index=None):
    """Generate a complete language .lua file.

    Returns (content_string, total_entry_count, table_stats).
    """
    lines = []
    lines.append(f"-- Auto-generated language file: {lang_code}")
    lines.append("-- Generated by generate_language_files.py")
    lines.append("-- Missing entries fall back to English at runtime.")
    lines.append("local L = {}\n")

    total_entries = 0
    table_stats = []

    # 1. HelpText-backed tables
    for table_name, (mod_file, field) in HELPTEXT_TABLES.items():
        keys = table_keys.get(table_name, [])
        if not keys:
            continue
        manual = manual_translations.get(table_name, {})
        entries = generate_table_entries(keys, helptext, field, keywords, tooltip_data,
                                         manual, en_helptext, extract_index)
        if entries:
            lines.append(f"L.{table_name} = {{")
            for k, v in entries.items():
                escaped = escape_lua_string(v)
                lines.append(f'    {lua_key(k)} = "{escaped}",')
            lines.append("}\n")
            total_entries += len(entries)
            table_stats.append((table_name, len(entries), len(keys)))

    # 2. Hybrid tables (HelpText first, manual fallback)
    for table_name, (mod_file, field) in HYBRID_TABLES.items():
        keys = table_keys.get(table_name, [])
        if not keys:
            continue
        manual = manual_translations.get(table_name, {})
        entries = generate_table_entries(keys, helptext, field, keywords, tooltip_data,
                                         manual, en_helptext, extract_index)
        if entries:
            lines.append(f"L.{table_name} = {{")
            for k, v in entries.items():
                escaped = escape_lua_string(v)
                lines.append(f'    {lua_key(k)} = "{escaped}",')
            lines.append("}\n")
            total_entries += len(entries)
            table_stats.append((table_name, len(entries), len(keys)))

    # 3. Manual-only tables
    for table_name in MANUAL_ONLY_TABLES:
        manual = manual_translations.get(table_name, {})
        if manual:
            lines.append(f"L.{table_name} = {{")
            for k, v in manual.items():
                escaped = escape_lua_string(v)
                lines.append(f'    {lua_key(k)} = "{escaped}",')
            lines.append("}\n")
            total_entries += len(manual)
            table_stats.append((table_name, len(manual), len(manual)))

    lines.append("_ApplyLanguageData(L)")
    lines.append("")

    return '\n'.join(lines), total_entries, table_stats


# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(
        description='Generate per-language Lua files for Hades accessibility mod localization.')
    parser.add_argument('--game-dir', default=DEFAULT_GAME_DIR,
                        help='Path to Hades game directory')
    parser.add_argument('--lang', help='Generate for single language code (e.g. "fr")')
    parser.add_argument('--output', default=OUTPUT_DIR,
                        help='Output directory for language files')
    parser.add_argument('--list-keys', action='store_true',
                        help='List all table keys and exit (diagnostic mode)')
    args = parser.parse_args()

    game_dir = args.game_dir
    output_dir = args.output
    langs = [args.lang] if args.lang else SUPPORTED_LANGUAGES

    print("=" * 70)
    print("Hades Accessibility Mod — Language File Generator")
    print("=" * 70)
    print()

    # --- Validate game directory ---
    text_dir = os.path.join(game_dir, "Content", "Game", "Text")
    if not os.path.exists(text_dir):
        print(f"ERROR: Game text directory not found: {text_dir}")
        print(f"  Use --game-dir to specify the Hades installation path.")
        sys.exit(1)

    # --- Parse TraitData (language-independent) ---
    traitdata_path = os.path.join(game_dir, "Content", "Scripts", "TraitData.lua")
    tooltip_data = {}
    extract_index = {}
    if os.path.exists(traitdata_path):
        print(f"Parsing TraitData: {traitdata_path}")
        tooltip_data = parse_trait_data(traitdata_path)
        extract_index = build_extract_index(traitdata_path)
        print(f"  Extracted tooltip data for {len(tooltip_data)} traits")
        print(f"  Built extract index for {len(extract_index)} traits")
    else:
        print(f"WARNING: TraitData.lua not found — tooltip values will be unresolved")
    print()

    # --- Extract table keys from English mod files ---
    print(f"Extracting table keys from mod files: {MODS_DIR}")
    table_keys = {}
    all_tables = {}
    all_tables.update(HELPTEXT_TABLES)
    all_tables.update(HYBRID_TABLES)
    for table_name, (mod_file, _) in all_tables.items():
        filepath = os.path.join(MODS_DIR, mod_file)
        if os.path.exists(filepath):
            keys = extract_table_keys(filepath, table_name)
            if keys:
                table_keys[table_name] = keys
                print(f"  {table_name}: {len(keys)} keys")
            else:
                print(f"  {table_name}: NOT FOUND in {mod_file}")
        else:
            print(f"  {table_name}: FILE NOT FOUND {mod_file}")

    for table_name, (mod_file,) in MANUAL_ONLY_TABLES.items():
        filepath = os.path.join(MODS_DIR, mod_file)
        if os.path.exists(filepath):
            keys = extract_table_keys(filepath, table_name)
            if keys:
                table_keys[table_name] = keys
                print(f"  {table_name}: {len(keys)} keys (manual-only)")

    total_keys = sum(len(v) for v in table_keys.values())
    print(f"\n  Total: {len(table_keys)} tables, {total_keys} keys")
    print()

    if args.list_keys:
        print("=" * 70)
        print("All table keys (diagnostic)")
        print("=" * 70)
        for table_name, keys in sorted(table_keys.items()):
            print(f"\n--- {table_name} ({len(keys)} keys) ---")
            for k in keys:
                print(f"  {k}")
        return

    # --- Create output directory ---
    os.makedirs(output_dir, exist_ok=True)

    # --- Parse English HelpText as secondary source ---
    en_helptext_path = os.path.join(game_dir, "Content", "Game", "Text", "en",
                                     "HelpText.en.sjson")
    en_helptext = None
    if os.path.exists(en_helptext_path):
        print(f"Parsing English HelpText as secondary source...")
        en_helptext = parse_sjson(en_helptext_path)
        resolve_inheritance(en_helptext)
        print(f"  {len(en_helptext)} entries")
    else:
        print(f"WARNING: English HelpText not found — cross-language fallback disabled")
    print()

    # --- Generate for each language ---
    print("=" * 70)
    print("Generating language files")
    print("=" * 70)

    for lang in langs:
        print(f"\n--- {lang} ---")

        # Parse HelpText for this language
        helptext_path = os.path.join(game_dir, "Content", "Game", "Text", lang,
                                     f"HelpText.{lang}.sjson")
        if not os.path.exists(helptext_path):
            print(f"  SKIP: HelpText not found at {helptext_path}")
            continue

        print(f"  Parsing HelpText.{lang}.sjson...", end=" ")
        helptext = parse_sjson(helptext_path)
        resolve_inheritance(helptext)
        keywords = build_keywords(helptext)
        print(f"{len(helptext)} entries, {len(keywords)} keywords")

        # Load manual translations
        manual_path = os.path.join(UI_TRANSLATIONS_DIR, f"{lang}.json")
        manual = {}
        if os.path.exists(manual_path):
            with open(manual_path, 'r', encoding='utf-8') as f:
                manual = json.load(f)
            manual_count = sum(len(v) for v in manual.values() if isinstance(v, dict))
            print(f"  Loaded {manual_count} manual translations from {lang}.json")
        else:
            print(f"  No manual translations (ui_translations/{lang}.json not found)")

        # Generate language file
        content, count, stats = generate_language_file(
            lang, helptext, keywords, tooltip_data, table_keys, manual, en_helptext,
            extract_index)

        # Write output
        output_path = os.path.join(output_dir, f"{lang}.lua")
        with open(output_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(content)

        file_size = os.path.getsize(output_path)
        print(f"  Generated: {output_path} ({count} entries, {file_size:,} bytes)")

        # Per-table stats
        for table_name, translated, total in stats:
            pct = (translated / total * 100) if total > 0 else 0
            print(f"    {table_name}: {translated}/{total} ({pct:.0f}%)")

    print()
    print("=" * 70)
    print("Done!")
    print("=" * 70)
    print()
    print("Next steps:")
    print("  1. Create ui_translations/{lang}.json files for manual translations")
    print("  2. Re-run this script to include manual translations")
    print("  3. Deploy languages/ folder to game's x64/ directory")


if __name__ == "__main__":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    main()
