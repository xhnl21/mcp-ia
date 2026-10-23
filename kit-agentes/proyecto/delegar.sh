#!/bin/sh
# Delega una tarea: delegar <agy|opencode> <tarea.md> [nombre] [--solo-prompt]
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" delegar "$@"
