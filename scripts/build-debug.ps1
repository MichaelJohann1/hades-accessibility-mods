# Build the accessibility DLL WITH debug keys (F1-F12 / number keys / ]), gated by chaos.dat.
# Self-contained: if chaos.dat is missing it creates one here, then builds with
# ENABLE_DEBUG_KEYS. Debug keys turn on simply when chaos.dat sits next to the DLL
# (no hash check) — delete chaos.dat to turn them off.
# Output: x64\Release\xinput1_4.dll + src\cpp\chaos.dat — deploy BOTH together.
$datPath = Join-Path $PSScriptRoot "..\src\cpp\chaos.dat"

if (-not (Test-Path $datPath)) {
    Write-Host "Creating chaos.dat (debug-key gate file)..."
    Set-Content -Path $datPath -Value "Hades accessibility debug-key gate file." -Encoding ASCII
}

Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Community" -DevCmdArguments "-arch=amd64" -SkipAutomaticLocation | Out-Null
msbuild "$PSScriptRoot\..\src\cpp\hades.vcxproj" /p:Configuration=Release /p:Platform=x64 /p:ExtraDefines=ENABLE_DEBUG_KEYS /t:Build /verbosity:minimal

Write-Host ""
Write-Host "Debug build complete. Deploy BOTH to the game's x64\ folder (matched pair):" -ForegroundColor Yellow
Write-Host "  - x64\Release\xinput1_4.dll"
Write-Host "  - src\cpp\chaos.dat"
