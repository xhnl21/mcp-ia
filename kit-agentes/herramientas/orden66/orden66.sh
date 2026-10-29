#!/usr/bin/env bash
# ==============================================================================
# orden66.sh — respalda, sube todo a GitHub y borra la carpeta de proyectos.
#
#   1. Sincroniza la base de mcp-ia (scripts/sincronizar.sh).
#   2. Cada proyecto con repositorio: commit de lo pendiente (con sus hooks,
#      nunca --no-verify) y push.
#   3. Proyectos sin repositorio: se copian, sin builds ni secretos, a
#      <repo anfitrión>/orden66/<proyecto> y se suben con ese repositorio.
#   4. Llaves y secretos que git no guarda (.jks, key.properties, .env,
#      credenciales de Google/FCM, .mcp.json, respaldos…) más ~/keystores: un
#      .tar.gz cifrado (AES-256, PBKDF2 600 000) que se sube a Google Drive con
#      rclone y se comprueba.
#   5. Solo si todo lo anterior salió bien: borra la carpeta de proyectos,
#      después de escribir «ORDEN 66» en una terminal.
#
# Permisos: cualquier agente de IA puede ejecutarlo (pasos 1-4). El borrado
# exige escribir la frase en una terminal interactiva (/dev/tty): un agente no
# la tiene, así que nunca puede borrar.
#
# Uso:
#   orden66.sh              # pasos 1-4 y, al final, pregunta si borrar
#   orden66.sh --sin-borrar # pasos 1-4; no borra
#   orden66.sh --simular    # muestra lo que haría; no cambia nada
#
# Requisitos (una vez):
#   brew install rclone
#   rclone config           # remoto «drive» de tipo Google Drive
#
# Frase de cifrado: se pide al ejecutar (no se guarda en ningún lado). Sin
# terminal se puede pasar en ORDEN66_FRASE.
#
# Variables opcionales:
#   ORDEN66_RAIZ      carpeta de proyectos (/Users/programacion/Documents/sheets)
#   ORDEN66_ANFITRION repo que guarda los proyectos sin repositorio (mcp-ia)
#   ORDEN66_REMOTO    remoto de rclone (drive)
#   ORDEN66_CARPETA   carpeta en Drive («FurionSystem - Respaldos orden66»)
# ==============================================================================
[ -n "$BASH_VERSION" ] || exec bash "$0" "$@"
set -uo pipefail

RAIZ="${ORDEN66_RAIZ:-/Users/programacion/Documents/sheets}"
ANFITRION="${ORDEN66_ANFITRION:-mcp-ia}"
REMOTO="${ORDEN66_REMOTO:-drive}"
CARPETA_DRIVE="${ORDEN66_CARPETA:-FurionSystem - Respaldos orden66}"
LLAVES_LOCALES="$HOME/keystores"
SELLO="$(date +%Y-%m-%d_%H%M)"
FRASE_BORRADO="ORDEN 66"

MODO="completo"
case "${1:-}" in
  "") ;;
  --sin-borrar) MODO="sin-borrar" ;;
  --simular) MODO="simular" ;;
  -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
  *) echo "Opción desconocida: $1 (usa --sin-borrar, --simular o --help)"; exit 64 ;;
esac

# Si el script vive dentro de la carpeta que va a borrar, se ejecuta desde una
# copia temporal (bash lee el archivo mientras corre).
SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
case "$SCRIPT" in
  "$RAIZ"/*)
    if [ -z "${ORDEN66_COPIA:-}" ]; then
      COPIA="$(mktemp -t orden66).sh"
      cp "$SCRIPT" "$COPIA"
      ORDEN66_COPIA=1 exec bash "$COPIA" "$@"
    fi ;;
esac

ERRORES=0
paso() { printf '\n\033[1;36m━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
aviso(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
fallo(){ printf '  \033[31m✗\033[0m %s\n' "$*"; ERRORES=$((ERRORES + 1)); }
simula(){ [ "$MODO" = "simular" ]; }

# Lo que nunca se copia ni se respalda: builds y archivos que se regeneran.
BASURA='(^|/)(build|\.dart_tool|dist|doc|node_modules|\.gradle|\.idea|\.kotlin|\.cxx|Pods|\.symlinks|\.widget_preview|ephemeral|coverage|venv|\.venv|__pycache__|lotes)(/|$)|/Flutter/|android/app/src/main/java/|gradle-wrapper\.jar$|gradlew(\.bat)?$|\.flutter-plugins|local\.properties$|Generated\.xcconfig$|flutter_export_environment\.sh$|\.DS_Store$|\.iml$|\.log$|\.pyc$|icono_vista_previa\.png$|splash_cuadro_.*\.png$'
# Secretos: nunca van a git; van al respaldo cifrado.
SECRETOS='(^|/)(\.env(\..*)?|key\.properties|\.mcp\.json|token\.json|client_secret[^/]*\.json|google-services[^/]*\.json|GoogleService-Info\.plist|fcm[^/]*\.json|credencial[^/]*\.js|[^/]*\.(jks|keystore|p12|pem|key))$|(^|/)(respaldo_tecnico|respaldos|\.claude)/|(^|/)data/[^/]*\.db(-shm|-wal)?$'
MAX_BYTES=$((50 * 1024 * 1024))

# ─── 0. Comprobaciones ────────────────────────────────────────────────────────
paso "Comprobaciones"
[ -d "$RAIZ" ] || { echo "No existe $RAIZ"; exit 1; }
case "$RAIZ" in /|"$HOME"|"$HOME/"|/Users|/Users/*/Documents) echo "RAIZ peligrosa: $RAIZ"; exit 1 ;; esac
for herramienta in git openssl tar rclone rsync; do
  command -v "$herramienta" >/dev/null || { echo "Falta $herramienta"; exit 1; }
done
if ! rclone listremotes 2>/dev/null | grep -qx "$REMOTO:"; then
  if simula; then
    aviso "rclone aún no tiene el remoto «${REMOTO}» (ejecuta «rclone config»)"
  else
    echo "rclone no tiene el remoto «${REMOTO}»: ejecuta «rclone config» (tipo drive)."
    exit 1
  fi
fi
ok "Carpeta: $RAIZ · Drive: $REMOTO:$CARPETA_DRIVE · modo: $MODO"

PROYECTOS=()
CON_REPO=()
SIN_REPO=()
for d in "$RAIZ"/*/; do
  d="${d%/}"; n="$(basename "$d")"
  PROYECTOS+=("$n")
  if git -C "$d" rev-parse --show-toplevel 2>/dev/null | grep -qx "$d" &&
     git -C "$d" remote get-url origin >/dev/null 2>&1; then
    CON_REPO+=("$n")
  else
    SIN_REPO+=("$n")
  fi
done
ok "Con repositorio: ${CON_REPO[*]:-ninguno}"
ok "Sin repositorio: ${SIN_REPO[*]:-ninguno}"
if [ "${#SIN_REPO[@]}" -gt 0 ] && [[ ! " ${CON_REPO[*]} " == *" $ANFITRION "* ]]; then
  echo "El repositorio anfitrión «${ANFITRION}» no existe o no tiene remoto."
  exit 1
fi

# ─── 1. Base de mcp-ia ────────────────────────────────────────────────────────
paso "Sincronizar mcp-ia"
if [ -x "$RAIZ/mcp-ia/scripts/sincronizar.sh" ] || [ -f "$RAIZ/mcp-ia/scripts/sincronizar.sh" ]; then
  if simula; then ok "(simulado) sh mcp-ia/scripts/sincronizar.sh"
  elif sh "$RAIZ/mcp-ia/scripts/sincronizar.sh" >/dev/null 2>&1; then ok "Base sincronizada"
  else fallo "sincronizar.sh falló"; fi
else
  aviso "No hay mcp-ia/scripts/sincronizar.sh"
fi

# ─── 2. Proyectos sin repositorio → anfitrión ─────────────────────────────────
if [ "${#SIN_REPO[@]}" -gt 0 ]; then
  paso "Proyectos sin repositorio → $ANFITRION/orden66/"
  for n in "${SIN_REPO[@]}"; do
    destino="$RAIZ/$ANFITRION/orden66/$n"
    if simula; then ok "(simulado) $n → $destino"; continue; fi
    mkdir -p "$destino"
    # Sin builds (se regeneran) ni secretos (van cifrados a Drive), y sin
    # carpetas .git anidadas.
    if (cd "$RAIZ/$n" && find . -type f ! -path '*/.git/*' | sed 's|^\./||' |
          grep -Ev "$BASURA" | grep -Ev "$SECRETOS" |
          rsync -a --files-from=- . "$destino/"); then
      ok "$n copiado ($(du -sh "$destino" | cut -f1))"
    else
      fallo "No se pudo copiar $n"
    fi
  done
fi

# ─── 3. Commit y push ─────────────────────────────────────────────────────────
paso "Commit y push"
for n in "${CON_REPO[@]}"; do
  d="$RAIZ/$n"
  rama="$(git -C "$d" symbolic-ref --short -q HEAD)" || { fallo "$n: HEAD separado"; continue; }
  # Un secreto que git todavía no ignora no se sube: se avisa y se para.
  sueltos="$(git -C "$d" status --porcelain -uall | sed -n 's/^?? //p' | grep -E "$SECRETOS" || true)"
  if [ -n "$sueltos" ]; then
    fallo "$n: secretos sin ignorar (agrégalos a .gitignore): $(echo "$sueltos" | tr '\n' ' ')"
    continue
  fi
  if [ -n "$(git -C "$d" status --porcelain)" ]; then
    if simula; then ok "(simulado) $n: commit de $(git -C "$d" status --porcelain | wc -l | tr -d ' ') cambios"
    else
      git -C "$d" add -A
      if git -C "$d" commit -s -q -m "chore(orden66): respaldo automático $SELLO"; then
        ok "$n: commit hecho"
      else
        fallo "$n: el commit falló (revisa sus hooks)"; continue
      fi
    fi
  fi
  if simula; then ok "(simulado) $n: git push origin $rama"; continue; fi
  if git -C "$d" push -q origin "$rama" 2>/dev/null; then
    git -C "$d" fetch -q origin "$rama" 2>/dev/null
    pendientes="$(git -C "$d" rev-list --count "origin/$rama..HEAD" 2>/dev/null || echo 1)"
    if [ "$pendientes" = "0" ] && [ -z "$(git -C "$d" status --porcelain)" ]; then
      ok "$n: subido ($rama)"
    else
      fallo "$n: quedan commits o cambios sin subir"
    fi
  else
    fallo "$n: git push falló"
  fi
done

# ─── 4. Llaves y secretos → Drive (cifrado) ───────────────────────────────────
paso "Respaldo cifrado de llaves y secretos"
LISTA="$(mktemp -t orden66-lista)"
for n in "${PROYECTOS[@]}"; do
  d="$RAIZ/$n"
  if git -C "$d" rev-parse >/dev/null 2>&1; then
    (cd "$d" && git ls-files -o -i --exclude-standard)
  else
    (cd "$d" && find . -type f ! -path '*/.git/*' | sed 's|^\./||')
  fi | grep -Ev "$BASURA" | grep -E "$SECRETOS" | sed "s|^|$n/|"
done | while read -r f; do
  tam=$(stat -f %z "$RAIZ/$f" 2>/dev/null || echo 0)
  if [ "$tam" -gt "$MAX_BYTES" ]; then echo "  ! $f supera 50 MB: no se respalda" >&2
  else echo "$f"; fi
done > "$LISTA"
ok "$(wc -l < "$LISTA" | tr -d ' ') archivos de los proyectos$( [ -d "$LLAVES_LOCALES" ] && echo " + ~/keystores")"
sed 's/^/      /' "$LISTA"

ARCHIVO="orden66-secretos-$SELLO.tar.gz.enc"
TMP="$(mktemp -d -t orden66)"
if simula; then
  ok "(simulado) $ARCHIVO → $REMOTO:$CARPETA_DRIVE/"
else
  FRASE="${ORDEN66_FRASE:-}"
  if [ -z "$FRASE" ]; then
    if { exec 3</dev/tty; } 2>/dev/null; then
      read -r -s -p "  Frase para cifrar el respaldo: " FRASE <&3; echo
      read -r -s -p "  Repítela: " FRASE2 <&3; echo
      exec 3<&-
      [ "$FRASE" = "$FRASE2" ] || { echo "  Las frases no coinciden."; exit 1; }
    else
      echo "  Sin terminal: pasa la frase en ORDEN66_FRASE."; exit 1
    fi
  fi
  [ -n "$FRASE" ] || { echo "  La frase no puede estar vacía."; exit 1; }
  mkdir -p "$TMP/orden66/proyectos"
  rsync -a --files-from="$LISTA" "$RAIZ/" "$TMP/orden66/proyectos/"
  [ -d "$LLAVES_LOCALES" ] && cp -Rp "$LLAVES_LOCALES" "$TMP/orden66/keystores"
  cat > "$TMP/orden66/LEEME.txt" <<EOF
Respaldo de orden66.sh ($SELLO).
proyectos/<proyecto>/<ruta>: cada archivo va de vuelta a esa ruta del proyecto.
keystores/: copia de ~/keystores.
Descifrar: openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in $ARCHIVO | tar -xzf -
EOF
  tar -czf "$TMP/secretos.tar.gz" -C "$TMP" orden66
  FRASE="$FRASE" openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
    -in "$TMP/secretos.tar.gz" -out "$TMP/$ARCHIVO" -pass env:FRASE
  # Antes de subir: que se descifre igual.
  if FRASE="$FRASE" openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
       -in "$TMP/$ARCHIVO" -pass env:FRASE | cmp -s - "$TMP/secretos.tar.gz"; then
    ok "Cifrado y comprobado ($(du -h "$TMP/$ARCHIVO" | cut -f1))"
  else
    fallo "El archivo cifrado no se descifra igual"
  fi
  unset FRASE FRASE2
  if [ "$ERRORES" -eq 0 ] &&
     rclone copy "$TMP/$ARCHIVO" "$REMOTO:$CARPETA_DRIVE/" &&
     rclone check --one-way "$TMP" "$REMOTO:$CARPETA_DRIVE/" \
       --include "$ARCHIVO" >/dev/null 2>&1; then
    ok "Subido y verificado en Drive: $CARPETA_DRIVE/$ARCHIVO"
  else
    fallo "No se pudo subir o verificar el respaldo en Drive"
  fi
fi
rm -rf "${TMP:?}" "${LISTA:?}"

# ─── 5. Borrado ───────────────────────────────────────────────────────────────
paso "Resultado"
if [ "$ERRORES" -gt 0 ]; then
  echo "  $ERRORES problema(s): NO se borra nada. Corrígelos y vuelve a ejecutar."
  exit 1
fi
ok "Todo respaldado y subido."
case "$MODO" in
  simular) echo "  (simulado) Aquí preguntaría si borrar $RAIZ."; exit 0 ;;
  sin-borrar) echo "  --sin-borrar: $RAIZ queda intacta."; exit 0 ;;
esac

# Solo una persona en una terminal puede confirmar: sin /dev/tty (un agente
# de IA) no se borra nunca.
if ! { exec 3</dev/tty; } 2>/dev/null; then
  echo "  Sin terminal interactiva: no se borra (solo una persona puede confirmarlo)."
  exit 0
fi
printf '\n  \033[1;31mSe borrará %s y todo su contenido. No se puede deshacer.\033[0m\n' "$RAIZ"
read -r -p "  Escribe «${FRASE_BORRADO}» para continuar: " RESPUESTA <&3
exec 3<&-
if [ "$RESPUESTA" != "$FRASE_BORRADO" ]; then
  echo "  Cancelado: no se borró nada."
  exit 0
fi
cd "$HOME" || exit 1
rm -rf "${RAIZ:?}"
[ -e "$RAIZ" ] && { echo "  No se pudo borrar todo $RAIZ"; exit 1; }
ok "$RAIZ borrada. Los proyectos están en GitHub y los secretos en Drive."
