@echo off
rem Delega una tarea: delegar <agy|opencode> <tarea.md> [nombre] [--solo-prompt]
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" delegar %*
) else (
  python "%DIR%kit_agentes.py" delegar %*
)
exit /b %ERRORLEVEL%
