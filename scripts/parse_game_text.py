#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

import re
import os
import sys
import math

GAME_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Hades"
HELPTEXT_PATH = os.path.join(GAME_DIR, "Content", "Game", "Text", "en", "HelpText.en.sjson")
TRAITDATA_PATH = os.path.join(GAME_DIR, "Content", "Scripts", "TraitData.lua")

MODS_DIR = os.path.join(os.path.dirname(__file__), "Content", "Mods")

def parse_sjson(filepath):
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

        m = re.match(r'Speaker\s*=\s*"([^"]*)"', s)
        if m:
            current['Speaker'] = m.group(1)
            continue

    if current_id is not None:
        entries[current_id] = current

    return entries

def resolve_inheritance(entries):
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
    keywords = {}
    for entry_id, entry in entries.items():
        if 'DisplayName' in entry:
            dn = strip_formatting(entry['DisplayName'])
            keywords[entry_id] = dn
    return keywords

def parse_trait_data(filepath):
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

        for ev_match in re.finditer(
            r'ExtractAs\s*=\s*"(\w+)"', block
        ):
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

def format_tooltip_value(value, fmt):
    if fmt == "PercentDelta":
        pct = (value - 1) * 100
        pct = round(pct)
        if pct > 0:
            return f"+{pct}%"
        return f"{pct}%"
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

def strip_formatting(text):
    if not text:
        return ""
    text = re.sub(r'\{#\w+\}', '', text)
    text = re.sub(r'\{!\w+(\.\w+)*\}', '', text)
    text = re.sub(r'\\n', ' ', text)
    text = re.sub(r'\\Column\s+\d+', ' ', text)
    text = re.sub(r'\{[A-Z][A-Z0-9]*\}', '', text)
    text = re.sub(r'\\\[', '[', text)
    text = re.sub(r'\\\]', ']', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def resolve_template(text, trait_id=None, keywords=None, tooltip_data=None):
    if not text:
        return ""

    result = text

    def replace_keyword(m):
        kw_name = m.group(1)
        if keywords and kw_name in keywords:
            return keywords[kw_name]
        return kw_name

    result = re.sub(r'\{\$Keywords\.(\w+)\}', replace_keyword, result)

    result = re.sub(r'\{\$TempTextData\.\w+(:\w+)?\}', '', result)

    def replace_tooltip(m):
        var_name = m.group(1)
        fmt_suffix = m.group(2) or ""

        if tooltip_data and trait_id and trait_id in tooltip_data:
            val = tooltip_data[trait_id].get(var_name)
            if val:
                return val

        return f"[?{var_name}]"

    result = re.sub(r'\{\$TooltipData\.(\w+)(:\w+)?\}', replace_tooltip, result)

    result = re.sub(r'\{#\w+\}', '', result)

    result = re.sub(r'\{!Icons\.HealthRestore_Small\}', '', result)
    result = re.sub(r'\{!Icons\.HealthDown_Small\}', '', result)
    result = re.sub(r'\{!Icons\.Currency_Small\}', ' Obols', result)
    result = re.sub(r'\{!Icons\.Ammo\}', ' Bloodstones', result)
    result = re.sub(r'\{!Icons\.RightArrow\}', ' to ', result)
    result = re.sub(r'\{!Icons\.Bullet\}', '', result)
    result = re.sub(r'\{!\w+(\.\w+)*\}', '', result)

    result = re.sub(r'\{[A-Z][A-Z0-9]*\}', '', result)

    result = re.sub(r'\\Column\s+\d+', ' ', result)

    result = result.replace('\\n', '. ')

    result = result.replace('\\[', '[').replace('\\]', ']')

    result = result.replace('%%', '%')

    result = re.sub(r'--(\d)', r'-\1', result)
    result = re.sub(r'\+\+(\d)', r'+\1', result)
    result = re.sub(r'\+-(\d)', r'-\1', result)
    result = re.sub(r'-\+(\d)', r'+\1', result)

    result = re.sub(r'\s+', ' ', result)
    result = re.sub(r'\.\s*\.', '.', result)
    result = re.sub(r'\s+\.', '.', result)
    result = re.sub(r'\.\s*,', ',', result)
    result = re.sub(r',\s*\.', '.', result)
    result = re.sub(r':\s+:', ':', result)
    result = result.strip()
    if result.endswith('.'):
        result = result[:-1].strip()
    result = result.strip()

    return result

def extract_lua_table_keys(filepath, table_name):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = rf'(?:local\s+)?{re.escape(table_name)}\s*=\s*\{{'
    m = re.search(pattern, content)
    if not m:
        print(f"  WARNING: Table '{table_name}' not found in {filepath}", file=sys.stderr)
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
    for line in table_body.split('\n'):
        stripped = line.strip()
        km = re.match(r'(\w+)\s*=', stripped)
        if km:
            key = km.group(1)
            if key not in ('text', 'values', 'base', 'perLevel', 'static',
                           'usesLevel', 'formatFunc', 'baseValue', 'local',
                           'function', 'if', 'then', 'end', 'return', 'for'):
                keys.append(key)

    return keys

def escape_lua_string(s):
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    return s

def generate_simple_table(table_name, entries, helptext, keywords, tooltip_data, use_description=True):
    lines = [f"local {table_name} = {{"]
    unresolved_count = 0

    for key in entries:
        entry = helptext.get(key, {})
        if use_description:
            raw = entry.get('Description', '')
        else:
            raw = entry.get('DisplayName', '')

        if not raw:
            lines.append(f'    -- {key}: NOT FOUND in HelpText')
            continue

        if use_description:
            resolved = resolve_template(raw, key, keywords, tooltip_data)
        else:
            resolved = strip_formatting(raw)

        if '[?' in resolved:
            unresolved_count += 1

        escaped = escape_lua_string(resolved)
        lines.append(f'    {key} = "{escaped}",')

    lines.append("}")
    return '\n'.join(lines), unresolved_count

def generate_names_table(table_name, entries, helptext, keywords=None):
    lines = [f"local {table_name} = {{"]

    for key in entries:
        entry = helptext.get(key, {})
        raw = entry.get('DisplayName', '')
        if not raw:
            lines.append(f'    -- {key}: NOT FOUND in HelpText')
            continue

        resolved = resolve_template(raw, key, keywords, None)
        escaped = escape_lua_string(resolved)
        lines.append(f'    {key} = "{escaped}",')

    lines.append("}")
    return '\n'.join(lines)

def extract_current_descriptions(filepath, table_name):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = rf'(?:local\s+)?{re.escape(table_name)}\s*=\s*\{{'
    m = re.search(pattern, content)
    if not m:
        return {}

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

    descriptions = {}

    for match in re.finditer(r'(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"', table_body):
        key = match.group(1)
        value = match.group(2).replace('\\"', '"').replace('\\\\', '\\')
        if key not in ('text', 'base', 'static', 'values', 'perLevel'):
            descriptions[key] = value

    for match in re.finditer(r'(\w+)\s*=\s*(\{[^}]*\{[^}]*\}[^}]*\})', table_body):
        key = match.group(1)
        raw_table = match.group(2)
        if key not in ('text', 'base', 'static', 'values', 'perLevel'):
            descriptions[key] = ("__RAW_LUA__", raw_table.strip())

    return descriptions

def generate_table_with_fallback(table_name, keys, helptext, keywords, tooltip_data,
                                  fallback_file, fallback_table):
    fallback = {}
    if fallback_file and fallback_table and os.path.exists(fallback_file):
        fallback = extract_current_descriptions(fallback_file, fallback_table)

    lines = [f"local {table_name} = {{"]
    game_text_count = 0
    fallback_count = 0
    not_found_count = 0

    for key in keys:
        entry = helptext.get(key, {})
        raw = entry.get('Description', '')

        if not raw:
            fb = fallback.get(key)
            if fb is not None:
                if isinstance(fb, tuple) and fb[0] == "__RAW_LUA__":
                    lines.append(f'    {key} = {fb[1]},')
                else:
                    escaped = escape_lua_string(fb)
                    lines.append(f'    {key} = "{escaped}",')
                fallback_count += 1
            else:
                lines.append(f'    -- {key}: NOT FOUND in HelpText or fallback')
                not_found_count += 1
            continue

        resolved = resolve_template(raw, key, keywords, tooltip_data)

        if '[?' in resolved:
            fb = fallback.get(key)
            if fb is not None:
                if isinstance(fb, tuple) and fb[0] == "__RAW_LUA__":
                    lines.append(f'    {key} = {fb[1]},')
                else:
                    escaped = escape_lua_string(fb)
                    lines.append(f'    {key} = "{escaped}",')
                fallback_count += 1
            else:
                escaped = escape_lua_string(resolved)
                lines.append(f'    {key} = "{escaped}",  -- UNRESOLVED')
                not_found_count += 1
        else:
            escaped = escape_lua_string(resolved)
            lines.append(f'    {key} = "{escaped}",')
            game_text_count += 1

    lines.append("}")
    code = '\n'.join(lines)

    print(f"  Game text: {game_text_count}, Fallback: {fallback_count}, Unresolved: {not_found_count}")
    return code

def generate_names_table_with_fallback(table_name, keys, helptext, keywords,
                                        fallback_file, fallback_table):
    fallback = {}
    if fallback_file and fallback_table and os.path.exists(fallback_file):
        fallback = extract_current_descriptions(fallback_file, fallback_table)

    lines = [f"local {table_name} = {{"]
    game_text_count = 0
    fallback_count = 0

    for key in keys:
        entry = helptext.get(key, {})
        raw = entry.get('DisplayName', '')

        if not raw:
            fb = fallback.get(key)
            if fb is not None and not isinstance(fb, tuple):
                escaped = escape_lua_string(fb)
                lines.append(f'    {key} = "{escaped}",')
                fallback_count += 1
            else:
                lines.append(f'    -- {key}: NOT FOUND in HelpText or fallback')
            continue

        resolved = resolve_template(raw, key, keywords, None)

        is_unresolved_keyword = (
            ' ' not in resolved and
            resolved[0:1].isupper() and
            re.match(r'^[A-Za-z]+$', resolved) and
            resolved != raw
        )

        if is_unresolved_keyword:
            fb = fallback.get(key)
            if fb is not None and not isinstance(fb, tuple):
                escaped = escape_lua_string(fb)
                lines.append(f'    {key} = "{escaped}",')
                fallback_count += 1
            else:
                escaped = escape_lua_string(resolved)
                lines.append(f'    {key} = "{escaped}",  -- unresolved keyword')
        else:
            escaped = escape_lua_string(resolved)
            lines.append(f'    {key} = "{escaped}",')
            game_text_count += 1

    lines.append("}")
    code = '\n'.join(lines)

    print(f"  Game text: {game_text_count}, Fallback: {fallback_count}")
    return code

def replace_table_in_file(filepath, table_name, new_table_code):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = rf'(local\s+{re.escape(table_name)}\s*=\s*)\{{'
    m = re.search(pattern, content)
    if not m:
        print(f"  WARNING: Could not find '{table_name}' in {filepath}")
        return False

    start = m.start()
    brace_start = m.end() - 1
    depth = 0
    pos = brace_start
    in_string = False
    escape_next = False

    while pos < len(content):
        ch = content[pos]
        if escape_next:
            escape_next = False
            pos += 1
            continue
        if ch == '\\':
            escape_next = True
            pos += 1
            continue
        if ch == '"' and not in_string:
            in_string = True
            pos += 1
            continue
        if ch == '"' and in_string:
            in_string = False
            pos += 1
            continue
        if in_string:
            pos += 1
            continue
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                break
        pos += 1

    end = pos + 1

    new_content = content[:start] + new_table_code + content[end:]

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    return True

def main():
    apply_mode = "--apply" in sys.argv

    print("=" * 70)
    print("Hades Game Text Parser for Accessibility Mods")
    if apply_mode:
        print("*** APPLY MODE — writing changes to mod files ***")
    print("=" * 70)
    print()

    print(f"Parsing HelpText: {HELPTEXT_PATH}")
    helptext = parse_sjson(HELPTEXT_PATH)
    resolve_inheritance(helptext)
    print(f"  Found {len(helptext)} entries")

    keywords = build_keywords(helptext)
    print(f"  Built keyword lookup ({len(keywords)} entries)")

    print(f"Parsing TraitData: {TRAITDATA_PATH}")
    tooltip_data = parse_trait_data(TRAITDATA_PATH)
    print(f"  Extracted tooltip data for {len(tooltip_data)} traits")
    print()

    replacements = []

    boons_file = os.path.join(MODS_DIR, "AccessibleBoons", "AccessibleBoons.lua")
    if os.path.exists(boons_file):
        print("=" * 70)
        print("AccessibleBoons")
        print("=" * 70)

        for table_name in ["HammerDescriptions", "GodBoonDescriptions",
                           "ChaosBlessingDescriptions", "ChaosCurseDescriptions"]:
            keys = extract_lua_table_keys(boons_file, table_name)
            print(f"\n--- {table_name} ({len(keys)} keys) ---")
            code = generate_table_with_fallback(
                table_name, keys, helptext, keywords, tooltip_data,
                boons_file, table_name
            )
            if not apply_mode:
                print(code)
            replacements.append((boons_file, table_name, code))
            print()

    well_file = os.path.join(MODS_DIR, "AccessibleWell", "AccessibleWell.lua")
    if os.path.exists(well_file):
        print("=" * 70)
        print("AccessibleWell")
        print("=" * 70)

        keys = extract_lua_table_keys(well_file, "WellItemNames")
        print(f"\n--- WellItemNames ({len(keys)} keys) ---")
        code = generate_names_table_with_fallback(
            "WellItemNames", keys, helptext, keywords,
            well_file, "WellItemNames"
        )
        if not apply_mode:
            print(code)
        replacements.append((well_file, "WellItemNames", code))
        print()

        keys = extract_lua_table_keys(well_file, "WellItemDescriptions")
        print(f"\n--- WellItemDescriptions ({len(keys)} keys) ---")
        code = generate_table_with_fallback(
            "WellItemDescriptions", keys, helptext, keywords, tooltip_data,
            well_file, "WellItemDescriptions"
        )
        if not apply_mode:
            print(code)
        replacements.append((well_file, "WellItemDescriptions", code))
        print()

    contractor_file = os.path.join(MODS_DIR, "AccessibleContractor", "AccessibleContractor.lua")
    if os.path.exists(contractor_file):
        print("=" * 70)
        print("AccessibleContractor")
        print("=" * 70)

        keys = extract_lua_table_keys(contractor_file, "ContractorItemNames")
        print(f"\n--- ContractorItemNames ({len(keys)} keys) ---")
        code = generate_names_table_with_fallback(
            "ContractorItemNames", keys, helptext, keywords,
            contractor_file, "ContractorItemNames"
        )
        if not apply_mode:
            print(code)
        replacements.append((contractor_file, "ContractorItemNames", code))
        print()

        keys = extract_lua_table_keys(contractor_file, "ContractorItemDescriptions")
        print(f"\n--- ContractorItemDescriptions ({len(keys)} keys) ---")
        code = generate_table_with_fallback(
            "ContractorItemDescriptions", keys, helptext, keywords, tooltip_data,
            contractor_file, "ContractorItemDescriptions"
        )
        if not apply_mode:
            print(code)
        replacements.append((contractor_file, "ContractorItemDescriptions", code))
        print()

    keepsakes_file = os.path.join(MODS_DIR, "AccessibleKeepsakes", "AccessibleKeepsakes.lua")
    if os.path.exists(keepsakes_file):
        print("=" * 70)
        print("AccessibleKeepsakes")
        print("=" * 70)

        keys = extract_lua_table_keys(keepsakes_file, "KeepsakeDescriptions")
        print(f"\n--- KeepsakeDescriptions ({len(keys)} keys) ---")
        code = generate_table_with_fallback(
            "KeepsakeDescriptions", keys, helptext, keywords, tooltip_data,
            keepsakes_file, "KeepsakeDescriptions"
        )
        if not apply_mode:
            print(code)
        replacements.append((keepsakes_file, "KeepsakeDescriptions", code))
        print()

    quest_file = os.path.join(MODS_DIR, "AccessibleQuestLog", "AccessibleQuestLog.lua")
    if os.path.exists(quest_file):
        print("=" * 70)
        print("AccessibleQuestLog")
        print("=" * 70)

        keys = extract_lua_table_keys(quest_file, "QuestDescriptions")
        print(f"\n--- QuestDescriptions ({len(keys)} keys) ---")
        code = generate_table_with_fallback(
            "QuestDescriptions", keys, helptext, keywords, tooltip_data,
            quest_file, "QuestDescriptions"
        )
        if not apply_mode:
            print(code)
        replacements.append((quest_file, "QuestDescriptions", code))
        print()

    mirror_file = os.path.join(MODS_DIR, "AccessibleMirror", "AccessibleMirror.lua")
    if os.path.exists(mirror_file):
        print("=" * 70)
        print("AccessibleMirror (DisplayNames only)")
        print("=" * 70)

        keys = extract_lua_table_keys(mirror_file, "MetaUpgradeDisplayNames")
        print(f"\n--- MetaUpgradeDisplayNames ({len(keys)} keys) ---")
        code = generate_names_table_with_fallback(
            "MetaUpgradeDisplayNames", keys, helptext, keywords,
            mirror_file, "MetaUpgradeDisplayNames"
        )
        if not apply_mode:
            print(code)
        replacements.append((mirror_file, "MetaUpgradeDisplayNames", code))
        print()

    if apply_mode:
        print("=" * 70)
        print("APPLYING CHANGES")
        print("=" * 70)

        files_updated = set()
        for filepath, table_name, new_code in replacements:
            print(f"  Replacing {table_name} in {os.path.basename(filepath)}...", end=" ")
            if replace_table_in_file(filepath, table_name, new_code):
                print("OK")
                files_updated.add(filepath)
            else:
                print("FAILED")

        print()
        print(f"  Updated {len(files_updated)} files:")
        for f in sorted(files_updated):
            print(f"    {f}")
    else:
        print("=" * 70)
        print("DRY RUN — use --apply to write changes to mod files")
        print("=" * 70)
    print()

if __name__ == "__main__":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    main()
