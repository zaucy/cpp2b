@echo off
setlocal enabledelayedexpansion

set vswhere="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%i in (`%vswhere% -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set vs_install_dir=%%i
)

if exist "%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
    set /p Version=<"%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
    set LatestVCToolsVersion=!Version: =!
)

:: Get list of installed MSVC versions, highest first
set "msvc_root=%vs_install_dir%\VC\Tools\MSVC"
set "ChosenMSVC="

for /f "delims=" %%v in ('dir /b /ad "%msvc_root%" ^| sort /R') do (
    set "ver=%%v"
    for /f "tokens=1,2 delims=." %%a in ("!ver!") do (
        set "major=%%a"
        set "minor=%%b"
    )
    rem Compare major.minor ≤ 14.43
    if !major! LSS 14 (
        set "ChosenMSVC=%%v"
        goto :found
    ) else if !major! EQU 14 if !minor! LEQ 43 (
        set "ChosenMSVC=%%v"
        goto :found
    )
)

echo ERROR: MSVC version ≤ 14.43 not found
exit 1

:found
:: Call vsdevcmd with selected version
call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64 -no_logo -vcvars_ver=%ChosenMSVC%

for /f "tokens=1,* delims= " %%a in ("%*") do set FORWARD_ARGS=%%b

%1 %FORWARD_ARGS%
