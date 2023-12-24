@echo off

set cppfront=%~dp0.cache\tools\cppfront.exe
set cppfront_include_dir=%~dp0.cache\repos\cppfront\include
set cpp2b_dist=%~dp0dist\debug\cpp2b
set modules_dir=%~dp0.cache\modules

if not exist .cache\repos ( mkdir .cache\repos )
if not exist %modules_dir% ( mkdir %modules_dir% )
if not exist .cache\tools ( mkdir .cache\tools )
if not exist dist ( mkdir dist )
if not exist dist\debug ( mkdir dist\debug )

set vswhere="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%i in (`vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
	set vs_install_dir=%%i
)

if exist "%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
	set /p vs_tools_version=<"%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
)

if "%vs_tools_version%"=="" (
	echo Cannot find VC tools installed on your system
	exit 1
)

set vs_tools_dir=%vs_install_dir%\VC\Tools\MSVC\%vs_tools_version%

if exist .cache\repos\cppfront\ (
	@rem TODO - report which cppfront version is being used
) else (
	git clone https://github.com/hsutter/cppfront.git .cache/repos/cppfront --quiet
)

call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" /no_logo

if not exist "%modules_dir%\std.ifc" (
	echo Compiling std module...
	pushd %modules_dir%
	cl /std:c++latest /EHsc /nologo /W4 /MTd /c "%vs_tools_dir%\modules\std.ixx"
	popd
)

if not exist "%modules_dir%\std.compat.ifc" (
	echo Compiling std.compat module...
	pushd %modules_dir%
	cl /std:c++latest /EHsc /nologo /W4 /MTd /c "%vs_tools_dir%\modules\std.compat.ixx"
	popd
)

if not exist %cppfront% (
	pushd .cache\repos\cppfront\source
	echo Compiling cppfront...
	cl /nologo /std:c++latest /EHsc cppfront.cpp
	xcopy /y /q cppfront.exe %cppfront%
	popd
)

%cppfront% src/main.cpp2 -pure -import-std -add-source-info -format-colon-errors

if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%

cl /nologo src/main.cpp ^
  /diagnostics:caret /permissive- ^
  /reference "%modules_dir%\std.ifc" "%modules_dir%\std.obj" ^
  /reference "%modules_dir%\std.compat.ifc" "%modules_dir%\std.compat.obj" ^
  /std:c++latest /W4 /MTd /EHsc ^
  -I"%cppfront_include_dir%" ^
  /Fe"%cpp2b_dist%"

if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%

echo %cpp2b_dist%.exe
