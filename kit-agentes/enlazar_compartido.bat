@echo off
REM Enlaza reglas y herramientas compartidas en Claude Code y Antigravity (ver enlazar_compartido.py).
py -3 "%~dp0enlazar_compartido.py" %* || python "%~dp0enlazar_compartido.py" %*
