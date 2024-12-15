@echo off

set root_dir=%~dp0
set tools_dir=%~dp0.cache\tools\
set cppfront=%tools_dir%\cppfront.exe
set cppfront_include_dir=%~dp0.cache\repos\cppfront\include
set cpp2b_dist=%~dp0dist\debug\cpp2b
set modules_dir=%~dp0.cache\modules

if not exist .cache\cpp2 ( mkdir .cache\cpp2 )
if not exist .cache\cpp2\source ( mkdir .cache\cpp2\source )
if not exist .cache\repos ( mkdir .cache\repos )
if not exist %modules_dir% ( mkdir %modules_dir% )
if not exist .cache\tools ( mkdir .cache\tools )
if not exist dist ( mkdir dist )
if not exist dist\debug ( mkdir dist\debug )

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

if exist .cache\repos\cppfront\ (
    @rem TODO - report which cppfront version is being used
) else (
    git clone --quiet --branch=v0.8.0 --depth=1 https://github.com/hsutter/cppfront.git .cache/repos/cppfront 
)

call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" /no_logo

if not exist "%modules_dir%\std.ifc" (
    echo Compiling std module...
    pushd %modules_dir%
    cl /D"_CRT_SECURE_NO_WARNINGS=1" /std:c++latest /EHsc /nologo /W4 /MDd /c "%vs_tools_dir%\modules\std.ixx"
    popd
)

if not exist "%modules_dir%\std.compat.ifc" (
    echo Compiling std.compat module...
    pushd %modules_dir%
    cl /std:c++latest /EHsc /nologo /W4 /MDd /c "%vs_tools_dir%\modules\std.compat.ixx"
    popd
)

if not exist "%root_dir%.cache\cpp2\source\_build" ( mkdir "%root_dir%.cache\cpp2\source\_build" )
echo INFO: compiling cpp2b module...
if exist "%root_dir%.cache\cpp2\source\_build\cpp2b.ixx" (
    del "%root_dir%.cache\cpp2\source\_build\cpp2b.ixx" /F
)

setlocal enableextensions disabledelayedexpansion

set "search=@CPP2B_PROJECT_ROOT@"
set "replace=%root_dir%"

set "inputFile=%root_dir%share\cpp2b.cppm.tpl"
set "outputFile=%root_dir%.cache\cpp2\source\_build\cpp2b.ixx"

for /f "delims=" %%i in ('type "%inputFile%"') do (
    set "line=%%i"
    setlocal enabledelayedexpansion
    >>"%outputFile%" echo(!line:%search%=%replace%!
    endlocal
)
endlocal

@REM attrib +r "%root_dir%.cache\cpp2\source\_build\cpp2b.ixx"

pushd %modules_dir%
cl /nologo ^
    /std:c++latest /W4 /MDd /EHsc ^
    /reference "%modules_dir%\std.ifc" ^
    /reference "%modules_dir%\std.compat.ifc" ^
    /c "%root_dir%.cache\cpp2\source\_build\cpp2b.ixx"
popd

if %ERRORLEVEL% neq 0 (
    echo ERROR: failed to compile cpp2b module
    exit %ERRORLEVEL%
)

echo INFO: compiling dylib module...
pushd %modules_dir%
cl /nologo ^
    /std:c++latest /W4 /MDd /EHsc ^
    /reference "%modules_dir%\std.ifc" ^
    /reference "%modules_dir%\std.compat.ifc" ^
    /c /interface /TP "%root_dir%src\dylib.cppm" > NUL
popd

if %ERRORLEVEL% neq 0 (
    echo ERROR: failed to compile dylib module
    exit %ERRORLEVEL%
)

echo INFO: compiling xxh3 module...
pushd %modules_dir%
cl /nologo ^
    /std:c++latest /W4 /MDd /EHsc ^
    /reference "%modules_dir%\std.ifc" ^
    /reference "%modules_dir%\std.compat.ifc" ^
    /c /interface /TP "%root_dir%src\xxh3.cppm" > NUL
popd

if %ERRORLEVEL% neq 0 (
    echo ERROR: failed to compile xxh3 module
    exit %ERRORLEVEL%
)

echo INFO: compiling nlohmann.json module...
pushd %modules_dir%
cl /nologo ^
    /std:c++latest /W4 /MDd /EHsc ^
    /reference "%modules_dir%\std.ifc" ^
    /reference "%modules_dir%\std.compat.ifc" ^
    /c /interface /TP "%root_dir%src\nlohmann.json.cppm" > NUL
popd

if %ERRORLEVEL% neq 0 (
    echo ERROR: failed to compile nlohmann.json module
    exit %ERRORLEVEL%
)

if not exist %cppfront% (
    pushd .cache\repos\cppfront\source
    echo INFO: compiling cppfront...
    cl /nologo /std:c++latest /EHsc cppfront.cpp
    xcopy cppfront.exe %tools_dir% /Y /Q
    popd
)

if not exist "%root_dir%.cache/cpp2/source/src" ( mkdir "%root_dir%.cache/cpp2/source/src" )

%cppfront% src/main.cpp2 -pure -import-std -l -format-colon-errors -o "%root_dir%.cache/cpp2/source/src/main.cpp"

if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%


cl /nologo "%root_dir%.cache/cpp2/source/src/main.cpp" ^
    /diagnostics:column /permissive- ^
    /reference "%modules_dir%\std.ifc" "%modules_dir%\std.obj" ^
    /reference "%modules_dir%\std.compat.ifc" "%modules_dir%\std.compat.obj" ^
    /reference "%modules_dir%\dylib.ifc" "%modules_dir%\dylib.obj" ^
    /reference "%modules_dir%\nlohmann.json.ifc" "%modules_dir%\nlohmann.json.obj" ^
    /reference "%modules_dir%\xxh3.ifc" "%modules_dir%\xxh3.obj" ^
    /reference "%modules_dir%\cpp2b.ifc" "%modules_dir%\cpp2b.obj" ^
    /std:c++latest /W4 /MDd /EHsc ^
    /DEBUG:FULL /Zi /FC ^
    -I"%cppfront_include_dir%" ^
    /Fe"%cpp2b_dist%" ^
    /Fd"%cpp2b_dist%.pdb"

if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%

echo %cpp2b_dist%.exe
