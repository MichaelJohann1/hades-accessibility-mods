import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_language_files as g

MODS = g.MODS_DIR
TABLE_FILES = {}
for n, (f, _) in g.HELPTEXT_TABLES.items(): TABLE_FILES[n] = f
for n, (f, _) in g.HYBRID_TABLES.items(): TABLE_FILES[n] = f
for n, (f,) in g.MANUAL_ONLY_TABLES.items(): TABLE_FILES[n] = f
TABLE_FILES["MetaUpgradeDescriptions"] = "AccessibleMirror/AccessibleMirror.lua"
TABLE_FILES["MusicTrackDisplayNames"] = "AccessibleMusicPlayer/AccessibleMusicPlayer.lua"
TABLE_FILES["CuePrefixToSpeaker"] = "AccessibleNotifications/AccessibleNotifications.lua"

SKIP = {'text', 'values', 'base', 'perLevel', 'static', 'field', 'template',
        'fallback', 'usesLevel', 'formatFunc', 'baseValue', 'local', 'function',
        'if', 'then', 'end', 'return', 'for'}


def table_body(content, tn):
    m = re.search(r'(?:local\s+)?' + re.escape(tn) + r'\s*=\s*\{', content)
    if not m:
        return None
    s = m.end(); d = 1; p = s
    while p < len(content) and d > 0:
        if content[p] == '{': d += 1
        elif content[p] == '}': d -= 1
        p += 1
    return content[s:p - 1]


def extract_kv(fp, tn):
    content = open(fp, encoding='utf-8').read()
    body = table_body(content, tn)
    if body is None:
        return {}
    kv = {}
    for km in re.finditer(r'(?m)^\s*(\w+)\s*=\s*"([^"]*)"', body):
        kv[km.group(1)] = km.group(2)
    for km in re.finditer(r'(?m)^\s*\["([^"]+)"\]\s*=\s*"([^"]*)"', body):
        kv[km.group(1)] = km.group(2)
    for km in re.finditer(r'(?m)^\s*(\w+)\s*=\s*\{', body):
        kv.setdefault(km.group(1), "<table>")
    return kv


de = open(os.path.join(g.OUTPUT_DIR, 'de.lua'), encoding='utf-8').read()
trans = {}
for tm in re.finditer(r'L\.(\w+)\s*=\s*\{(.*?)\n\}', de, re.S):
    ks = set()
    for km in re.finditer(r'(?m)^\s*(\w+)\s*=', tm.group(2)): ks.add(km.group(1))
    for km in re.finditer(r'(?m)^\s*\["([^"]+)"\]\s*=', tm.group(2)): ks.add(km.group(1))
    trans[tm.group(1)] = ks

total = 0
detail = {}
for t, f in sorted(TABLE_FILES.items()):
    kv = extract_kv(os.path.join(MODS, f), t)
    tk = trans.get(t, set())
    gaps = [k for k in kv if k not in SKIP and k not in tk]
    if gaps:
        total += len(gaps)
        nkeys = len([k for k in kv if k not in SKIP])
        print(f"{t}: {len(gaps)} untranslated of {nkeys}")
        detail[t] = [(k, kv[k]) for k in gaps]

print(f"\nTOTAL UNTRANSLATED KEYS: {total}  (x10 languages = {total*10} translations)")

if "--detail" in sys.argv:
    import json
    json.dump(detail, open("scripts/gap_detail.json", "w", encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print("wrote scripts/gap_detail.json")
