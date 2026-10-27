#!/bin/sh
# Enlaza reglas y herramientas compartidas en Claude Code y Antigravity (ver enlazar_compartido.py).
python3 "$(dirname "$0")/enlazar_compartido.py" "$@"
