Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Community" -DevCmdArguments "-arch=amd64" -SkipAutomaticLocation | Out-Null
msbuild "$PSScriptRoot\..\src\cpp\hades.vcxproj" /p:Configuration=Release /p:Platform=x64 /t:Build /verbosity:minimal
