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
    SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
    GOTO :HandleExit
)

CALL :RunAgent
IF !ERRORLEVEL! NEQ 0 (
    ECHO INFO: Agent script exited with a non-zero status.
    SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
    GOTO :HandleExit
)

REM If we reach here, all main operations were successful
SET "SCRIPT_EXIT_CODE=0"
ECHO.
ECHO Agent execution completed successfully.
GOTO :HandleExit

REM === Subroutines ===
:ActivateVenv
    ECHO.
    ECHO Activating virtual environment from '!VENV_DIR!'...
    IF NOT EXIST "!VENV_DIR!\Scripts\activate.bat" (
        ECHO ERROR: Virtual environment activation script not found at '!VENV_DIR!\Scripts\activate.bat'.
        ECHO Please run the 'setup_venv.bat' script first to create the virtual environment.
        EXIT /B 1
    )
    CALL "!VENV_DIR!\Scripts\activate.bat"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Failed to execute activate.bat script.
        EXIT /B 1
    )
    ECHO Virtual environment activated.
EXIT /B 0

:RunAgent
    ECHO.
    ECHO Starting the Roblox Agent ('!AGENT_SCRIPT!')...
    IF NOT EXIST "!AGENT_SCRIPT!" (
        ECHO ERROR: Agent script '!AGENT_SCRIPT!' not found.
        EXIT /B 1
    )
    python "!AGENT_SCRIPT!"
pause
    SET "PYTHON_ERRORLEVEL=!ERRORLEVEL!"
    IF !PYTHON_ERRORLEVEL! NEQ 0 (
        ECHO WARNING: The agent script exited with error code !PYTHON_ERRORLEVEL!.
    ) ELSE (
        ECHO Agent script completed.
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
