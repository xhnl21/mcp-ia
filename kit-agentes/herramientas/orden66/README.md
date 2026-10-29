# orden66

Respalda y sube todos los proyectos de `~/Documents/sheets` y, si una persona lo confirma, borra la carpeta.

1. Sincroniza la base de mcp-ia.
2. Hace commit (con hooks) y push de cada repositorio.
3. Copia los proyectos sin repositorio a `mcp-ia/orden66/<proyecto>`, sin builds ni secretos.
4. Cifra las llaves y los secretos que git no guarda, sube el archivo a Google Drive y comprueba la subida.
   - Qué entra: `.jks`, `key.properties`, `.env*`, credenciales de Google y FCM, `.mcp.json`, `respaldos/` y `~/keystores`.
   - Dónde queda: «FurionSystem - Respaldos orden66».
5. Solo si no hubo ningún error, pide escribir `ORDEN 66` en una terminal y borra la carpeta.

## Instalación (una vez por máquina)

```sh
brew install rclone
rclone config                 # crea el remoto «drive» (tipo Google Drive) y autoriza en el navegador
mkdir -p ~/bin && cp kit-agentes/herramientas/orden66/orden66.sh ~/bin/ && chmod +x ~/bin/orden66.sh
```

El script vive en `~/bin`, fuera de la carpeta que borra.

## Uso

```sh
~/bin/orden66.sh --simular     # muestra lo que haría; no cambia nada
~/bin/orden66.sh --sin-borrar  # respalda, hace commit y sube; no borra
~/bin/orden66.sh               # todo y, al final, pide «ORDEN 66» para borrar
```

La frase de cifrado se pide al ejecutar y no se guarda. Sin terminal, se puede pasar en `ORDEN66_FRASE`. Para descifrar el respaldo:

```sh
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in <archivo> | tar -xzf -
```

## Agentes de IA

- **Pueden ejecutar** `--simular` y `--sin-borrar` sin pedir permiso. En Claude Code ya están en `permissions.allow` de `~/.claude/settings.json`.
- **No deben borrar.** La ejecución completa está en `permissions.ask`. Además, el borrado exige escribir la frase en una terminal interactiva, que un agente no tiene.
- **Nunca** deben simular esa terminal (`expect`, `script`) para llegar al borrado. Esa decisión es de la persona.
- Si algo falla, no se borra nada. El agente informa el error, lo corrige y vuelve a ejecutar.
