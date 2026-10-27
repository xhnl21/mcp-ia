#!/bin/sh
# ==============================================================================
# herramientas/instalar.sh — enlaza las herramientas compartidas del kit como
# skills de Claude Code (~/.claude/skills/<nombre>), para usarlas en cualquier
# proyecto de esta máquina. Es un enlace: un `git pull` de mcp-ia las actualiza.
#
# Uso: sh kit-agentes/herramientas/instalar.sh            (todas)
#      sh kit-agentes/herramientas/instalar.sh marca-app  (una)
# ==============================================================================
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
DESTINO="$HOME/.claude/skills"
mkdir -p "$DESTINO"
for dir in "$AQUI"/*/; do
  nombre=$(basename "$dir")
  [ -n "$1" ] && [ "$1" != "$nombre" ] && continue
  [ -f "$dir/SKILL.md" ] || continue
  if [ -e "$DESTINO/$nombre" ] && [ ! -L "$DESTINO/$nombre" ]; then
    mv "$DESTINO/$nombre" "$DESTINO/$nombre.bak-$(date +%Y%m%d-%H%M%S)"
    echo "  (copia anterior guardada como $nombre.bak-…)"
  fi
  ln -sfn "${dir%/}" "$DESTINO/$nombre"
  echo "✓ $nombre → $DESTINO/$nombre"
done
echo "Listo. En Claude Code aparecen como skills; para otros agentes usa el PROMPT.md de cada herramienta."
