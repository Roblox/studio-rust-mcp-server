@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM --- Configuration ---
SET "VENV_DIR=venv"
SET "SCRIPT_NAME=run_ollama_agent.bat"
SET "PYTHON_EXE=python"
SET "MAIN_SCRIPT=main.py"
SET "OLLAMA_SERVICE_LOG=ollama_service.log"
SET "DEFAULT_MODEL=phi3:mini"
SET "STARTUP_DELAY_SECONDS=7"

REM --- Main Script ---
CALL :ActivateVenv
IF ERRORLEVEL 1 GOTO :Cleanup

CALL :CheckOllamaInstallation
IF "!OLLAMA_READY!"=="false" GOTO :Cleanup

CALL :EnsureOllamaService
IF "!OLLAMA_SERVICE_READY!"=="false" (
    echo.
    echo [!SCRIPT_NAME!] The Ollama service does not seem to be responding even after an attempt to start it.
    echo [!SCRIPT_NAME!] Please try starting the Ollama application/service manually.
    CHOICE /C YN /M "[!SCRIPT_NAME!] Do you want to try running the agent anyway (Y/N)?"
    IF ERRORLEVEL 2 (
        echo [!SCRIPT_NAME!] Exiting due to Ollama service issue.
        GOTO :Cleanup
    )
    echo [!SCRIPT_NAME!] Proceeding despite potential Ollama service issue. Agent may fail.
)

CALL :SelectOllamaModel
IF "!SELECTED_MODEL!"=="" (
    echo [!SCRIPT_NAME!] No model selected or invalid input. Exiting.
    GOTO :Cleanup
)

CALL :RunAgent

:Cleanup
echo.
echo [!SCRIPT_NAME!] Script finished.
ENDLOCAL
GOTO :EOF


REM --- Subroutine: ActivateVenv ---
:ActivateVenv
echo.
echo [!SCRIPT_NAME!] Looking for Python virtual environment in "!VENV_DIR!"...
IF NOT EXIST "%~dp0!VENV_DIR!\Scripts\activate.bat" (
    echo.
    echo [!SCRIPT_NAME!] ERROR: Python virtual environment not found at "%~dp0!VENV_DIR%\Scripts\activate.bat".
    echo [!SCRIPT_NAME!] Please run "setup_venv.bat" from the project root to create the virtual environment.
    EXIT /B 1
)
echo [!SCRIPT_NAME!] Activating Python virtual environment...
CALL "%~dp0!VENV_DIR!\Scripts\activate.bat"
IF ERRORLEVEL 1 (
    echo.
    echo [!SCRIPT_NAME!] ERROR: Failed to activate the Python virtual environment.
    EXIT /B 1
)
echo [!SCRIPT_NAME!] Python virtual environment activated.
GOTO :EOF


REM --- Subroutine: CheckOllamaInstallation ---
:CheckOllamaInstallation
SET OLLAMA_READY=false
echo.
echo [!SCRIPT_NAME!] Checking for Ollama installation...
ollama --version >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
    echo [!SCRIPT_NAME!] Ollama is installed.
    SET OLLAMA_READY=true
) ELSE (
    echo [!SCRIPT_NAME!] Ollama installation not found.
    echo [!SCRIPT_NAME!] Please run 'ollama_setup.bat' first to install Ollama and download models.
)
GOTO :EOF


REM --- Subroutine: EnsureOllamaService ---
:EnsureOllamaService
SET OLLAMA_SERVICE_READY=false
echo.
echo [!SCRIPT_NAME!] Checking if Ollama service is running...
ollama list >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
    echo [!SCRIPT_NAME!] Ollama service is responding.
    SET OLLAMA_SERVICE_READY=true
    GOTO :EOF
)

echo [!SCRIPT_NAME!] Ollama service not responding. Attempting to start it...
echo [!SCRIPT_NAME!] This may take a moment. A log file will be created: !OLLAMA_SERVICE_LOG!
REM Starting a small model like phi3:mini in the background can help ensure the service is up.
REM The --verbose flag can help in diagnosing issues if the log is inspected.
START "OllamaServiceDaemon" /B ollama run !DEFAULT_MODEL! --verbose > "!OLLAMA_SERVICE_LOG!" 2>&1

echo [!SCRIPT_NAME!] Waiting for !STARTUP_DELAY_SECONDS! seconds for the Ollama service to initialize...
timeout /t !STARTUP_DELAY_SECONDS! /nobreak >NUL

echo [!SCRIPT_NAME!] Re-checking Ollama service status...
ollama list >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
    echo [!SCRIPT_NAME!] Ollama service is now responding.
    SET OLLAMA_SERVICE_READY=true
) ELSE (
    echo [!SCRIPT_NAME!] Ollama service still not responding.
    echo [!SCRIPT_NAME!] Please check the log file: !OLLAMA_SERVICE_LOG!
    echo [!SCRIPT_NAME!] You might need to start the Ollama application manually.
    REM Note: The background 'ollama run' process might still be trying.
    REM If it succeeds later, the agent might connect.
)
GOTO :EOF


REM --- Subroutine: SelectOllamaModel ---
:SelectOllamaModel
SET SELECTED_MODEL=
echo.
echo [!SCRIPT_NAME!] Please select an Ollama model to use:
echo   1. Phi-4 Mini - Function Calling (phi4-mini-functools) (Recommended if you ran setup_phi4_fc_model.bat)
echo   2. Phi-4 Mini - Standard (phi4-mini)
echo   3. Qwen2.5 7B (qwen2.5-coder:7b)
echo   4. Qwen2.5 7B Quantized (qwen2.5-coder:7b-instruct-q4_K_M)
echo   5. Enter custom model name
echo.

CHOICE /C 12345 /M "[!SCRIPT_NAME!] Enter your choice (1-5): "
SET MODEL_CHOICE=!ERRORLEVEL!

IF "!MODEL_CHOICE!"=="1" SET SELECTED_MODEL=phi4-mini-functools
IF "!MODEL_CHOICE!"=="2" SET SELECTED_MODEL=phi4-mini
IF "!MODEL_CHOICE!"=="3" SET SELECTED_MODEL=qwen2.5-coder:7b
IF "!MODEL_CHOICE!"=="4" SET SELECTED_MODEL=qwen2.5-coder:7b-instruct-q4_K_M

IF "!MODEL_CHOICE!"=="5" (
    echo.
    SET /P "CUSTOM_MODEL=[!SCRIPT_NAME!] Enter the custom Ollama model name (e.g., mistral:latest): "
    IF DEFINED CUSTOM_MODEL (
        SET SELECTED_MODEL=!CUSTOM_MODEL!
    ) ELSE (
        echo [!SCRIPT_NAME!] No custom model name entered.
        SET SELECTED_MODEL=
    )
)

IF DEFINED SELECTED_MODEL (
    echo [!SCRIPT_NAME!] Using model: !SELECTED_MODEL!
)
GOTO :EOF
pause

REM --- Subroutine: RunAgent ---
:RunAgent
echo.
echo [!SCRIPT_NAME!] Starting the AI agent with Ollama model: !SELECTED_MODEL!
echo [!SCRIPT_NAME!] Command: !PYTHON_EXE! !MAIN_SCRIPT! --llm_provider ollama --ollama_model "!SELECTED_MODEL!"
echo.
"!PYTHON_EXE!" "!MAIN_SCRIPT!" --llm_provider ollama --ollama_model "!SELECTED_MODEL!"
echo.
echo [!SCRIPT_NAME!] Agent execution finished.
pause
GOTO :EOF

pause

