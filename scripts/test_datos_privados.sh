#!/bin/sh
# Prueba de revisar_datos_privados.sh: lo que parece real falla, lo inventado pasa.
# Todos los datos de aquí son inventados.
cd "$(dirname "$0")" || exit 1
fallos=0
debe_fallar() { printf '%s\n' "$1" | sh revisar_datos_privados.sh >/dev/null && { echo "NO falló: $1"; fallos=1; }; return 0; }
debe_pasar()  { printf '%s\n' "$1" | sh revisar_datos_privados.sh >/dev/null || { echo "falló sin deber: $1"; fallos=1; }; return 0; }
debe_fallar 'emisor ("V20481357")'
debe_fallar 'cliente J-30481256-7'
debe_fallar 'llamar al +58 412 3456789'
debe_fallar 'llamar al 04141357924'
debe_fallar 'escribe a maria.perez@gmail.com'
debe_pasar 'validar V12345678 y E-1234567'
debe_pasar 'ana@example.com y git@gitlab.com'
debe_pasar 'hash 095497908629c4e94a367769'
debe_pasar 'sha 009c73ae10f5b8056b40fb1218d2b1acf1050974'
exit $fallos
