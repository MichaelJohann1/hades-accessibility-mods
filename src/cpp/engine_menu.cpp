#include "engine_menu.h"
#include "embedded_helptext.h"
#include "logger.h"
#include "tolk_loader.h"
#include "vendor/MinHook/MinHook.h"
#include <Windows.h>
#include <cstdint>
#include <cstring>
#include <cstdio>

// ============================================================
// Engine-menu accessibility.
//
// The engine's menus are pure C++ sgg screens that derive from sgg::MenuScreen
// (Title, Pause, Settings, Controls/KeyMapping, Save select, dialogs, ...). Lua
// never creates their components, so OnMouseOver/AttachLua can't reach them.
//
// We locate every MenuScreen-derived class via the MSVC RTTI walk (anchored on
// the stable class-name string, not prologue bytes), hook each one's per-frame
// Update (vtable slot 3, signature Update(this,float) — dedup'd since several
// classes share the base implementation), and on each selection change read the
// highlighted component (screen+0x128) and narrate it via Tolk — its HelpTextId
// (button+0x410) if present, else its component name (component+0x90). All reads
// are SEH-guarded and pointer-probed.
// ============================================================

namespace {

uint8_t* g_base = nullptr;

struct Section { uint8_t* start = nullptr; uint32_t vsize = 0; uint32_t rawsize = 0; };
Section g_text, g_rdata, g_data;

bool GetSection(HMODULE h, const char* name, Section& out)
{
    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(h);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(reinterpret_cast<uint8_t*>(h) + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return false;
    size_t nlen = strlen(name);
    auto* sec = IMAGE_FIRST_SECTION(nt);
    for (WORD i = 0; i < nt->FileHeader.NumberOfSections; i++) {
        if (nlen <= 8 && memcmp(sec[i].Name, name, nlen) == 0 && (nlen == 8 || sec[i].Name[nlen] == 0)) {
            out.start   = reinterpret_cast<uint8_t*>(h) + sec[i].VirtualAddress;
            out.vsize   = sec[i].Misc.VirtualSize;
            out.rawsize = sec[i].SizeOfRawData;
            return true;
        }
    }
    return false;
}

inline uint32_t ToRVA(const void* p) { return static_cast<uint32_t>(reinterpret_cast<const uint8_t*>(p) - g_base); }
bool InText(uint32_t rva) { uint32_t s = ToRVA(g_text.start); return rva >= s && rva < s + g_text.vsize; }
bool InSection(const void* p, const Section& s)
{
    return reinterpret_cast<const uint8_t*>(p) >= s.start &&
           reinterpret_cast<const uint8_t*>(p) <  s.start + s.vsize;
}

// ---- RTTI: resolve a class vtable from its sgg class name ----
uint32_t FindTD(const char* cls)
{
    char pat[160];
    int n = snprintf(pat, sizeof(pat), ".?AV%s@sgg@@", cls);
    if (n <= 0) return 0;
    size_t patlen = (size_t)n;
    uint8_t* d = g_data.start;
    for (size_t i = 0; i + patlen + 1 <= g_data.rawsize; i++)
        if (d[i] == '.' && memcmp(d + i, pat, patlen + 1) == 0)
            return ToRVA(d + i - 0x10);
    return 0;
}

uint32_t FindCOL(uint32_t tdRVA)
{
    uint8_t* r = g_rdata.start;
    uint32_t rdataRVA = ToRVA(r);
    uint32_t firstAny = 0;
    for (size_t off = 0; off + 0x18 <= g_rdata.vsize; off += 4) {
        if (*reinterpret_cast<uint32_t*>(r + off) != 1) continue;
        if (*reinterpret_cast<uint32_t*>(r + off + 0x0C) != tdRVA) continue;
        uint32_t colRVA = rdataRVA + (uint32_t)off;
        if (*reinterpret_cast<uint32_t*>(r + off + 0x14) != colRVA) continue;
        if (*reinterpret_cast<uint32_t*>(r + off + 0x04) == 0) return colRVA;
        if (!firstAny) firstAny = colRVA;
    }
    return firstAny;
}

void* FindVtable(uint32_t colRVA)
{
    uint64_t colVA = reinterpret_cast<uint64_t>(g_base + colRVA);
    uint8_t* r = g_rdata.start;
    for (size_t off = 0; off + 8 <= g_rdata.vsize; off += 8)
        if (*reinterpret_cast<uint64_t*>(r + off) == colVA) return r + off + 8;
    return nullptr;
}

void* ResolveVtable(const char* cls)
{
    uint32_t td = FindTD(cls);   if (!td)  return nullptr;
    uint32_t col = FindCOL(td);  if (!col) return nullptr;
    return FindVtable(col);
}

// ---- SEH-guarded reads ----
bool SafeReadPtr(const void* p, void** out)
{
    __try { *out = *reinterpret_cast<void* const*>(p); return true; }
    __except (EXCEPTION_EXECUTE_HANDLER) { return false; }
}
bool SafeReadBytes(void* dst, const void* src, size_t n)
{
    __try { memcpy(dst, src, n); return true; }
    __except (EXCEPTION_EXECUTE_HANDLER) { return false; }
}

// Reverse-RTTI: object vtable -> class name (for verbose dumps).
bool ClassNameOfVtable(void* vtbl, char* out, size_t outsz)
{
    if (!vtbl || !InSection(vtbl, g_rdata)) return false;
    void* col;
    if (!SafeReadPtr(reinterpret_cast<uint8_t*>(vtbl) - 8, &col) || !InSection(col, g_rdata)) return false;
    uint32_t tdRVA;
    if (!SafeReadBytes(&tdRVA, reinterpret_cast<uint8_t*>(col) + 0x0C, 4)) return false;
    uint8_t* td = g_base + tdRVA;
    if (!InSection(td, g_data)) return false;
    char name[256];
    if (!SafeReadBytes(name, td + 0x10, sizeof(name))) return false;
    name[sizeof(name) - 1] = 0;
    if (strncmp(name, ".?AV", 4) != 0) return false;
    const char* start = name + 4;
    size_t i = 0;
    for (; start[i] && start[i] != '@' && i < outsz - 1; i++) out[i] = start[i];
    out[i] = 0;
    return i > 0;
}

// Interpret memory as an MSVC std::string (SSO when cap<=15).
int TryReadStdString(const void* addr, char* out, size_t outsz)
{
    uint8_t hdr[0x20];
    if (!SafeReadBytes(hdr, addr, sizeof(hdr))) return -1;
    uint64_t len = *reinterpret_cast<uint64_t*>(hdr + 0x10);
    uint64_t cap = *reinterpret_cast<uint64_t*>(hdr + 0x18);
    if (len == 0 || len > 200 || cap < len || cap > 0x100000) return -1;
    const char* data; char heap[256];
    if (cap <= 15) data = reinterpret_cast<const char*>(hdr);
    else {
        void* p = *reinterpret_cast<void**>(hdr); if (!p) return -1;
        size_t rd = (len < 255) ? (size_t)len + 1 : 255;
        if (!SafeReadBytes(heap, p, rd)) return -1;
        data = heap;
    }
    if (data[len] != 0) return -1;
    size_t L = (len < outsz - 1) ? (size_t)len : outsz - 1;
    for (size_t i = 0; i < L; i++) { unsigned char c = (unsigned char)data[i]; if (c < 0x20 || c > 0x7E) return -1; out[i] = (char)c; }
    out[L] = 0;
    return (int)L;
}

bool g_verboseDump = false;   // set true to log selected-component structure

// Verbose: dump an object's ASCII runs, std::strings, and named pointer members.
void DumpObject(void* obj, int depth, const char* tag)
{
    if (!obj) return;
    uint8_t* o = reinterpret_cast<uint8_t*>(obj);
    void* vt = nullptr; char cn[128] = {};
    if (SafeReadPtr(o, &vt)) ClassNameOfVtable(vt, cn, sizeof(cn));
    Log::Info("[MENU-DBG] %*sOBJ %s obj=%p class=%s", depth * 2, "", tag, obj, cn[0] ? cn : "?");
    uint32_t win = 0xC00; uint8_t buf[0xC00];
    if (!SafeReadBytes(buf, o, win)) { win = 0x80; if (!SafeReadBytes(buf, o, win)) return; }
    for (uint32_t i = 0; i < win;) {
        if (buf[i] >= 0x20 && buf[i] < 0x7F) {
            uint32_t j = i; while (j < win && buf[j] >= 0x20 && buf[j] < 0x7F) j++;
            if (j - i >= 4) { char s[80]; uint32_t L = (j - i < 79) ? (j - i) : 79; memcpy(s, buf + i, L); s[L] = 0;
                Log::Info("[MENU-DBG] %*s  ascii@0x%X: \"%s\"", depth * 2, "", i, s); }
            i = j;
        } else i++;
    }
    char str[256], ccn[128];
    for (uint32_t off = 0; off + 0x20 <= win; off += 8) {
        int sl = TryReadStdString(o + off, str, sizeof(str));
        if (sl > 0) { Log::Info("[MENU-DBG] %*s  str@0x%X: \"%s\"", depth * 2, "", off, str); continue; }
        void* p;
        if (SafeReadPtr(o + off, &p) && p) {
            void* pvt;
            if (SafeReadPtr(p, &pvt) && ClassNameOfVtable(pvt, ccn, sizeof(ccn))) {
                Log::Info("[MENU-DBG] %*s  ptr@0x%X -> %s (%p)", depth * 2, "", off, ccn, p);
                if (depth == 0 && (strstr(ccn, "Text") || strstr(ccn, "Button"))) DumpObject(p, depth + 1, "sub");
            }
        }
    }
    // Numeric fields: slider fill (float in 0..1), toggle/binding state (small
    // int). These reveal values that aren't stored as text.
    for (uint32_t off = 0; off + 4 <= win; off += 4) {
        uint32_t u; memcpy(&u, buf + off, 4);
        float f;   memcpy(&f, buf + off, 4);
        if (f > 0.0005f && f < 1.0001f) Log::Info("[MENU-DBG] %*s  f32@0x%X: %.3f", depth * 2, "", off, f);
        else if (u >= 1 && u <= 400)    Log::Info("[MENU-DBG] %*s  i32@0x%X: %u", depth * 2, "", off, u);
    }
}

// ---- Label extraction / speech ----

// A button's HelpTextId is an inline char buffer (e.g. "MainMenuScreen_PlayGame").
bool ValidHelpId(const char* s)
{
    if (s[0] < 'A' || s[0] > 'Z') return false;
    for (int i = 0; i < 120; i++) { char c = s[i]; if (c == 0) return i >= 3; if (c < 0x20 || c > 0x7E) return false; }
    return false;
}
bool ValidName(const char* s)   // a component name, e.g. "MusicVolumeSlider"
{
    if (s[0] < 'A' || s[0] > 'Z') return false;
    for (int i = 0; i < 80; i++) { char c = s[i]; if (c == 0) return i >= 2; if (c < 0x20 || c > 0x7E) return false; }
    return false;
}

// "MainMenuScreen_PlayGame" -> "Play Game". Drops "<Screen>_" prefix, splits
// camelCase, trims a trailing " Label".
void FriendlyLabel(const char* helpId, char* out, size_t outsz)
{
    const char* p = strrchr(helpId, '_'); p = p ? p + 1 : helpId;
    size_t o = 0;
    for (size_t i = 0; p[i] && o < outsz - 2; i++) {
        char c = p[i];
        if (i > 0 && c >= 'A' && c <= 'Z' && !(p[i-1] >= 'A' && p[i-1] <= 'Z') && p[i-1] != ' ') out[o++] = ' ';
        out[o++] = c;
    }
    out[o] = 0;
    if (o > 6 && strcmp(out + o - 6, " Label") == 0) out[o - 6] = 0;
}

// "MusicVolumeSlider" -> "Music Volume". Strips a known trailing component-type
// suffix, then splits camelCase. Fallback when there is no HelpTextId.
void NameToLabel(const char* name, char* out, size_t outsz)
{
    char tmp[96]; size_t L = 0;
    for (; name[L] && L < sizeof(tmp) - 1; L++) tmp[L] = name[L];
    tmp[L] = 0;
    static const char* kSfx[] = { "Button", "Slider", "Toggle", "Selector", "CheckBox",
                                  "TextBox", "Screen", "Dialog", "Entry", "Item", "Label", "Icon", "Box" };
    for (const char* sfx : kSfx) { size_t sl = strlen(sfx); if (L > sl && strcmp(tmp + L - sl, sfx) == 0) { tmp[L - sl] = 0; L -= sl; break; } }
    size_t o = 0;
    for (size_t i = 0; tmp[i] && o < outsz - 2; i++) {
        char c = tmp[i];
        if (i > 0 && c >= 'A' && c <= 'Z' && !(tmp[i-1] >= 'A' && tmp[i-1] <= 'Z') && tmp[i-1] != ' ') out[o++] = ' ';
        out[o++] = c;
    }
    out[o] = 0;
}

void SpeakLabel(const char* label)
{
    if (!label || !label[0]) return;
    static char s_last[200] = {};
    if (strcmp(label, s_last) == 0) return;
    strncpy_s(s_last, sizeof(s_last), label, _TRUNCATE);
    Log::Info("[ENGINE-MENU] speak: \"%s\"", label);
    if (!TolkLoader::IsAvailable()) return;
    wchar_t w[256];
    int n = MultiByteToWideChar(CP_UTF8, 0, label, -1, w, 256);
    if (n > 0) TolkLoader::Output(w, true);
}

// Accept text as a label. Normal items need >=2 chars with a letter (this skips
// value/decorative boxes holding "0", "p", "`"). In "loose" mode (key-binding
// rows) a short alnum token like "W", "0" or "F5" — the on-screen key — is kept.
bool AcceptLabel(const char* t, bool loose)
{
    int len = 0; bool letter = false, alnum = false;
    for (; t[len]; len++) {
        char c = t[len];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) { letter = true; alnum = true; }
        else if (c >= '0' && c <= '9') alnum = true;
    }
    if (len >= 2 && letter) return true;
    if (loose && len >= 1 && len <= 3 && alnum) return true;
    return false;
}

// Read a GUIComponentTextBox's rendered string (inline buffer at +0xA98),
// trimmed. Only writes `out` when the result passes AcceptLabel.
bool ReadTextBoxText(void* tb, char* out, size_t outsz, bool loose)
{
    char txt[96];
    if (!SafeReadBytes(txt, reinterpret_cast<uint8_t*>(tb) + 0xA98, sizeof(txt))) return false;
    txt[sizeof(txt) - 1] = 0;
    const char* t = txt; while (*t == ' ') t++;
    char tmp[96]; size_t L = 0;
    for (; t[L] && L < sizeof(tmp) - 1; L++) { unsigned char c = (unsigned char)t[L]; if (c < 0x20 || c > 0x7E) break; tmp[L] = t[L]; }
    while (L > 0 && tmp[L - 1] == ' ') L--;
    tmp[L] = 0;
    if (!AcceptLabel(tmp, loose)) return false;
    strncpy_s(out, outsz, tmp, _TRUNCATE);
    return true;
}

// Read the highlighted component's EXACT on-screen text: its own TextBox string
// if it is a TextBox, else the first child GUIComponentTextBox with a real label.
// Key-binding rows (RemappableButtonComponent) hold only the short key token, so
// a short binding like "W" is allowed there.
bool ReadDisplayedText(void* comp, char* out, size_t outsz)
{
    uint8_t* c = reinterpret_cast<uint8_t*>(comp);
    bool loose = false;
    void* cvt; char cn[64];
    if (SafeReadPtr(c, &cvt) && ClassNameOfVtable(cvt, cn, sizeof(cn))) {
        if (strcmp(cn, "GUIComponentTextBox") == 0 && ReadTextBoxText(comp, out, outsz, false)) return true;
        if (strstr(cn, "Remappable") || strstr(cn, "KeyControl")) loose = true;
    }
    for (uint32_t off = 0; off <= 0xC00; off += 8) {
        void* p; if (!SafeReadPtr(c + off, &p) || !p) continue;
        void* pvt; if (!SafeReadPtr(p, &pvt)) continue;
        char tn[64]; if (!ClassNameOfVtable(pvt, tn, sizeof(tn)) || strcmp(tn, "GUIComponentTextBox") != 0) continue;
        if (ReadTextBoxText(p, out, outsz, loose)) return true;
    }
    return false;
}

// Read a NUL-terminated inline ASCII string at comp+off (printable only).
bool ReadInlineAscii(void* comp, uint32_t off, char* out, size_t outsz)
{
    char buf[96];
    if (!SafeReadBytes(buf, reinterpret_cast<uint8_t*>(comp) + off, sizeof(buf))) return false;
    buf[sizeof(buf) - 1] = 0;
    size_t L = 0;
    for (; buf[L] && L < outsz - 1; L++) { unsigned char ch = (unsigned char)buf[L]; if (ch < 0x20 || ch > 0x7E) break; out[L] = buf[L]; }
    out[L] = 0;
    return L > 0;
}

// Some labels carry an icon/format prefix (e.g. God Mode's "@icon {#fmt}God
// Mode"); the game renders those to glyphs without persisting the plain string,
// and stores no inline HelpTextId. But the component name + owning screen class
// reconstruct the id: EasyModeButton on MiscSettingsScreen ->
// "MiscSettingsScreen_EasyModeLabel" -> "God Mode". The owning screen is at
// comp+0x840; settings toggles follow "<Screen>_<Name minus Button>Label".
bool ResolveByScreenAndName(void* comp, char* out, size_t outsz)
{
    char name[80];
    if (!SafeReadBytes(name, reinterpret_cast<uint8_t*>(comp) + 0x90, sizeof(name) - 1)) return false;
    name[sizeof(name) - 1] = 0;
    if (!ValidName(name)) return false;

    char core[80]; size_t L = 0;
    for (; name[L] && L < sizeof(core) - 1; L++) core[L] = name[L];
    core[L] = 0;
    static const char* kSfx[] = { "Button", "Toggle", "CheckBox", "Selector", "Slider" };
    for (const char* s : kSfx) { size_t sl = strlen(s); if (L > sl && strcmp(core + L - sl, s) == 0) { core[L - sl] = 0; L -= sl; break; } }
    if (L < 2) return false;

    void* scr;
    if (!SafeReadPtr(reinterpret_cast<uint8_t*>(comp) + 0x840, &scr)) return false;
    void* svt; char scn[64];
    if (!SafeReadPtr(scr, &svt) || !ClassNameOfVtable(svt, scn, sizeof(scn))) return false;

    char id[200]; const char* d;
    snprintf(id, sizeof(id), "%s_%sLabel", scn, core); d = HelpText::Lookup(id);
    if (!d) { snprintf(id, sizeof(id), "%s_%s", scn, core); d = HelpText::Lookup(id); }
    if (d && d[0]) { strncpy_s(out, outsz, d, _TRUNCATE); return true; }
    return false;
}

// Save/profile slots all share the generic name "ProfileButton" and persist no
// rendered text, but carry a distinct per-slot key (e.g. "Profile3") at +0x958.
// Surface it as "Profile 3" so slots read distinctly instead of all "Profile".
bool ResolveProfileSlot(void* comp, char* out, size_t outsz)
{
    char name[80];
    if (!SafeReadBytes(name, reinterpret_cast<uint8_t*>(comp) + 0x90, sizeof(name) - 1)) return false;
    name[sizeof(name) - 1] = 0;
    if (strncmp(name, "Profile", 7) != 0) return false;

    char key[64];
    if (!ReadInlineAscii(comp, 0x958, key, sizeof(key))) return false;
    if (strncmp(key, "Profile", 7) != 0) return false;     // expect "ProfileN"

    size_t o = 0;                                           // "Profile3" -> "Profile 3"
    for (size_t i = 0; key[i] && o < outsz - 2; i++) {
        if (i > 0 && key[i] >= '0' && key[i] <= '9' && !(key[i-1] >= '0' && key[i-1] <= '9') && key[i-1] != ' ') out[o++] = ' ';
        out[o++] = key[i];
    }
    out[o] = 0;
    return out[0] != 0;
}

// Diagnostic: dump every component in a screen's component vector (screen+0x148,
// an std::vector of component pointers) in order — class, name, scraped text,
// and the +0x958 key — so sibling structure (control action labels paired with
// key buttons, profile-slot sub-elements) and any richer text can be mapped.
void DumpScreenComponents(void* screen)
{
    uint8_t* s = reinterpret_cast<uint8_t*>(screen);
    void* begin = nullptr; void* end = nullptr;
    if (!SafeReadPtr(s + 0x148, &begin) || !SafeReadPtr(s + 0x150, &end)) return;
    if (!begin || !end || reinterpret_cast<uint8_t*>(end) < reinterpret_cast<uint8_t*>(begin)) return;
    size_t count = (reinterpret_cast<uint8_t*>(end) - reinterpret_cast<uint8_t*>(begin)) / 8;
    Log::Info("[SCR-DUMP] screen=%p components=%zu", screen, count);
    if (count > 256) count = 256;
    for (size_t i = 0; i < count; i++) {
        void* comp = nullptr;
        if (!SafeReadPtr(reinterpret_cast<uint8_t*>(begin) + i * 8, &comp) || !comp) continue;
        void* vt = nullptr; char cn[64] = "?";
        if (SafeReadPtr(comp, &vt)) ClassNameOfVtable(vt, cn, sizeof(cn));
        char name[80] = ""; if (SafeReadBytes(name, reinterpret_cast<uint8_t*>(comp) + 0x90, 79)) { name[79] = 0; if (!ValidName(name)) name[0] = 0; }
        char scr[120] = ""; ReadDisplayedText(comp, scr, sizeof(scr));
        char key[64] = ""; ReadInlineAscii(comp, 0x958, key, sizeof(key));
        Log::Info("[SCR-DUMP]  [%zu] cls=%s name=\"%s\" scrape=\"%s\" key958=\"%s\"", i, cn, name, scr, key);
    }
}

bool ClassIs(void* obj, const char* want)
{
    void* vt; char cn[64];
    if (!SafeReadPtr(obj, &vt) || !ClassNameOfVtable(vt, cn, sizeof(cn))) return false;
    return strcmp(cn, want) == 0;
}

// A control-binding row's action name ("Attack", "Move Up") lives in the sibling
// GUIComponentTextBox ("ControlLabel") that immediately precedes the selected key
// button (RemappableButtonComponent) in the screen's component vector
// (screen+0x148). Walk the vector tracking the latest ControlLabel; on reaching
// the key, announce "Action, Key" (or just "Action" when the key renders as an
// icon, e.g. mouse). The screen is the hooked `self`, not comp+0x840 (which may
// be a base subobject at a different address).
bool ResolveControlBinding(void* screen, void* comp, char* out, size_t outsz)
{
    uint8_t* s = reinterpret_cast<uint8_t*>(screen);
    void* begin = nullptr; void* end = nullptr;
    if (!SafeReadPtr(s + 0x148, &begin) || !SafeReadPtr(s + 0x150, &end)) return false;
    if (!begin || !end || reinterpret_cast<uint8_t*>(end) < reinterpret_cast<uint8_t*>(begin)) return false;
    size_t count = (reinterpret_cast<uint8_t*>(end) - reinterpret_cast<uint8_t*>(begin)) / 8;
    if (count > 256) count = 256;

    char action[120] = ""; bool found = false;
    for (size_t i = 0; i < count; i++) {
        void* e;
        if (!SafeReadPtr(reinterpret_cast<uint8_t*>(begin) + i * 8, &e) || !e) continue;
        if (e == comp) {
            found = true;
            char key[40] = ""; ReadDisplayedText(comp, key, sizeof(key));   // bound key (loose)
            if (action[0] && key[0]) snprintf(out, outsz, "%s, %s", action, key);
            else if (action[0])      strncpy_s(out, outsz, action, _TRUNCATE);
            return action[0] != 0;
        }
        char nm[64];
        if (SafeReadBytes(nm, reinterpret_cast<uint8_t*>(e) + 0x90, sizeof(nm) - 1)) {
            nm[sizeof(nm) - 1] = 0;
            if (strcmp(nm, "ControlLabel") == 0) {
                char t[120];
                if (ReadDisplayedText(e, t, sizeof(t))) strncpy_s(action, sizeof(action), t, _TRUNCATE);
            }
        }
    }
    (void)found;
    return false;
}

// When a dialog pops up, announce its body/prompt text — not just its OK/Cancel
// buttons. The prompt is a GUIComponentTextBox in the dialog's component vector;
// pick the longest readable one (titles/instructions are shorter than the body).
bool ReadDialogMessage(void* screen, char* out, size_t outsz)
{
    uint8_t* s = reinterpret_cast<uint8_t*>(screen);
    void* begin = nullptr; void* end = nullptr;
    if (!SafeReadPtr(s + 0x148, &begin) || !SafeReadPtr(s + 0x150, &end)) return false;
    if (!begin || !end || reinterpret_cast<uint8_t*>(end) < reinterpret_cast<uint8_t*>(begin)) return false;
    size_t count = (reinterpret_cast<uint8_t*>(end) - reinterpret_cast<uint8_t*>(begin)) / 8;
    if (count > 256) count = 256;

    char best[260] = ""; size_t bestLen = 0;
    for (size_t i = 0; i < count; i++) {
        void* e;
        if (!SafeReadPtr(reinterpret_cast<uint8_t*>(begin) + i * 8, &e) || !e) continue;
        if (!ClassIs(e, "GUIComponentTextBox")) continue;
        char t[260];
        if (!ReadDisplayedText(e, t, sizeof(t))) continue;
        size_t L = strlen(t);
        if (L > bestLen) { bestLen = L; strncpy_s(best, sizeof(best), t, _TRUNCATE); }
    }
    if (!best[0]) return false;
    strncpy_s(out, outsz, best, _TRUNCATE);
    return true;
}

// GUIComponentSlider stores its fill ratio (0..1) as a float at +0x38; render it
// as a percentage to append to the label -> "Master Volume, 100%".
bool ReadSliderPercent(void* comp, char* out, size_t outsz)
{
    float v;
    if (!SafeReadBytes(&v, reinterpret_cast<uint8_t*>(comp) + 0x38, 4)) return false;
    if (!(v >= 0.0f && v <= 1.0f)) return false;
    snprintf(out, outsz, "%d%%", (int)(v * 100.0f + 0.5f));
    return true;
}

// ============================================================
// The set of engine menus to narrate (every MenuScreen-derived class except the
// in-game HUD). Re-derive after a game patch with re-tools/engine_menu_classes.py.
// ============================================================
struct MenuDef { const char* cls; const char* friendly; };
static const MenuDef kMenus[] = {
    { "MainMenuScreen",          "Main menu" },
    { "PauseScreen",             "Pause menu" },
    { "MiscSettingsScreen",      "Settings" },
    { "SettingsMenuScreen",      "Settings" },
    { "SettingsScreen",          "Settings" },
    { "ResolutionScreen",        "Resolution" },
    { "CloudSettingsScreen",     "Cloud settings" },
    { "LanguageScreen",          "Language" },
    { "KeyMappingScreen",        "Controls" },
    { "LoadSaveScreen",          "Save select" },
    { "LoadScreen",              "Load" },
    { "RemoteProfileScreen",     "Profiles" },
    { "ExitConfirmDialog",       "Exit" },
    { "MessageDialog",           "Message" },
    { "ThreeWayDialog",          "Dialog" },
    { "AnnouncementScreen",      "Announcement" },
    { "AboutScreen",             "About" },
    { "PatchNotesScreen",        "Patch notes" },
    { "CloudSaveDownloadDialog", "Cloud save" },
    { "CloudSaveUploadDialog",   "Cloud save" },
    { "LaunchScreen",            "Launch" },
    { "ShellScreen",             "Menu" },
    // NOTE: InGameUI also derives from MenuScreen but is the HUD — excluded.
};
static const int kMenuTotal = (int)(sizeof(kMenus) / sizeof(kMenus[0]));

// Resolved menus (vtable -> friendly name) for identifying `this` in the hook.
struct Resolved { const char* cls; const char* friendly; void* vtable; bool dialog; };
static Resolved g_menu[48];
static int g_menuCount = 0;

const char* FriendlyForVtable(void* vtbl)
{
    for (int i = 0; i < g_menuCount; i++) if (g_menu[i].vtable == vtbl) return g_menu[i].friendly;
    return nullptr;
}
bool IsDialogVtable(void* vtbl)
{
    for (int i = 0; i < g_menuCount; i++) if (g_menu[i].vtable == vtbl) return g_menu[i].dialog;
    return false;
}

// Per-screen selection state. Several menu screens can be active at once (a
// dialog or settings screen on top of the main menu, a persistent container,
// etc.), so each screen tracks its own last selection — background screens whose
// selection never changes are ignored.
struct ScrState { void* screen; void* lastSel; };
static ScrState g_scr[8] = {};
static int g_scrNext = 0;
static ScrState* GetScrState(void* screen)
{
    for (int i = 0; i < 8; i++) if (g_scr[i].screen == screen) return &g_scr[i];
    ScrState* e = &g_scr[g_scrNext]; g_scrNext = (g_scrNext + 1) & 7;
    e->screen = screen; e->lastSel = nullptr;
    return e;
}

// Identify the active menu by `this`'s vtable; narrate its highlighted item when
// the selection changes. The menu name is announced only when the *focused* menu
// switches (so it isn't repeated before every item).
void OnAnyMenuUpdate(void* self)
{
    __try {
        uint8_t* s = reinterpret_cast<uint8_t*>(self);
        void* vtbl;
        if (!SafeReadPtr(s, &vtbl)) return;
        const char* friendly = FriendlyForVtable(vtbl);
        if (!friendly) return;

        void* sel = nullptr;
        SafeReadPtr(s + 0x128, &sel);
        if (!sel) return;                  // no highlighted item (inactive/background)

        // DIAGNOSTIC: on a stable selection, log numeric fields that change, so a
        // slider value / toggle state / binding can be pinned to an offset.
        if (g_verboseDump) {
            static void* wc = nullptr; static uint8_t snap[0xC00];
            uint8_t cur[0xC00];
            if (SafeReadBytes(cur, sel, sizeof(cur))) {
                if (sel != wc) { wc = sel; memcpy(snap, cur, sizeof(snap)); }
                else {
                    for (uint32_t off = 0x20; off + 4 <= sizeof(cur); off += 4) {
                        if (memcmp(cur + off, snap + off, 4) == 0) continue;
                        if (off == 0x38) continue;                  // known focus-glow animation
                        uint32_t ou, nu; memcpy(&ou, snap + off, 4); memcpy(&nu, cur + off, 4);
                        float of, nf;   memcpy(&of, snap + off, 4); memcpy(&nf, cur + off, 4);
                        if ((nf >= 0.0f && nf <= 1.0001f) || nu <= 400)
                            Log::Info("[VAL-CHG] off=0x%X  u:%u->%u  f:%.3f->%.3f", off, ou, nu, of, nf);
                    }
                    memcpy(snap, cur, sizeof(snap));
                }
            }
        }

        ScrState* st = GetScrState(self);
        if (sel == st->lastSel) return;    // this screen's selection didn't change
        st->lastSel = sel;

        // Item label, in order of fidelity:
        char label[200]; label[0] = 0;

        // 0. Control-binding rows: the action name is a sibling label; pair it
        //    with the bound key -> "Special, Q".
        if (ClassIs(sel, "RemappableButtonComponent")) ResolveControlBinding(self, sel, label, sizeof(label));

        // 1. The EXACT on-screen text (works for the vast majority of labels).
        if (!label[0]) ReadDisplayedText(sel, label, sizeof(label));

        // 2. An inline HelpTextId on the component (PlayGame, Quit, VSync, Hell
        //    Mode, ...) resolved to its real wording via the game's table.
        char helpId[128]; helpId[0] = 0;
        if (SafeReadBytes(helpId, reinterpret_cast<uint8_t*>(sel) + 0x410, sizeof(helpId) - 1)) {
            helpId[sizeof(helpId) - 1] = 0;
            if (!ValidHelpId(helpId)) helpId[0] = 0;
        }
        if (!label[0] && helpId[0]) {
            const char* disp = HelpText::Lookup(helpId);
            if (disp && disp[0]) strncpy_s(label, sizeof(label), disp, _TRUNCATE);
        }

        // 3. Fancy labels (God Mode, ...) persist no plain text and no inline id;
        //    reconstruct the id from the owning screen class + component name.
        if (!label[0]) ResolveByScreenAndName(sel, label, sizeof(label));

        // 4. Save/profile slots carry a distinct per-slot key at +0x958.
        if (!label[0]) ResolveProfileSlot(sel, label, sizeof(label));

        // 5. Last resorts: de-camelCase the inline id, then the component name.
        if (!label[0] && helpId[0]) FriendlyLabel(helpId, label, sizeof(label));
        if (!label[0]) {
            char nm[80];
            if (SafeReadBytes(nm, reinterpret_cast<uint8_t*>(sel) + 0x90, sizeof(nm) - 1)) {
                nm[sizeof(nm) - 1] = 0;
                if (ValidName(nm)) NameToLabel(nm, label, sizeof(label));
            }
        }

        // Exact slider values / toggle states aren't reliably stored on the
        // component, so at least announce the control TYPE so the player knows
        // how to interact: sliders are adjusted (left/right), buttons are pressed.
        if (label[0]) {
            const char* type = nullptr;
            if (ClassIs(sel, "GUIComponentSlider")) type = "slider";
            else if (friendly && strcmp(friendly, "Settings") == 0 && ClassIs(sel, "GUIComponentButton")) type = "button";
            if (type) { char buf[240]; snprintf(buf, sizeof(buf), "%s, %s", label, type); strncpy_s(label, sizeof(label), buf, _TRUNCATE); }
        }

        if (g_verboseDump) {
            char dscrape[200] = {}; ReadDisplayedText(sel, dscrape, sizeof(dscrape));
            void* dvt = nullptr; char dcn[64] = "?"; if (SafeReadPtr(sel, &dvt)) ClassNameOfVtable(dvt, dcn, sizeof(dcn));
            Log::Info("[MENU-DIAG] cls=%s scrape=\"%s\" -> \"%s\"", dcn, dscrape, label);
            DumpObject(sel, 0, friendly);
        }

        // Log (not speak) when the focused menu changes — speech is just the item.
        static void* s_active = nullptr;
        bool firstFrame = (self != s_active);
        if (firstFrame) {
            s_active = self;
            Log::Info("[ENGINE-MENU] menu active: %s", friendly);
            if (g_verboseDump) DumpScreenComponents(self);
        }

        // On a dialog's first frame, lead with its prompt text, then the button.
        char say[400];
        if (firstFrame && IsDialogVtable(vtbl)) {
            char msg[260];
            if (ReadDialogMessage(self, msg, sizeof(msg)) && _stricmp(msg, label) != 0) {
                Log::Info("[ENGINE-MENU] dialog message: \"%s\"", msg);
                if (label[0]) snprintf(say, sizeof(say), "%s. %s", msg, label);
                else          strncpy_s(say, sizeof(say), msg, _TRUNCATE);
            } else strncpy_s(say, sizeof(say), label, _TRUNCATE);
        } else strncpy_s(say, sizeof(say), label, _TRUNCATE);

        if (say[0]) SpeakLabel(say);
        else        Log::Info("[ENGINE-MENU] %s: unreadable sel=%p", friendly, sel);
    } __except (EXCEPTION_EXECUTE_HANDLER) {}
}

// ---- Hook plumbing: dedup'd Update targets, shared detour via a thunk pool ----
typedef void (*UpdateFn)(void*, float);
static void*    g_updTarget[48] = {};
static UpdateFn g_updOrig[48]   = {};
static int      g_updCount      = 0;

static void SharedUpd(int idx, void* self, float dt)
{
    OnAnyMenuUpdate(self);
    if (g_updOrig[idx]) g_updOrig[idx](self, dt);
}
#define UPDN(n) static void Upd##n(void* s, float dt) { SharedUpd(n, s, dt); }
UPDN(0)  UPDN(1)  UPDN(2)  UPDN(3)  UPDN(4)  UPDN(5)  UPDN(6)  UPDN(7)
UPDN(8)  UPDN(9)  UPDN(10) UPDN(11) UPDN(12) UPDN(13) UPDN(14) UPDN(15)
UPDN(16) UPDN(17) UPDN(18) UPDN(19) UPDN(20) UPDN(21) UPDN(22) UPDN(23)
UPDN(24) UPDN(25) UPDN(26) UPDN(27) UPDN(28) UPDN(29) UPDN(30) UPDN(31)
static UpdateFn g_updDetour[32] = {
    Upd0, Upd1, Upd2, Upd3, Upd4, Upd5, Upd6, Upd7,
    Upd8, Upd9, Upd10, Upd11, Upd12, Upd13, Upd14, Upd15,
    Upd16, Upd17, Upd18, Upd19, Upd20, Upd21, Upd22, Upd23,
    Upd24, Upd25, Upd26, Upd27, Upd28, Upd29, Upd30, Upd31,
};

} // namespace

namespace EngineMenu {

int Init()
{
    HMODULE h = GetModuleHandleW(L"EngineWin64s.dll");
    if (!h) { Log::Error("[ENGINE-MENU] EngineWin64s.dll not loaded"); return 0; }
    g_base = reinterpret_cast<uint8_t*>(h);
    if (!GetSection(h, ".text", g_text) || !GetSection(h, ".rdata", g_rdata) || !GetSection(h, ".data", g_data)) {
        Log::Error("[ENGINE-MENU] failed to read engine PE sections"); return 0;
    }

    // Resolve each menu class vtable and collect the unique Update (slot 3)
    // addresses to hook (several classes share the base implementation).
    for (int i = 0; i < kMenuTotal; i++) {
        void* vt = ResolveVtable(kMenus[i].cls);
        if (!vt) { Log::Warn("[ENGINE-MENU] %s NOT resolved", kMenus[i].cls); continue; }
        if (g_menuCount < 48) g_menu[g_menuCount++] = { kMenus[i].cls, kMenus[i].friendly, vt, strstr(kMenus[i].cls, "Dialog") != nullptr };

        void* upd = reinterpret_cast<void**>(vt)[3];   // slot 3 = Update(this, float)
        if (!upd) continue;
        bool dup = false;
        for (int j = 0; j < g_updCount; j++) if (g_updTarget[j] == upd) { dup = true; break; }
        if (!dup && g_updCount < 32) g_updTarget[g_updCount++] = upd;
    }
    Log::Info("[ENGINE-MENU] resolved %d/%d menu classes, %d unique Update targets",
              g_menuCount, kMenuTotal, g_updCount);

    // Install the hooks (MinHook already initialized by LuaStateCapture).
    int hooked = 0;
    for (int i = 0; i < g_updCount; i++) {
        if (MH_CreateHook(g_updTarget[i], reinterpret_cast<void*>(g_updDetour[i]),
                          reinterpret_cast<void**>(&g_updOrig[i])) == MH_OK &&
            MH_EnableHook(g_updTarget[i]) == MH_OK) {
            hooked++;
        } else {
            Log::Warn("[ENGINE-MENU] hook %d @ %p failed", i, g_updTarget[i]);
        }
    }
    Log::Info("[ENGINE-MENU] installed %d/%d menu Update hooks", hooked, g_updCount);
    return g_menuCount;
}

void* GetVtable(const char* className)
{
    for (int i = 0; i < g_menuCount; i++) if (strcmp(g_menu[i].cls, className) == 0) return g_menu[i].vtable;
    return nullptr;
}

}
