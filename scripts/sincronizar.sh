#!/bin/sh
# ==============================================================================
# sincronizar.sh — une la base local de mcp-ia con la de las otras máquinas.
#
# Cada máquina tiene su propia base (data/flutter_memory.db, fuera de git) y
# numera sus soluciones por su cuenta. El punto de encuentro es
# data/sync/compartido.json, que sí va en git. Este script:
#   1. trae origin (git fetch);
#   2. importa el compartido.json remoto a la base local (sin duplicados: se
#      compara un hash del contenido, no el id);
#   3. avanza la rama (git pull --ff-only);
#   4. exporta la unión a compartido.json y hace commit si cambió.
# Después: git push (lo hace la persona, no el script).
#
# Ojo: los ids (#172…) son locales de cada máquina. Para citar una solución
# entre máquinas, usa su título.
# ==============================================================================
set -e
cd "$(dirname "$0")/.."

ARCHIVO="data/sync/compartido.json"
REMOTO="data/sync/_remoto.json"

if [ -n "$(git status --porcelain -- "$ARCHIVO")" ]; then
  echo "❌ $ARCHIVO tiene cambios sin commit. Haz commit o descártalos antes." >&2
  exit 1
fi

echo "⬇️  git fetch…"
git fetch -q origin
RAMA=$(git rev-parse --abbrev-ref HEAD)

if git cat-file -e "origin/$RAMA:$ARCHIVO" 2>/dev/null; then
  git show "origin/$RAMA:$ARCHIVO" > "$REMOTO"
  echo "🔀 Importando el compartido.json remoto a la base local…"
  python3 scripts/sync.py bajar "$REMOTO"
  rm -f "$REMOTO"
fi

echo "⏩ git pull --ff-only…"
if ! git pull -q --ff-only origin "$RAMA"; then
  echo "❌ La rama local y origin divergieron. Resuélvelo (git pull) y vuelve a ejecutar." >&2
  exit 1
fi

echo "⬆️  Exportando la unión a ${ARCHIVO}…"
python3 scripts/sync.py subir >/dev/null
TOTAL=$(python3 -c "import json; print(len(json.load(open('$ARCHIVO', encoding='utf-8'))))")

if [ -n "$(git status --porcelain -- "$ARCHIVO")" ]; then
  git add "$ARCHIVO"
  git commit -q -s -m "chore(sync): compartir conocimiento ($TOTAL soluciones)" -- "$ARCHIVO"
  echo "✅ Commit hecho ($TOTAL soluciones). Falta: git push"
else
  echo "✅ Sin cambios: $TOTAL soluciones, igual que origin."
fi
