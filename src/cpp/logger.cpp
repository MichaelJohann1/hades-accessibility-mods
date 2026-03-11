#include "logger.h"
#include <Windows.h>
#include <cstdarg>
#include <cstdio>
#include <mutex>

static FILE*       s_logFile  = nullptr;
static std::mutex  s_mutex;
static Log::Level  s_minLevel = Log::Level::Debug;

static const char* LevelStr(Log::Level level)
{
    switch (level) {
        case Log::Level::Debug: return "DEBUG";
        case Log::Level::Info:  return "INFO ";
        case Log::Level::Warn:  return "WARN ";
        case Log::Level::Error: return "ERROR";
    }
    return "?????";
}

static void WriteLog(Log::Level level, const char* fmt, va_list args)
{
    if (level < s_minLevel) return;

    SYSTEMTIME st;
    GetLocalTime(&st);

    std::lock_guard<std::mutex> lock(s_mutex);

    char prefix[64];
    snprintf(prefix, sizeof(prefix), "%04d %02d:%02d:%02d.%01d %s ",
             st.wYear, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds / 100,
             LevelStr(level));

    // Write to stdout (debug console)
    fputs(prefix, stdout);
    vfprintf(stdout, fmt, args);
    fputc('\n', stdout);
    fflush(stdout);

    // Write to log file
    if (s_logFile) {
        fputs(prefix, s_logFile);
        vfprintf(s_logFile, fmt, args);
        fputc('\n', s_logFile);
        fflush(s_logFile);
    }
}

namespace Log {

void Init()
{
    // Build logs/ directory path next to the executable
    wchar_t exeDir[MAX_PATH];
    GetModuleFileNameW(nullptr, exeDir, MAX_PATH);

    wchar_t* lastSlash = wcsrchr(exeDir, L'\\');
    if (!lastSlash) return;
    *(lastSlash + 1) = L'\0';  // null-terminate to get directory path

    // Create logs subdirectory (no-op if it already exists)
    wchar_t logsDir[MAX_PATH];
    swprintf_s(logsDir, MAX_PATH, L"%slogs", exeDir);
    CreateDirectoryW(logsDir, nullptr);

    // Generate timestamped filename: hades_accessibility_YYYY-MM-DD_HH-MM-SS.log
    SYSTEMTIME st;
    GetLocalTime(&st);

    wchar_t logPath[MAX_PATH];
    swprintf_s(logPath, MAX_PATH,
        L"%slogs\\hades_accessibility_%04d-%02d-%02d_%02d-%02d-%02d.log",
        exeDir, st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

    _wfopen_s(&s_logFile, logPath, L"w");
}

void Shutdown()
{
    std::lock_guard<std::mutex> lock(s_mutex);
    if (s_logFile) {
        fclose(s_logFile);
        s_logFile = nullptr;
    }
}

void SetMinLevel(Level level) { s_minLevel = level; }

void Debug(const char* fmt, ...) { va_list a; va_start(a, fmt); WriteLog(Level::Debug, fmt, a); va_end(a); }
void Info(const char* fmt, ...)  { va_list a; va_start(a, fmt); WriteLog(Level::Info, fmt, a);  va_end(a); }
void Warn(const char* fmt, ...)  { va_list a; va_start(a, fmt); WriteLog(Level::Warn, fmt, a);  va_end(a); }
void Error(const char* fmt, ...) { va_list a; va_start(a, fmt); WriteLog(Level::Error, fmt, a); va_end(a); }

}
