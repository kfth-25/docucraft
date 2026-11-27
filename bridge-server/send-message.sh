#!/bin/bash
# Helper script: reads JSON from stdin, calls aioncore.exe session send-message
# This runs in bash environment which has valid AIONUI_RUNTIME_TOKEN

AIONCORE_PATH="${LOCALAPPDATA:-$HOME/AppData/Local}/Programs/AionUi/resources/bundled-aioncore/win32-x64/aioncore.exe"

# Read stdin
cat | "$AIONCORE_PATH" --local session send-message
