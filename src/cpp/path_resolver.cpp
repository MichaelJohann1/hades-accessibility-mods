#include "path_resolver.h"
#include "logger.h"
#include <Windows.h>

// Forward declaration from dllmain.cpp
HMODULE GetInjectedModule();

static std::wstring s_exeDir;
static std::wstring s_dllDir;
static std::wstring s_gameRoot;
static std::wstring s_modsDir;

static std::wstring GetDirectoryFromPath(const wchar_t* fullPath)
{
    std::wstring path(fullPath);
    size_t pos = path.find_last_of(L'\\');
    if (pos != std::wstring::npos)
        return path.substr(0, pos);
    return path;
}

static std::wstring GetParentDirectory(const std::wstring& dir)
{
    size_t pos = dir.find_last_of(L'\\');
    if (pos != std::wstring::npos)
        return dir.substr(0, pos);
    return dir;
}

static bool DirectoryExists(const std::wstring& path)
{
    DWORD attr = GetFileAttributesW(path.c_str());
    return (attr != INVALID_FILE_ATTRIBUTES) && (attr & FILE_ATTRIBUTE_DIRECTORY);
}

static bool FileExists(const std::wstring& path)
{
    DWORD attr = GetFileAttributesW(path.c_str());
    return (attr != INVALID_FILE_ATTRIBUTES) && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

static bool SearchFileRecursive(const std::wstring& dir, const wchar_t* filename,
                                 std::wstring& outPath, int maxDepth)
{
    if (maxDepth <= 0) return false;

    // Check this directory
    std::wstring candidate = dir + L"\\" + filename;
    if (FileExists(candidate)) {
        outPath = candidate;
        return true;
    }

    // Search subdirectories
    WIN32_FIND_DATAW fd;
    std::wstring searchPattern = dir + L"\\*";
    HANDLE hFind = FindFirstFileW(searchPattern.c_str(), &fd);
    if (hFind == INVALID_HANDLE_VALUE) return false;

    bool found = false;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0) continue;

        std::wstring subdir = dir + L"\\" + fd.cFileName;
        if (SearchFileRecursive(subdir, filename, outPath, maxDepth - 1)) {
            found = true;
            break;
        }
    } while (FindNextFileW(hFind, &fd));

    FindClose(hFind);
    return found;
}

namespace PathResolver {

bool Init()
{
    // Get executable directory
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    s_exeDir = GetDirectoryFromPath(exePath);
    Log::Info("Executable dir: %ls", s_exeDir.c_str());

    // Get injected DLL directory
    wchar_t dllPath[MAX_PATH];
    GetModuleFileNameW(GetInjectedModule(), dllPath, MAX_PATH);
    s_dllDir = GetDirectoryFromPath(dllPath);
    Log::Info("Injected DLL dir: %ls", s_dllDir.c_str());

    // Game root is parent of exe dir (x64/ -> Hades/)
    s_gameRoot = GetParentDirectory(s_exeDir);
    Log::Info("Game root dir: %ls", s_gameRoot.c_str());

    // Look for Mods folder
    s_modsDir = s_gameRoot + L"\\Content\\Mods";
    if (DirectoryExists(s_modsDir)) {
        Log::Info("Mods dir found: %ls", s_modsDir.c_str());
    } else {
        // Try alternate locations
        std::wstring alt = s_gameRoot + L"\\Mods";
        if (DirectoryExists(alt)) {
            s_modsDir = alt;
            Log::Info("Mods dir found (alternate): %ls", s_modsDir.c_str());
        } else {
            Log::Warn("Mods directory not found");
            s_modsDir.clear();
        }
    }

    return true;
}

const std::wstring& GetExecutableDir()   { return s_exeDir; }
const std::wstring& GetGameRootDir()     { return s_gameRoot; }
const std::wstring& GetModsDir()         { return s_modsDir; }
const std::wstring& GetInjectedDllDir()  { return s_dllDir; }

SpeechDllPaths FindSpeechDlls()
{
    SpeechDllPaths paths;

    // Search order: exe dir, DLL dir, game root, then recursive from game root
    auto findDll = [](const wchar_t* name, std::wstring& outPath) -> bool {
        // 1. Executable directory
        std::wstring candidate = s_exeDir + L"\\" + name;
        if (FileExists(candidate)) { outPath = candidate; return true; }

        // 2. Injected DLL directory (if different)
        if (s_dllDir != s_exeDir) {
            candidate = s_dllDir + L"\\" + name;
            if (FileExists(candidate)) { outPath = candidate; return true; }
        }

        // 3. Game root directory
        candidate = s_gameRoot + L"\\" + name;
        if (FileExists(candidate)) { outPath = candidate; return true; }

        // 4. Recursive search from game root (max depth 3)
        if (SearchFileRecursive(s_gameRoot, name, outPath, 3))
            return true;

        return false;
    };

    paths.tolkFound  = findDll(L"Tolk.dll", paths.tolkDll);
    paths.nvdaFound  = findDll(L"nvdaControllerClient64.dll", paths.nvdaDll);
    paths.saapiFound = findDll(L"SAAPI64.dll", paths.saapiDll);

    if (paths.tolkFound)  Log::Info("Found Tolk.dll: %ls", paths.tolkDll.c_str());
    else                  Log::Warn("Tolk.dll not found");

    if (paths.nvdaFound)  Log::Info("Found nvdaControllerClient64.dll: %ls", paths.nvdaDll.c_str());
    else                  Log::Warn("nvdaControllerClient64.dll not found");

    if (paths.saapiFound) Log::Info("Found SAAPI64.dll: %ls", paths.saapiDll.c_str());
    else                  Log::Warn("SAAPI64.dll not found");

    return paths;
}

}
