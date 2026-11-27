@echo off
echo Starting Bridge Server...
cd /d "%~dp0bridge-server"
node aion-bridge.js
