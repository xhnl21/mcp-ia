#!/bin/sh
# Instala el kit: instalar <ruta del proyecto> --prefijo XX [--carpetas "lib test docs"] [--mcp-ia RUTA]
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" instalar "$@"
