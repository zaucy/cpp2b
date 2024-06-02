@echo off

set vswhere="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%i in (`%vswhere% -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
	set vs_install_dir=%%i
)

if exist "%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
	set /p vs_tools_version=<"%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
)

if "%vs_tools_version%"=="" (
	echo ERROR: cannot find VC tools installed on your system
	exit 1
)

set vs_tools_dir=%vs_install_dir%\VC\Tools\MSVC\%vs_tools_version%

call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" /no_logo

for /f "tokens=1,* delims= " %%a in ("%*") do set FORWARD_ARGS=%%b

%1 %FORWARD_ARGS%
