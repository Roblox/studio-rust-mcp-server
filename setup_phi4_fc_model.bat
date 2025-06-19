@echo OFF
SETLOCAL ENABLEDELAYEDEXPANSION

:: ============================================================================
:: Batch File: setup_phi4_fc_model.bat
:: Version: 2.4 (Production Ready)
:: Description: Creates a custom Ollama model for phi4-mini with a specific
::              template for reliable function calling (functools format).
:: ============================================================================

:: --- Configuration ---
SET "MODFILE_NAME=phi4_fc_ollama.Modelfile"
SET "CUSTOM_MODEL_NAME=phi4-mini-functools"
SET "BASE_MODEL_NAME=phi4-mini:latest"
SET "SCRIPT_NAME=%~nx0"
SET "ERROR_FLAG=0"

:: Define a single quote and triple quote reliably
SET "Q="" 
SET "TQ=!Q!!Q!!Q!"

echo [!SCRIPT_NAME!] SCRIPT START
echo [!SCRIPT_NAME!] Using custom model name: !CUSTOM_MODEL_NAME!, base model: !BASE_MODEL_NAME!
echo.

:: --- Prepare Modelfile by copying from source ---
echo [!SCRIPT_NAME!] Ensuring source Modelfile 'phi4_fc_ollama.Modelfile' exists...
IF NOT EXIST "phi4_fc_ollama.Modelfile" (
    echo [!SCRIPT_NAME!] CRITICAL ERROR: Source Modelfile 'phi4_fc_ollama.Modelfile' not found in current directory.
    SET "ERROR_FLAG=1"
    GOTO :EndScript
)

echo [!SCRIPT_NAME!] Source Modelfile 'phi4_fc_ollama.Modelfile' found.


echo [!SCRIPT_NAME!] Copying 'phi4_fc_ollama.Modelfile' to '!MODFILE_NAME!'...
COPY /Y "phi4_fc_ollama.Modelfile" "!MODFILE_NAME!"
IF !ERRORLEVEL! NEQ 0 (
    echo [!SCRIPT_NAME!] CRITICAL ERROR: Failed to copy 'phi4_fc_ollama.Modelfile' to '!MODFILE_NAME!'.
    SET "ERROR_FLAG=1"
    GOTO :EndScript
)
echo [!SCRIPT_NAME!] Modelfile '!MODFILE_NAME!' prepared successfully by copying.
echo.

:: --- Run ollama create ---
echo [!SCRIPT_NAME!] Attempting to create Ollama model "!CUSTOM_MODEL_NAME!"...
ollama create "!CUSTOM_MODEL_NAME!" -f "!MODFILE_NAME!"
SET "OLLAMA_CREATE_ERRORLEVEL=!ERRORLEVEL!"
echo [!SCRIPT_NAME!] 'ollama create' command finished with ERRORLEVEL: !OLLAMA_CREATE_ERRORLEVEL!

SET "TEST_VAR=Value" & REM This simple command seems to prevent a cmd.exe parsing error after ollama create. Do not remove.

IF "!OLLAMA_CREATE_ERRORLEVEL!" NEQ "0" (
    echo.
    echo [!SCRIPT_NAME!] ERROR: 'ollama create' command failed with error code !OLLAMA_CREATE_ERRORLEVEL!.
    echo [!SCRIPT_NAME!] Please check Ollama output above and its server logs for more details.
    SET "ERROR_FLAG=1"
    GOTO :EndScript
)

echo.
echo [!SCRIPT_NAME!] Successfully created Ollama model: "!CUSTOM_MODEL_NAME!"
echo.
echo   --- Next Steps ---
echo   1. If using with an agent, update its configuration to use: "!CUSTOM_MODEL_NAME!"
echo   2. Relaunch your agent.
echo   The Modelfile ("!MODFILE_NAME!") is in the current directory for reference.
echo.

GOTO :EndScript

:EndScript
IF "!ERROR_FLAG!" EQU "1" (
    echo [!SCRIPT_NAME!] SCRIPT FINISHED WITH ERRORS.
) ELSE (
    echo [!SCRIPT_NAME!] SCRIPT FINISHED SUCCESSFULLY.
)
ENDLOCAL
echo.
echo Press any key to continue . . .
pause
EXIT /B %ERROR_FLAG%