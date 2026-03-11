/*
 * Hades Native Accessibility Layer
 * DLL proxy (xinput1_4.dll) that hooks Lua 5.2 to provide screen reader support.
 *
 * Original proxy skeleton by Hamada Trichine.
 * Accessibility layer by the Hades Accessibility Project.
 */

#include <Windows.h>
#include <cstdio>
#include "xinput_proxy.h"

// Forward declaration — implemented in accessibility_core.cpp
namespace AccessibilityCore {
    DWORD WINAPI WorkerThread(LPVOID lpParam);
    void Shutdown();
}

static HMODULE g_hModule = nullptr;
static HANDLE  g_workerThread = nullptr;
static HANDLE  g_shutdownEvent = nullptr;

HMODULE GetInjectedModule()
{
    return g_hModule;
}

HANDLE GetShutdownEvent()
{
    return g_shutdownEvent;
}

static bool Init(HMODULE hModule)
{
    g_hModule = hModule;
    DisableThreadLibraryCalls(hModule);

    if (!XInputProxy::Init())
        return false;

    // No console window — all logging goes to hades_accessibility.log via Logger

    // Create shutdown event (manual reset, initially non-signaled)
    g_shutdownEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);

    // Launch worker thread for accessibility initialization
    g_workerThread = CreateThread(nullptr, 0, AccessibilityCore::WorkerThread, nullptr, 0, nullptr);

    return true;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID)
{
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        return Init(hModule) ? TRUE : FALSE;
    }

    if (ul_reason_for_call == DLL_PROCESS_DETACH) {
        // Signal worker thread to stop
        if (g_shutdownEvent) {
            SetEvent(g_shutdownEvent);
        }

        // Wait for worker thread to finish (up to 3 seconds)
        if (g_workerThread) {
            WaitForSingleObject(g_workerThread, 3000);
            CloseHandle(g_workerThread);
            g_workerThread = nullptr;
        }

        AccessibilityCore::Shutdown();
        XInputProxy::Shutdown();

        if (g_shutdownEvent) {
            CloseHandle(g_shutdownEvent);
            g_shutdownEvent = nullptr;
        }

    }

    return TRUE;
}
