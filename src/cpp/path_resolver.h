#pragma once
#include <string>

struct SpeechDllPaths {
    std::wstring tolkDll;
    std::wstring nvdaDll;
    std::wstring saapiDll;
    bool tolkFound   = false;
    bool nvdaFound   = false;
    bool saapiFound  = false;
};

namespace PathResolver {

bool Init();

const std::wstring& GetExecutableDir();
const std::wstring& GetGameRootDir();
const std::wstring& GetModsDir();
const std::wstring& GetInjectedDllDir();

SpeechDllPaths FindSpeechDlls();

}
