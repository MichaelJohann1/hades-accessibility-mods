#pragma once
#include <Windows.h>

namespace TolkLoader {

bool Init(const wchar_t* tolkDllPath);
void Shutdown();
bool IsAvailable();

void Load();
void Unload();
bool Output(const wchar_t* text, bool interrupt);
void Silence();
bool IsLoaded();
bool HasSpeech();
const wchar_t* DetectScreenReader();

}
