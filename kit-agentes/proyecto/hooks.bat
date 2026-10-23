@echo off
rem Pre-commit común: [--actualizar | --compartir] [--ver] [--forzar].
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" hooks %*
) else (
  python "%DIR%kit_agentes.py" hooks %*
)
exit /b %ERRORLEVEL%
