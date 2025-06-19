@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SCRIPT_EXIT_CODE=0"
SET "RUSTUP_URL=https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
SET "RUSTUP_PATH=%TEMP%\rustup-init.exe"

REM === Initial Cargo Check ===
ECHO Checking for existing Cargo installation...
cargo --version >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    ECHO Cargo is already installed. Proceeding to build.
    ECHO.
    GOTO :BuildSection
)

ECHO.
ECHO Cargo not found. Attempting to download Rust/Cargo.
ECHO This will download 'rustup-init.exe' from !RUSTUP_URL! to !RUSTUP_PATH!
ECHO.

REM === Download rustup-init.exe ===
ECHO Attempting to download rustup-init.exe...
REM Ensure old temp file is deleted if it exists, to prevent issues with partial downloads
IF EXIST "!RUSTUP_PATH!" DEL "!RUSTUP_PATH!" /F /Q

REM PowerShell command to download the file
SET "POWERSHELL_COMMAND=Write-Host 'INFO: Attempting to download rustup-init.exe...'; try { Invoke-WebRequest -Uri '!RUSTUP_URL!' -OutFile '!RUSTUP_PATH!' -UseBasicParsing; Write-Host 'INFO: Download of rustup-init.exe complete.'; exit 0; } catch { Write-Error ('ERROR: Failed to download rustup-init.exe: ' + $_.Exception.Message); exit 1; }"
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "!POWERSHELL_COMMAND!"

IF !ERRORLEVEL! NEQ 0 (
    ECHO.
    ECHO =====================================================================
    ECHO ERROR: Failed to download rustup-init.exe using PowerShell.
    ECHO PowerShell Exit Code: !ERRORLEVEL!
    ECHO Please check your internet connection and ensure PowerShell can access the internet.
    ECHO You can also try downloading manually from !RUSTUP_URL!
    ECHO and placing it at !RUSTUP_PATH! then re-running this script.
    ECHO =====================================================================
    SET "SCRIPT_EXIT_CODE=3" & REM Specific error code for download failure
    GOTO :Finish
)

ECHO Download of rustup-init.exe successful.

REM === Execute rustup-init.exe ===
ECHO.
ECHO Attempting to install Rust/Cargo using the downloaded installer...
ECHO This may take a few minutes.
"!RUSTUP_PATH!" -y --default-toolchain stable --profile default
SET "INSTALL_ERROR_LEVEL=!ERRORLEVEL!"

IF !INSTALL_ERROR_LEVEL! NEQ 0 (
    ECHO.
    ECHO =====================================================================
    ECHO ERROR: Rust installation via rustup-init.exe failed (Error Code: !INSTALL_ERROR_LEVEL!).
    ECHO This could be due to:
    ECHO   - Insufficient permissions (try running this script as Administrator).
    ECHO   - An existing incompatible Rust installation.
    ECHO   - Network issues during installation of components.
    ECHO   - Antivirus software interfering with the installer.
    ECHO Please review any messages above from the installer.
    ECHO You may need to install Rust manually from https://rustup.rs
    ECHO =====================================================================
    SET "SCRIPT_EXIT_CODE=4" & REM Specific error code for installation failure
    GOTO :DeleteRustupAndFinish
)

ECHO.
ECHO =========================================================================
ECHO Rust/Cargo installation attempt appears to have been successful.
ECHO IMPORTANT: For the PATH changes to take full effect,
ECHO            you MUST CLOSE this command prompt/terminal window
ECHO            and OPEN A NEW ONE.
ECHO
ECHO After opening a new terminal, please RE-RUN this
ECHO build_rust_server.bat script to proceed with building the project.
ECHO =========================================================================
SET "SCRIPT_EXIT_CODE=0" & REM Installation attempted, user must re-run.
GOTO :DeleteRustupAndFinish


:DeleteRustupAndFinish
    IF EXIST "!RUSTUP_PATH!" (
        ECHO Deleting temporary installer "!RUSTUP_PATH!"...
        DEL /F /Q "!RUSTUP_PATH!"
        IF !ERRORLEVEL! NEQ 0 (
            ECHO WARNING: Failed to delete temporary installer "!RUSTUP_PATH!". You may want to delete it manually.
        ) ELSE (
            ECHO Temporary installer deleted.
        )
    )
    GOTO :Finish

:BuildSection
    ECHO.
    ECHO Cargo is available. Proceeding to build the Rust MCP Server...
    ECHO Enabling 'gemini_python_broker' feature for this build.
    cargo build --release --features gemini_python_broker
	pause
    IF !ERRORLEVEL! NEQ 0 (
        ECHO.
        ECHO =====================================================================
        ECHO ERROR: Failed to build Rust MCP Server (with 'gemini_python_broker' feature).
        ECHO Cargo reported an error (Code: !ERRORLEVEL!). Please review any messages above.
        ECHO =====================================================================
        SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!" & REM Use the actual cargo error code
        GOTO :Finish
    )

    ECHO.
    ECHO =====================================================================
    ECHO Rust MCP Server built successfully!
    ECHO Executable should be in target\release\rbx-studio-mcp.exe
    ECHO =====================================================================
    SET "SCRIPT_EXIT_CODE=0" & REM Explicitly set to 0 on successful build
    GOTO :Finish

:Finish
ENDLOCAL & (
    ECHO.
    IF %SCRIPT_EXIT_CODE% EQU 0 (
        ECHO Script finished successfully (Current stage).
    ) ELSE (
        ECHO Script finished with errors (Code: %SCRIPT_EXIT_CODE%). Review messages above.
    )
    PAUSE
    EXIT /B %SCRIPT_EXIT_CODE%
)
