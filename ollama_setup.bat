@echo OFF
REM This script does not activate the Python virtual environment as it primarily
REM interacts with the system-level 'ollama' command and does not run project Python scripts.
SETLOCAL ENABLEDELAYEDEXPANSION

REM --- Main Script ---
CALL :CheckOllama
IF "!OLLAMA_INSTALLED!"=="false" (
    CALL :InstallGuide
    CALL :CheckOllama
    IF "!OLLAMA_INSTALLED!"=="false" (
        echo.
        echo [OLLAMA SETUP] Ollama still not found after installation attempt.
        echo [OLLAMA SETUP] Please try restarting your terminal/command prompt, or ensure Ollama is correctly added to your system PATH.
        CHOICE /C YN /M "[OLLAMA SETUP] Do you want to try downloading models anyway (Y/N)?"
        IF ERRORLEVEL 2 (
            echo [OLLAMA SETUP] Exiting setup. Please resolve Ollama installation issues.
            GOTO :EOF
        )
    )
)

CALL :DownloadModels

echo.
echo [OLLAMA SETUP] Ollama setup process complete.
echo [OLLAMA SETUP] You can now try running the agent using a batch file like 'run_ollama_agent.bat' (if available)
echo [OLLAMA SETUP] or by running the main Python script with '--llm_provider ollama'.
GOTO :EOF

REM --- Subroutine: CheckOllama ---
:CheckOllama
echo.
echo [OLLAMA SETUP] Checking for Ollama installation...
ollama --version >NUL 2>NUL
IF !ERRORLEVEL! EQU 0 (
    echo [OLLAMA SETUP] Ollama is installed.
    SET OLLAMA_INSTALLED=true
) ELSE (
    echo [OLLAMA SETUP] Ollama not found.
    SET OLLAMA_INSTALLED=false
)
GOTO :EOF

REM --- Subroutine: InstallGuide ---
:InstallGuide
echo.
echo [OLLAMA SETUP] Ollama installation guide:
echo [OLLAMA SETUP] 1. Download Ollama from: https://ollama.com/download
echo [OLLAMA SETUP] 2. Run the installer and follow its instructions.
echo [OLLAMA SETUP] 3. Ensure Ollama is running after installation (it usually starts automatically).
echo.
pause "[OLLAMA SETUP] Press any key to continue after installing Ollama..."
GOTO :EOF

REM --- Subroutine: DownloadModels ---
:DownloadModels
echo.
echo [OLLAMA SETUP] Attempting to download required Ollama models...
echo [OLLAMA SETUP] This may take some time depending on your internet connection.
echo.

SET MODEL_PHI4=phi4-mini

SET MODEL_QWEN2_7B=qwen2.5-coder:7b
SET MODEL_QWEN2_7B_Q4=qwen2.5-coder:7b-instruct-q4_K_M

REM Using qwen2:7b-q4_K_M as q4_0 is less common. User can change if needed.

echo [OLLAMA SETUP] Pulling model: !MODEL_PHI4!
ollama pull "!MODEL_PHI4!"
IF !ERRORLEVEL! EQU 0 (
    echo [OLLAMA SETUP] Successfully pulled !MODEL_PHI4!.
) ELSE (
    echo [OLLAMA SETUP] ERROR: Failed to pull !MODEL_PHI4!. Please check your internet connection and ensure Ollama is running. (Error Code: !ERRORLEVEL!)
)
echo.

echo [OLLAMA SETUP] Pulling model: !MODEL_QWEN2_7B!
ollama pull "!MODEL_QWEN2_7B!"
IF !ERRORLEVEL! EQU 0 (
    echo [OLLAMA SETUP] Successfully pulled !MODEL_QWEN2_7B!.
) ELSE (
    echo [OLLAMA SETUP] ERROR: Failed to pull !MODEL_QWEN2_7B!. (Error Code: !ERRORLEVEL!)
)
echo.

echo [OLLAMA SETUP] Pulling model: !MODEL_QWEN2_7B_Q4!
ollama pull "!MODEL_QWEN2_7B_Q4!"
IF !ERRORLEVEL! EQU 0 (
    echo [OLLAMA SETUP] Successfully pulled !MODEL_QWEN2_7B_Q4!.
) ELSE (
    echo [OLLAMA SETUP] ERROR: Failed to pull !MODEL_QWEN2_7B_Q4!. (Error Code: !ERRORLEVEL!)
    echo [OLLAMA SETUP] Note: If this specific quantized model is unavailable, you might try other variants like 'qwen2:7b-q5_K_M' or check the Ollama library for available tags.
)
echo.
GOTO :EOF


pause

