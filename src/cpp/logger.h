#pragma once
#include <cstdio>

namespace Log {

enum class Level { Debug, Info, Warn, Error };

void Init();
void Shutdown();
void SetMinLevel(Level level);

void Debug(const char* fmt, ...);
void Info(const char* fmt, ...);
void Warn(const char* fmt, ...);
void Error(const char* fmt, ...);

}
