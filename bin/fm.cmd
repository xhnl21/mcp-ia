@echo off
rem fm.cmd — Acceso rápido al CLI flutter-memory en Windows.
rem Coloca esta carpeta bin/ en tu PATH, o copia el acceso directo.
setlocal
set "FM_ROOT=%~dp0.."
python "%FM_ROOT%\scripts\fm.py" %*
if errorlevel 1 (
    py "%FM_ROOT%\scripts\fm.py" %*
)
endlocal
