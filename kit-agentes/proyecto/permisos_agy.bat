@echo off
rem Da a Antigravity los permisos de este proyecto ([--ver] solo muestra).
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" permisos %*
) else (
  python "%DIR%kit_agentes.py" permisos %*
)
exit /b %ERRORLEVEL%
