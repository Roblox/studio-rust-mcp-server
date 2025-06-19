@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM === Configuration ===
SET "VENV_DIR=venv"
SET "AGENT_SCRIPT=main.py"

SET "TEST_COMMAND_FILE=test_commands.txt"
SET "PYTHON_EXIT_CODE=0"


REM === Main Logic ===
CALL :ActivateVenv
IF !ERRORLEVEL! NEQ 0 (
    ECHO ERROR: Failed to activate virtual environment. Script will now exit.
    PAUSE
    ENDLOCAL
    EXIT /B !ERRORLEVEL!
)

ECHO.

ECHO Starting Plugin Test Sequence from file: "%~dp0!TEST_COMMAND_FILE!"
ECHO Agent Script: "%~dp0!AGENT_SCRIPT!"
ECHO =====================================

python "%~dp0!AGENT_SCRIPT!" --test_file "%~dp0!TEST_COMMAND_FILE!"
SET "PYTHON_EXIT_CODE=!ERRORLEVEL!"

ECHO.
ECHO =====================================
ECHO Test Sequence Summary (from main.py execution above)
IF !PYTHON_EXIT_CODE! NEQ 0 (
    ECHO WARNING: main.py exited with error code !PYTHON_EXIT_CODE!. This may indicate issues with the test file execution or the script itself.
) ELSE (
    ECHO main.py completed. Review output above for specific command success/failure details.

)
ECHO =====================================

PAUSE

ENDLOCAL & EXIT /B !PYTHON_EXIT_CODE!


REM === Subroutines ===
:ActivateVenv
    ECHO.
    ECHO Activating virtual environment from '!VENV_DIR!'...
    IF NOT EXIST "%~dp0!VENV_DIR!\Scripts\activate.bat" (
        ECHO ERROR: Virtual environment activation script not found at '%~dp0!VENV_DIR!\Scripts\activate.bat'.
        ECHO Make sure the VENV_DIR is set correctly and the venv exists in the script's directory.
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
