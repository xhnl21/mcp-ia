#!/bin/sh
# ==============================================================================
# marca.sh — genera ícono, logo del splash y video del splash de una app.
#
# Uso (desde cualquier carpeta):
#   sh ~/.claude/skills/marca-app/scripts/marca.sh <ruta/a/marca.json> [icono|video|todo]
#   sh ~/.claude/skills/marca-app/scripts/marca.sh marca.json cuadros 0.3,1.2,2.0,3.4
#
# La primera vez crea un entorno de Python aislado en ~/.cache/marca-app/venv
# (Pillow, NumPy, imageio-ffmpeg con su propio ffmpeg). No instala nada en el
# sistema ni en el proyecto.
# ==============================================================================
set -e

CONFIG="$1"
QUE="${2:-todo}"
if [ -z "$CONFIG" ] || [ ! -f "$CONFIG" ]; then
  echo "Uso: sh marca.sh <ruta/a/marca.json> [icono|video|todo|cuadros <t1,t2,...>]"
  exit 1
fi
CONFIG=$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")
DIR=$(cd "$(dirname "$0")" && pwd)
VENV="${MARCA_VENV:-$HOME/.cache/marca-app/venv}"

if [ ! -x "$VENV/bin/python" ]; then
  echo "▶ Preparando el entorno en $VENV (solo la primera vez)..."
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q -r "$DIR/../requirements.txt"
fi
PY="$VENV/bin/python"

cd "$DIR"
case "$QUE" in
  icono) "$PY" generar_icono.py --config "$CONFIG" ;;
  video) "$PY" generar_video_splash.py --config "$CONFIG" ;;
  cuadros) "$PY" generar_video_splash.py --config "$CONFIG" --cuadros "$3" ;;
  todo)
    "$PY" generar_icono.py --config "$CONFIG"
    "$PY" generar_video_splash.py --config "$CONFIG"
    ;;
  *) echo "Opción no válida: $QUE (icono, video, todo o cuadros)"; exit 1 ;;
esac
