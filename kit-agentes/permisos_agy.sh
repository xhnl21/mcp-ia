#!/bin/sh
# Permisos de Antigravity: permisos_agy <ruta del proyecto> [--ver]
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" permisos "$@"
