#!/bin/sh
# Clona o usa mcp-ia y lo registra en Claude Code y Antigravity: registrar_mcp <ruta del proyecto> [--mcp-ia RUTA]
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" mcp "$@"
