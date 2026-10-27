@echo off
rem Clona o usa mcp-ia y lo registra en Claude Code y Antigravity: registrar_mcp <ruta del proyecto> [--mcp-ia RUTA]
setlocal
set "DIR=%~dp0"
where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%DIR%kit_agentes.py" mcp %*
) else (
  python "%DIR%kit_agentes.py" mcp %*
)
exit /b %ERRORLEVEL%
