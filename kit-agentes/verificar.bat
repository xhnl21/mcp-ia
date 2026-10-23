@echo off
rem Revisa la configuración: verificar <ruta del proyecto>
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" verificar %*
) else (
  python "%DIR%kit_agentes.py" verificar %*
)
exit /b %ERRORLEVEL%
