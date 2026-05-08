@echo off
setlocal enabledelayedexpansion
set BUNDLE_DIR=%~dp0..
set PWSH_EXE=%BUNDLE_DIR%\runtime\pwsh\pwsh.exe
if exist "%PWSH_EXE%" (
  "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\modules\Znelchar.Tools\Public\Expand-ZnelcharData.ps1' %*"
) else (
  pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\modules\Znelchar.Tools\Public\Expand-ZnelcharData.ps1' %*"
)
exit /b %ERRORLEVEL%
