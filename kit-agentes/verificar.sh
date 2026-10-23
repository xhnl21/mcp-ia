#!/bin/sh
# Revisa la configuración: verificar <ruta del proyecto>
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" verificar "$@"
