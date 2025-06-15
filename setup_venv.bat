@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SCRIPT_EXIT_CODE=0"

REM === Configuration ===
SET "VENV_DIR=venv"
SET "REQUIREMENTS_FILE=requirements.txt"

REM === Validation ===
CALL :CheckPython
IF !ERRORLEVEL! NEQ 0 (
    ECHO ERROR: Python check failed. Script will terminate.
    SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
    GOTO :HandleExit
)

REM === Main Logic ===
CALL :CreateVenv
IF !ERRORLEVEL! NEQ 0 (
    ECHO ERROR: Virtual environment creation failed. Script will terminate.
    SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
    GOTO :HandleExit
)

CALL :InstallDependencies
IF !ERRORLEVEL! NEQ 0 (
    ECHO ERROR: Failed to install dependencies. Script will terminate.
    SET "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
    GOTO :HandleExit
)

REM === Completion (if all successful) ===
ECHO.
ECHO =====================================================================
ECHO Setup complete!
ECHO Virtual environment '!VENV_DIR!' is ready and dependencies are installed.
ECHO To activate the virtual environment in your current shell, run:
ECHO .\!VENV_DIR!\Scripts\activate.bat
ECHO =====================================================================
SET "SCRIPT_EXIT_CODE=0" REM Explicitly set for success path
GOTO :HandleExit


REM === Subroutines ===
:CheckPython
    ECHO Checking for Python installation...
    python --version >nul 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Python is not installed or not found in your system's PATH.
        ECHO Please install Python from python.org and ensure it's added to PATH.
        EXIT /B 1
    )
    ECHO Python found.
EXIT /B 0

:CreateVenv
    ECHO.
    ECHO Checking for virtual environment directory: '!VENV_DIR!'
    IF EXIST "!VENV_DIR!\Scripts\activate.bat" (
        ECHO Virtual environment '!VENV_DIR!' already exists and appears valid. Skipping creation.
        EXIT /B 0
    )

    IF EXIST "!VENV_DIR!" (
        ECHO Directory '!VENV_DIR!' exists but doesn't seem to be a valid venv.
        ECHO You might need to remove it manually if you want to recreate it.
        ECHO For now, attempting to proceed assuming it might be usable or will be fixed by Python.
    )

    ECHO Creating virtual environment in '!VENV_DIR!'...
    python -m venv "!VENV_DIR!"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Failed to create virtual environment in '!VENV_DIR!'.
        EXIT /B 1
    )
    ECHO Virtual environment created.
EXIT /B 0

:InstallDependencies
    ECHO.
    ECHO Activating virtual environment to install dependencies...
    IF NOT EXIST "!VENV_DIR!\Scripts\activate.bat" (
        ECHO ERROR: Cannot find activate script at '!VENV_DIR!\Scripts\activate.bat'.
        ECHO Virtual environment setup might have failed.
        EXIT /B 1
    )
    CALL "!VENV_DIR!\Scripts\activate.bat"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Failed to call the activate script. Venv might be corrupted or not found.
        EXIT /B 1
    )

    ECHO Installing dependencies from '!REQUIREMENTS_FILE!'...
    IF NOT EXIST "!REQUIREMENTS_FILE!" (
        ECHO ERROR: '!REQUIREMENTS_FILE!' not found. Cannot install dependencies.
        EXIT /B 1
    )
    pip install -r "!REQUIREMENTS_FILE!"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO ERROR: Failed to install dependencies from '!REQUIREMENTS_FILE!'.
        ECHO Check your internet connection and the contents of the file.
        EXIT /B 1
    )
    ECHO Dependencies installed successfully.
EXIT /B 0

REM === Final Exit Point ===
:HandleExit
ENDLOCAL & (
    ECHO.
    IF %SCRIPT_EXIT_CODE% NEQ 0 (
        ECHO Script finished with errors. Error Code: %SCRIPT_EXIT_CODE%
    ) ELSE (
        ECHO Script finished successfully.
    )
    PAUSE
    EXIT /B %SCRIPT_EXIT_CODE%
)
