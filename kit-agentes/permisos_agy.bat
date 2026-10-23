@echo off
rem Permisos de Antigravity: permisos_agy <ruta del proyecto> [--ver]
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" permisos %*
) else (
  python "%DIR%kit_agentes.py" permisos %*
)
exit /b %ERRORLEVEL%
