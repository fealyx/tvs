@echo off
setlocal enabledelayedexpansion
set BUNDLE_DIR=%~dp0..
set PWSH_EXE=%BUNDLE_DIR%\runtime\pwsh\pwsh.exe
if exist "%PWSH_EXE%" (
  "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\tvsm.ps1' update apply %*"
) else (
  pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\tvsm.ps1' update apply %*"
)
exit /b %ERRORLEVEL%
