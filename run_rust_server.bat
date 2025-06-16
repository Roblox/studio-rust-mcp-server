@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SCRIPT_EXIT_CODE=0"

REM === Configuration ===
SET "SERVER_EXE_PATH=target\release\rbx-studio-mcp.exe"

REM === Main Logic ===
ECHO Starting Rust MCP Server...
ECHO.

IF NOT EXIST "!SERVER_EXE_PATH!" (
    ECHO ERROR: Rust MCP Server executable not found at '!SERVER_EXE_PATH!'.
    ECHO Please build the server first by running 'build_rust_server.bat'.
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)

ECHO Attempting to run server: "!SERVER_EXE_PATH!" --stdio
ECHO Press Ctrl+C in this window to stop the server manually if needed.
ECHO.
"!SERVER_EXE_PATH!" --stdio
SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!" REM Capture exit code immediately

IF !SCRIPT_EXIT_CODE! NEQ 0 (
    ECHO.
    ECHO =====================================================================
    ECHO WARNING: Rust MCP Server exited with error code !SCRIPT_EXIT_CODE!.
    ECHO Review any messages above from the server.
    ECHO =====================================================================
) ELSE (
    ECHO.
    ECHO =====================================================================
    ECHO Rust MCP Server has finished execution (Exit Code: 0).
    ECHO =====================================================================
)
GOTO :HandleExit

REM === Final Exit Point ===
:HandleExit
ENDLOCAL & (
    ECHO.
    IF %SCRIPT_EXIT_CODE% NEQ 0 (
        ECHO Script finished with errors (Code: %SCRIPT_EXIT_CODE%).
    ) ELSE (
        ECHO Script finished successfully.
    )
    PAUSE
    EXIT /B %SCRIPT_EXIT_CODE%
)
