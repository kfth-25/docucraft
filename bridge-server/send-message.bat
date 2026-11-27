@echo off
REM Aion UI session send-message wrapper
REM Inherits Aion UI env vars for runtime bridge auth
"C:\Users\Pongo\AppData\Local\Programs\AionUi\resources\bundled-aioncore\win32-x64\aioncore.exe" --parent-pid 21952 --local session send-message
