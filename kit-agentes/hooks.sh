#!/bin/sh
# Pre-commit común: hooks <proyecto> [--actualizar | --compartir] [--ver] [--forzar]
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" hooks "$@"
