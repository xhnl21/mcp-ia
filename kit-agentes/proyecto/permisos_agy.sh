#!/bin/sh
# Da a Antigravity los permisos de este proyecto ([--ver] solo muestra).
DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$DIR/kit_agentes.py" permisos "$@"
