@echo off
rem Instala el kit: instalar <ruta del proyecto> --prefijo XX [--carpetas "lib test docs"] [--mcp-ia RUTA]
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" instalar %*
) else (
  python "%DIR%kit_agentes.py" instalar %*
)
exit /b %ERRORLEVEL%
