@echo off
REM ============================================================================
REM PS-Launcher (Rust) - Windows Build Script
REM ============================================================================
REM This script builds the Rust version of PS-Launcher with optimized settings
REM for minimal binary size and maximum performance.
REM
REM Prerequisites:
REM   - Rust toolchain installed (rustup.rs)
REM   - Windows 10/11 or Windows Server 2016+
REM
REM Usage:
REM   build.bat           - Build release version
REM   build.bat debug     - Build debug version
REM   build.bat clean     - Clean build artifacts
REM   build.bat test      - Run tests
REM   build.bat all       - Clean, build, and test
REM ============================================================================

setlocal EnableDelayedExpansion

REM Colors for output (if terminal supports it)
set "RESET=[0m"
set "GREEN=[32m"
set "YELLOW=[33m"
set "RED=[31m"
set "CYAN=[36m"

echo.
echo ============================================================================
echo PS-Launcher (Rust Edition) - Build Script
echo ============================================================================
echo.

REM Check if Rust is installed
where cargo >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo %RED%ERROR: Cargo not found!%RESET%
    echo.
    echo Please install Rust from: https://rustup.rs
    echo.
    exit /b 1
)

REM Get Rust version
for /f "tokens=2" %%i in ('cargo --version') do set RUST_VERSION=%%i
echo Rust toolchain detected: %RUST_VERSION%
echo.

REM Parse command line argument
set BUILD_TYPE=%1
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release

REM Handle different build types
if /i "%BUILD_TYPE%"=="release" goto BUILD_RELEASE
if /i "%BUILD_TYPE%"=="debug" goto BUILD_DEBUG
if /i "%BUILD_TYPE%"=="clean" goto CLEAN
if /i "%BUILD_TYPE%"=="test" goto TEST
if /i "%BUILD_TYPE%"=="all" goto BUILD_ALL
if /i "%BUILD_TYPE%"=="help" goto HELP

echo %RED%Unknown build type: %BUILD_TYPE%%RESET%
echo Run "build.bat help" for usage information
exit /b 1

:BUILD_RELEASE
echo %CYAN%Building RELEASE version (optimized for size)...%RESET%
echo.
cargo build --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo %RED%Build failed!%RESET%
    exit /b 1
)
echo.
echo %GREEN%Build successful!%RESET%
echo.
goto SHOW_INFO

:BUILD_DEBUG
echo %CYAN%Building DEBUG version...%RESET%
echo.
cargo build
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo %RED%Build failed!%RESET%
    exit /b 1
)
echo.
echo %GREEN%Build successful!%RESET%
echo.
goto SHOW_INFO

:CLEAN
echo %CYAN%Cleaning build artifacts...%RESET%
echo.
cargo clean
if %ERRORLEVEL% NEQ 0 (
    echo %RED%Clean failed!%RESET%
    exit /b 1
)
echo.
echo %GREEN%Clean complete!%RESET%
echo.
exit /b 0

:TEST
echo %CYAN%Running tests...%RESET%
echo.
cargo test
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo %RED%Tests failed!%RESET%
    exit /b 1
)
echo.
echo %GREEN%All tests passed!%RESET%
echo.
exit /b 0

:BUILD_ALL
echo %CYAN%Performing full build (clean + release + test)...%RESET%
echo.
call :CLEAN
if %ERRORLEVEL% NEQ 0 exit /b 1
call :BUILD_RELEASE
if %ERRORLEVEL% NEQ 0 exit /b 1
call :TEST
if %ERRORLEVEL% NEQ 0 exit /b 1
echo.
echo %GREEN%Full build complete!%RESET%
echo.
exit /b 0

:HELP
echo Usage: build.bat [option]
echo.
echo Options:
echo   release     Build optimized release version (default)
echo   debug       Build debug version with full debug info
echo   clean       Clean all build artifacts
echo   test        Run all unit tests
echo   all         Clean, build release, and run tests
echo   help        Show this help message
echo.
echo Examples:
echo   build.bat              - Build release version
echo   build.bat debug        - Build debug version
echo   build.bat clean        - Clean build files
echo   build.bat test         - Run tests
echo   build.bat all          - Full clean build with tests
echo.
exit /b 0

:SHOW_INFO
REM Determine which executable to show info for
if /i "%BUILD_TYPE%"=="release" (
    set "EXE_PATH=target\release\ps-launcher.exe"
) else (
    set "EXE_PATH=target\debug\ps-launcher.exe"
)

REM Check if executable exists
if not exist "%EXE_PATH%" (
    echo %YELLOW%Warning: Executable not found at %EXE_PATH%%RESET%
    exit /b 0
)

echo ============================================================================
echo Build Information
echo ============================================================================
echo.
echo Executable: %EXE_PATH%

REM Get file size
for %%A in ("%EXE_PATH%") do set SIZE=%%~zA
set /a SIZE_KB=!SIZE! / 1024
echo Size: !SIZE_KB! KB (!SIZE! bytes)
echo.

echo ============================================================================
echo Usage
echo ============================================================================
echo.
echo %EXE_PATH% -Script script.ps1 [parameters]
echo.
echo Examples:
echo   %EXE_PATH% -Script test.ps1
echo   %EXE_PATH% -Script test.ps1 -Verbose
echo   %EXE_PATH% -Script backup.ps1 -Path "C:\Data"
echo.

echo ============================================================================
echo Next Steps
echo ============================================================================
echo.
echo 1. Test the executable:
echo    %EXE_PATH% -Script test.ps1
echo.
echo 2. Run unit tests:
echo    build.bat test
echo.
echo 3. Copy to desired location:
echo    copy "%EXE_PATH%" "C:\Tools\"
echo.
echo 4. Run with your own script:
echo    %EXE_PATH% -Script yourscript.ps1
echo.

exit /b 0
