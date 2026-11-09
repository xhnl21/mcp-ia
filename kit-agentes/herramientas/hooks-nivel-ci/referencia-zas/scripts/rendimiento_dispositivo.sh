#!/bin/sh
# ==============================================================================
# Prueba de rendimiento por módulo en un dispositivo, con log y informe.
#
#   sh scripts/rendimiento_dispositivo.sh <dispositivo> [segundos_observacion]
#
# Antes: la app (variante dev) instalada en el dispositivo con una sesión
# abierta. Corre integration_test/rendimiento_por_modulo_test.dart en modo
# profile con los logs de la app encendidos (ACTIVE_LOG=true), guarda el log
# del dispositivo con horas y deja en build/rendimiento/:
#   <dispositivo>_<fecha>.json   informe crudo
#   <dispositivo>_<fecha>.md     tabla por módulo, sin medir y sesión
#   <dispositivo>_<fecha>.log    log del dispositivo (flutter) con horas
#   <dispositivo>_<fecha>.drive  salida de flutter drive
# ==============================================================================
set -u
DISPOSITIVO="${1:-}"
OBSERVAR="${2:-90}"
if [ -z "$DISPOSITIVO" ]; then
  echo "Uso: sh scripts/rendimiento_dispositivo.sh <dispositivo> [segundos_observacion]"
  echo "Dispositivos conectados:"
  adb devices
  exit 1
fi
[ -x .fvm/flutter_sdk/bin/flutter ] && PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" && export PATH
command -v adb >/dev/null 2>&1 || PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"

SALIDA=build/rendimiento
mkdir -p "$SALIDA"
BASE="$SALIDA/${DISPOSITIVO}_$(date +%Y%m%d_%H%M%S)"

adb -s "$DISPOSITIVO" logcat -c
adb -s "$DISPOSITIVO" logcat -v time 'flutter:V' '*:S' > "$BASE.log" &
LOGCAT=$!
trap 'kill $LOGCAT 2>/dev/null' EXIT

rm -f build/integration_response_data.json
# --no-dds: con DDS, watchPerformance no conecta con la VM.
# --keep-app-running: sin él, flutter drive desinstala la app y borra la sesión.
flutter drive --profile --no-dds --keep-app-running \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/rendimiento_por_modulo_test.dart \
  -d "$DISPOSITIVO" --flavor dev --dart-define-from-file .env.dev \
  --dart-define=ACTIVE_LOG=true \
  --dart-define=RENDIMIENTO_OBSERVAR_S="$OBSERVAR" > "$BASE.drive" 2>&1
RESULTADO=$?

if [ ! -f build/integration_response_data.json ]; then
  echo "❌ La prueba no dejó informe. Revisa $BASE.drive"
  exit 1
fi
cp build/integration_response_data.json "$BASE.json"
dart run scripts/rendimiento_informe.dart "$BASE.json" "Rendimiento en $DISPOSITIVO" > "$BASE.md"
cat "$BASE.md"
echo ""
echo "Informe: $BASE.md · log: $BASE.log · drive: $BASE.drive"
# La APK que deja drive es la de la prueba (ignora los toques): para usar la
# app hay que reinstalar la normal.
echo "Ojo: en el dispositivo quedó la APK de la prueba; reinstala la app para usarla."
exit $RESULTADO
