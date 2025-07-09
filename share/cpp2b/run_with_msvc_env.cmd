@echo off

set vswhere="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%i in (`%vswhere% -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set vs_install_dir=%%i
)

call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64 -no_logo -vcvars_ver=14.42

for /f "tokens=1,* delims= " %%a in ("%*") do set FORWARD_ARGS=%%b

%1 %FORWARD_ARGS%
