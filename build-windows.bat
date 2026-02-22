@echo off
setlocal

:: x86 or x64
set "BUILD_ARCH=%~1"
if "%BUILD_ARCH%"=="" (
    echo Error: Please specify architecture: x86 or x64
    exit /b 1
)

:: config
set "LUAJIT_ROOT=%~dp0"
set "ARTIFACTS_DIR=%LUAJIT_ROOT%luajit-build"

:: define output directories
set "DIR_BIN=%ARTIFACTS_DIR%\luajit-bin\%BUILD_ARCH%"
set "DIR_LIB=%ARTIFACTS_DIR%\luajit\%BUILD_ARCH%"
set "DIR_INC=%ARTIFACTS_DIR%\luajit-include"

:: create output directories
if not exist "%DIR_BIN%" mkdir "%DIR_BIN%"
if not exist "%DIR_LIB%" mkdir "%DIR_LIB%"
if not exist "%DIR_INC%" mkdir "%DIR_INC%"

pushd "%LUAJIT_ROOT%\src"

echo ########## Building for Windows %BUILD_ARCH% ##########

:: patch msvcbuild.bat to skip cleanup of minilua.exe and buildvm.exe
powershell -Command "(Get-Content msvcbuild.bat) -replace '@del \*\.obj \*\.manifest minilua\.exe buildvm\.exe', ':: Skipped cleanup to keep tools' | Set-Content msvcbuild.bat"

:: build
if "%BUILD_ARCH%"=="x64" (
    call msvcbuild.bat gc64
) else (
    call msvcbuild.bat
)

if %errorlevel% neq 0 (
    echo Error: Build failed for %BUILD_ARCH%.
    popd
    exit /b %errorlevel%
)

:: 1. Copy Binaries (Executable + DLL)
echo Copying Binaries...
copy /Y luajit.exe "%DIR_BIN%\"
copy /Y lua51.dll "%DIR_BIN%\"

:: 2. Copy Link Libs (LIB)
echo Copying Libraries...
copy /Y lua51.lib "%DIR_LIB%\"

:: 3. Copy Tools (Minilua & Buildvm)
echo Copying Tools...

if exist minilua.exe (
    copy /Y minilua.exe "%ARTIFACTS_DIR%\minilua-%BUILD_ARCH%.exe"
    echo minilua.exe copied.
) else (
    echo Error: minilua.exe not found even after patching msvcbuild.bat!
)

if exist buildvm.exe (
    copy /Y buildvm.exe "%ARTIFACTS_DIR%\buildvm-%BUILD_ARCH%.exe"
    echo buildvm.exe copied.
) else (
    echo Error: buildvm.exe not found even after patching msvcbuild.bat!
)

:: 4. Copy Headers
if not exist "%DIR_INC%\lua.h" (
    echo Copying Headers...
    copy /Y lua.h "%DIR_INC%\"
    copy /Y lualib.h "%DIR_INC%\"
    copy /Y lauxlib.h "%DIR_INC%\"
    copy /Y luaconf.h "%DIR_INC%\"
    copy /Y luajit.h "%DIR_INC%\"
    copy /Y lua.hpp "%DIR_INC%\"
)

:: Cleanup
if exist minilua.exe del minilua.exe
if exist buildvm.exe del buildvm.exe
if exist *.obj del *.obj
if exist *.manifest del *.manifest
if exist host\buildvm_arch.h del host\buildvm_arch.h
if exist lj_bcdef.h del lj_bcdef.h
if exist lj_ffdef.h del lj_ffdef.h
if exist lj_libdef.h del lj_libdef.h
if exist lj_recdef.h del lj_recdef.h
if exist lj_folddef.h del lj_folddef.h

popd

echo ########## Build for %BUILD_ARCH% Completed ##########