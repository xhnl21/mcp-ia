#!/bin/sh
# ImagineArt es un servidor MCP remoto (https://mcp.imagine.art): no hay nada que arrancar en local.
# Este script lo registra si falta (alcance usuario, sirve para todos los proyectos) y muestra su estado.
# El inicio de sesión (OAuth) solo se puede hacer a mano, en /mcp, en una sesión interactiva.
URL=https://mcp.imagine.art
command -v claude >/dev/null || { echo "❌ No encuentro el comando 'claude'."; exit 1; }

claude mcp get imagine >/dev/null 2>&1 || {
  echo "➕ Registrando imagine (alcance usuario)…"
  claude mcp add --scope user --transport http imagine "$URL" || exit 1
}

claude mcp list 2>/dev/null | grep -i imagine
echo
echo "Si dice «Needs authentication» o no está «Connected»:"
echo "  1) abre una sesión interactiva:  claude"
echo "  2) escribe /mcp, elige imagine y autoriza en el navegador"
echo "  3) abre una sesión NUEVA: las herramientas se cargan al arrancar la sesión"
echo "Si cambiaste de cuenta de Claude, hay que autorizar otra vez (pasa a 'needs to sign in again')."
