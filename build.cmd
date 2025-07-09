@echo off
setlocal enabledelayedexpansion

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
    set /p Version=<"%vs_install_dir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
    set LatestVCToolsVersion=!Version: =!
)


set "msvc_root=%vs_install_dir%\VC\Tools\MSVC"
set "chosen_minor=0"
set "chosen_patch=0"

:: Iterate over all MSVC versions installed
for /f "delims=" %%v in ('dir /b /ad "%msvc_root%"') do (
    call :check_version "%%v"
)

if not defined chosen_version (
    echo ERROR: MSVC version less than or equal to 14.43 not found
    exit 1
)

echo INFO: using chosen version !chosen_version!

call "%vs_install_dir%\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64 -no_logo -vcvars_ver=!chosen_version!

if "%VCToolsInstallDir%"=="" (
    echo ERROR: missing VCToolsInstallDir after running vsdevcmd.bat
    exit 1
)

echo INFO: using vs tools %VCToolsVersion%

set vs_tools_dir=%VCToolsInstallDir%

if exist .cache\repos\cppfront\ (
    @rem TODO - report which cppfront version is being used
) else (
    git clone --quiet --branch=v0.8.1 --depth=1 https://github.com/hsutter/cppfront.git .cache/repos/cppfront 
)

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

set "inputFile=%root_dir%share\cpp2b\cpp2b.cppm.tpl"
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

if %ERRORLEVEL% neq 0 (
    echo ERROR: failed to compile cppfront
    exit %ERRORLEVEL%
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
    /reference "%modules_dir%\cpp2b.ifc" "%modules_dir%\cpp2b.obj" ^
    /std:c++latest /W4 /MDd /EHsc ^
    /DEBUG:FULL /Zi /FC ^
    -I"%cppfront_include_dir%" ^
    /Fe"%cpp2b_dist%" ^
    /Fd"%cpp2b_dist%.pdb"

if %ERRORLEVEL% neq 0 exit %ERRORLEVEL%

echo %cpp2b_dist%.exe

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
    if !m! LEQ 44 (
        if not defined chosen_version (
            set "chosen_version=!ver!"
            set "chosen_minor=!m!"
            set "chosen_patch=!p!"
        ) else (
            if !m! GTR !chosen_minor! (
                set "chosen_version=!ver!"
                set "chosen_minor=!m!"
                set "chosen_patch=!p!"
            ) else if !m! EQU !chosen_minor! if !p! GTR !chosen_patch! (
                set "chosen_version=!ver!"
                set "chosen_minor=!m!"
                set "chosen_patch=!p!"
            )
        )
    )
)
goto :eof
