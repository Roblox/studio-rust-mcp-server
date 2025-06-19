@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SCRIPT_EXIT_CODE=0"

REM === Configuration ===
SET "VENV_DIR=venv"
SET "AGENT_SCRIPT=main.py"

REM === Main Logic ===
CALL :ActivateVenv
IF !ERRORLEVEL! NEQ 0 (
    ECHO ERROR: Failed to activate virtual environment.
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)

CALL :RunAgent
REM The SCRIPT_EXIT_CODE from RunAgent will propagate
SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
IF !SCRIPT_EXIT_CODE! NEQ 0 (
    ECHO INFO: Agent script exited with error code !SCRIPT_EXIT_CODE!.
) ELSE (
    ECHO Agent script completed.
)

GOTO :HandleExit

REM === Subroutines ===
:ActivateVenv
    ECHO.
    ECHO Activating virtual environment from '!VENV_DIR!'...
    IF NOT EXIST "%~dp0!VENV_DIR!\Scripts\activate.bat" (
        ECHO ERROR: Virtual environment activation script not found at '%~dp0!VENV_DIR!\Scripts\activate.bat'.
        ECHO Please run the 'setup_venv.bat' script first to create the virtual environment.
        EXIT /B 1
    )
    CALL "%~dp0!VENV_DIR!\Scripts\activate.bat"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Failed to execute activate.bat script.
        EXIT /B 1
    )
    ECHO Virtual environment activated.
EXIT /B 0

:RunAgent
    ECHO.
    ECHO Starting the Roblox Agent in Interactive Mode ('%~dp0!AGENT_SCRIPT!')...
    IF NOT EXIST "%~dp0!AGENT_SCRIPT!" (
        ECHO ERROR: Agent script '%~dp0!AGENT_SCRIPT!' not found.
        EXIT /B 1
    )
    python "%~dp0!AGENT_SCRIPT!"
    SET "PYTHON_ERRORLEVEL=!ERRORLEVEL!"
    pause
    REM This pause allows user to see any immediate output/errors if main.py exits quickly.

    IF !PYTHON_ERRORLEVEL! NEQ 0 (
        ECHO WARNING: The agent script exited with error code !PYTHON_ERRORLEVEL!.
    )
EXIT /B !PYTHON_ERRORLEVEL!

REM === Final Exit Point ===
:HandleExit
ENDLOCAL & (
    ECHO.
    IF %SCRIPT_EXIT_CODE% NEQ 0 (
        ECHO Agent execution finished with errors (Code: %SCRIPT_EXIT_CODE%).
    ) ELSE (
        ECHO Agent execution finished successfully.
    )
    PAUSE
    EXIT /B %SCRIPT_EXIT_CODE%
)
