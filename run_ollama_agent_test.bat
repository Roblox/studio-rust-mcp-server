@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SCRIPT_EXIT_CODE=0"

REM === Configuration ===
SET "VENV_DIR=venv"

SET "OLLAMA_TEST_MODEL=qwen2.5-coder:7b-instruct-q4_K_M" 

SET "TEST_COMMAND_FILE=ollama_test_commands.txt"
SET "PYTHON_SCRIPT=main.py"
SET "OLLAMA_SERVICE_LOG=ollama_service_test_run.log"

ECHO [run_ollama_agent_test.bat] Starting Ollama Agent Test Script...

REM === Activate Virtual Environment ===
CALL :ActivateVenv
IF !ERRORLEVEL! NEQ 0 (
    ECHO [run_ollama_agent_test.bat] ERROR: Failed to activate virtual environment.
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)

REM === Check Ollama Installation ===
CALL :CheckOllamaInstallation
IF !ERRORLEVEL! NEQ 0 (
    ECHO [run_ollama_agent_test.bat] ERROR: Ollama installation check failed.
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)

REM === Check Ollama Service ===
CALL :CheckOllamaService
IF !ERRORLEVEL! NEQ 0 (
    ECHO [run_ollama_agent_test.bat] ERROR: Ollama service check failed.
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)

REM === Check for Test Command File ===
ECHO [run_ollama_agent_test.bat] Looking for test command file: "!TEST_COMMAND_FILE!"
IF NOT EXIST "%~dp0!TEST_COMMAND_FILE!" (
    ECHO [run_ollama_agent_test.bat] ERROR: Test command file "!TEST_COMMAND_FILE!" not found in "%~dp0".
    SET "SCRIPT_EXIT_CODE=1"
    GOTO :HandleExit
)
ECHO [run_ollama_agent_test.bat] Test command file found.

REM === Run the Agent with Test File ===
ECHO [run_ollama_agent_test.bat] Starting the AI agent with Ollama model "!OLLAMA_TEST_MODEL!" using test file "!TEST_COMMAND_FILE!"...
ECHO [run_ollama_agent_test.bat] Command: python "%~dp0!PYTHON_SCRIPT!" --llm_provider ollama --ollama_model "!OLLAMA_TEST_MODEL!" --test_file "%~dp0!TEST_COMMAND_FILE!"
python "%~dp0!PYTHON_SCRIPT!" --llm_provider ollama --ollama_model "!OLLAMA_TEST_MODEL!" --test_file "%~dp0!TEST_COMMAND_FILE!"
SET "AGENT_ERRORLEVEL=!ERRORLEVEL!"

IF !AGENT_ERRORLEVEL! NEQ 0 (
    ECHO [run_ollama_agent_test.bat] WARNING: Agent script exited with error code !AGENT_ERRORLEVEL!.
    SET "SCRIPT_EXIT_CODE=!AGENT_ERRORLEVEL!"
) ELSE (
    ECHO [run_ollama_agent_test.bat] Agent script completed successfully.
)

GOTO :HandleExit

REM === Subroutines ===
:ActivateVenv
    ECHO [run_ollama_agent_test.bat] Looking for Python virtual environment in "!VENV_DIR!"...
    IF NOT EXIST "%~dp0!VENV_DIR!\Scripts\activate.bat" (
        ECHO [run_ollama_agent_test.bat] ERROR: Virtual environment script not found at '%~dp0!VENV_DIR!\Scripts\activate.bat'.
        ECHO [run_ollama_agent_test.bat] Please run 'setup_venv.bat' first.
        EXIT /B 1
    )
    ECHO [run_ollama_agent_test.bat] Activating Python virtual environment...
    CALL "%~dp0!VENV_DIR!\Scripts\activate.bat"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO [run_ollama_agent_test.bat] ERROR: Failed to execute activate.bat.
        EXIT /B 1
    )
    ECHO [run_ollama_agent_test.bat] Python virtual environment activated.
EXIT /B 0

:CheckOllamaInstallation
    ECHO [run_ollama_agent_test.bat] Checking for Ollama installation...
    ollama --version >nul 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        ECHO [run_ollama_agent_test.bat] ERROR: Ollama is not installed or not found in PATH.
        ECHO [run_ollama_agent_test.bat] Please install Ollama and ensure it's in your PATH or run ollama_setup.bat.
        EXIT /B 1
    )
    ECHO [run_ollama_agent_test.bat] Ollama is installed.
EXIT /B 0

:CheckOllamaService
    ECHO [run_ollama_agent_test.bat] Checking if Ollama service is running...
    ollama list >nul 2>nul
    IF !ERRORLEVEL! NEQ 0 (
        ECHO [run_ollama_agent_test.bat] Ollama service does not appear to be running. Attempting to start it...
        ECHO [run_ollama_agent_test.bat] (This may take a few moments. A log file '!OLLAMA_SERVICE_LOG!' will be created.)
        START "OllamaServiceTest" /B ollama run !OLLAMA_TEST_MODEL! --verbose > "!OLLAMA_SERVICE_LOG!" 2>&1

        ECHO [run_ollama_agent_test.bat] Waiting for 25 seconds for Ollama service to initialize...
        TIMEOUT /T 25 /NOBREAK >nul

        ollama list >nul 2>&1
        IF !ERRORLEVEL! NEQ 0 (
            ECHO [run_ollama_agent_test.bat] ERROR: Failed to start or detect Ollama service after attempt.
            ECHO [run_ollama_agent_test.bat] Please ensure Ollama service is running manually and try again.
            ECHO [run_ollama_agent_test.bat] Check '!OLLAMA_SERVICE_LOG!' for details if a start was attempted.
            EXIT /B 1
        )
        ECHO [run_ollama_agent_test.bat] Ollama service appears to be running now.
    ) ELSE (
        ECHO [run_ollama_agent_test.bat] Ollama service is responding.
    )
EXIT /B 0

:HandleExit
    ECHO [run_ollama_agent_test.bat] Script finished. Exit Code: !SCRIPT_EXIT_CODE!
    ENDLOCAL & (
        PAUSE
        EXIT /B %SCRIPT_EXIT_CODE%
    )
