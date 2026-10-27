#!/bin/sh
# Compatibilidad: ahora lo hace kit-agentes/enlazar_compartido.sh (reglas + herramientas, Claude y Antigravity).
exec sh "$(dirname "$0")/../enlazar_compartido.sh" "$@"
