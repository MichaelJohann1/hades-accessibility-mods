#pragma once
#include <Windows.h>

namespace AccessibilityCore {

DWORD WINAPI WorkerThread(LPVOID lpParam);
void Shutdown();

}
