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

set "msvc_root=%vs_install_dir%\VC\Tools\MSVC"
set "chosen_minor=0"
set "chosen_patch=0"

for /f "delims=" %%v in ('dir /b /ad "%msvc_root%"') do (
    call :check_version "%%v"
)

if not defined ChosenMSVC (
    set "ChosenMSVC=%LatestVCToolsVersion%"
)

:: Call vsdevcmd with selected version
call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64 -no_logo -vcvars_ver=%ChosenMSVC%

for /f "tokens=1,* delims= " %%a in ("%*") do set FORWARD_ARGS=%%b

%1 %FORWARD_ARGS%

:: -------------------------------
:: Subroutine: check_version
:: %1 = version string like 14.43.32706
:: -------------------------------
:check_version
set "ver=%~1"
for /f "tokens=1-3 delims=." %%a in ("!ver!") do (
    set "major=%%a"
    set "minor=%%b"
    set "patch=%%c"
)

if "%major%"=="14" (
    set /a m=!minor!
    set /a p=!patch!
    if !m! LEQ 43 (
        if not defined ChosenMSVC (
            set "ChosenMSVC=!ver!"
            set "chosen_minor=!m!"
            set "chosen_patch=!p!"
        ) else (
            if !m! GTR !chosen_minor! (
                set "ChosenMSVC=!ver!"
                set "chosen_minor=!m!"
                set "chosen_patch=!p!"
            ) else if !m! EQU !chosen_minor! if !p! GTR !chosen_patch! (
                set "ChosenMSVC=!ver!"
                set "chosen_minor=!m!"
                set "chosen_patch=!p!"
            )
        )
    )
)
goto :eof
