# Prompt: configurar el kit del jefe maestro en un proyecto

> **Cómo usarlo:** abre tu proyecto en el editor con tu IA (Claude Code, Antigravity, Cursor…), descomprime `kit-agentes.zip` en cualquier carpeta y pega este prompt completo en el chat. Cambia solo las tres líneas de «Datos».

---

## Datos (complétalos antes de pegar)

- **Ruta del proyecto:** `<ruta absoluta del repositorio git, p. ej. /Users/ana/proyectos/mi_app o C:\proyectos\mi_app>`
- **Ruta donde descomprimí el kit:** `<p. ej. /Users/ana/Descargas/kit-agentes o C:\Users\ana\Downloads\kit-agentes>`
- **Prefijo de lecciones del proyecto:** `<2 o 3 letras en mayúscula, p. ej. MA>`

## Tu tarea

Configura en mi proyecto el **kit del jefe maestro**: tú (la IA del editor) serás el jefe maestro que escribe tareas, las delega en Antigravity (`agy`) u OpenCode (`opencode`), revisa el resultado y hace los commits. Los agentes delegados aprenden de sus errores mediante lecciones compartidas en la base `mcp-ia`.

Responde siempre en español. Ejecuta los pasos en orden, **un comando por llamada**, y después de cada paso muéstrame el resultado en una o dos líneas. Si un paso falla, detente, explícame la causa y no sigas.

En los comandos, `<KIT>` es la ruta del kit y `<PROYECTO>` la del proyecto. En macOS o Linux usa los `.sh` con `sh`; en Windows usa los `.bat`.

### Paso 1. Requisitos

Comprueba, sin instalar nada, que existen y dime sus versiones: `git`, `python3` (en Windows `py -3` o `python`, 3.9 o superior) y `agy`. `opencode` es opcional. Comprueba que `<PROYECTO>` es un repositorio git. Si falta algo, dime cómo instalarlo y detente.

### Paso 2. Elegir las carpetas del agente

Lista las carpetas de primer nivel de `<PROYECTO>` y propónme en cuáles puede **escribir** el agente delegado: solo código y pruebas (por ejemplo `lib test docs` en Flutter, `src test docs` en otros). Nunca la raíz, `.git`, `android/`, `ios/`, `pubspec.yaml`, `package.json`, `.env*` ni carpetas con secretos. **Espera a que confirme la lista.**

### Paso 3. Instalar el kit

- macOS/Linux: `sh <KIT>/instalar.sh <PROYECTO> --prefijo <PREFIJO> --carpetas "<carpetas confirmadas>"`
- Windows: `<KIT>\instalar.bat <PROYECTO> --prefijo <PREFIJO> --carpetas "<carpetas confirmadas>"`

Crea `.agents/prompts/` (reglas, plantilla de tarea, revisión, lecciones, `delegar` y `permisos_agy`), agrega entradas al `.gitignore` y una sección al `AGENTS.md`. Muéstrame qué agregó al `AGENTS.md` y al `.gitignore`.

### Paso 4. Base de soluciones mcp-ia

- macOS/Linux: `sh <KIT>/registrar_mcp.sh <PROYECTO>`
- Windows: `<KIT>\registrar_mcp.bat <PROYECTO>`

Clona `https://github.com/xhnl21/mcp-ia` en `~/mcp-ia` (si no está), instala sus dependencias, importa el conocimiento compartido (soluciones y lecciones de los agentes) y registra el servidor MCP en `.mcp.json` del proyecto (Claude Code) y en `~/.gemini/config/mcp_config.json` (Antigravity). Si ya tengo mcp-ia en otra ruta, agrega `--mcp-ia <ruta>`.

### Paso 5. Permisos de Antigravity

Primero muéstrame qué cambiaría, **sin aplicar**:
- macOS/Linux: `sh <PROYECTO>/.agents/prompts/permisos_agy.sh --ver`
- Windows: `<PROYECTO>\.agents\prompts\permisos_agy.bat --ver`

Explícame cada entrada. **No apliques los permisos tú:** dime el mismo comando sin `--ver` para que yo lo ejecute. Dar permisos a otro agente lo decido yo. El script guarda una copia de seguridad de la configuración de Antigravity y nunca agrega permisos generales (`write_file(*)`, `command(*)`) ni comandos que modifiquen el repositorio.

### Paso 6. Verificar

Cuando te confirme que ejecuté los permisos:
- macOS/Linux: `sh <KIT>/verificar.sh <PROYECTO>`
- Windows: `<KIT>\verificar.bat <PROYECTO>`

Todo debe salir con ✓ (OpenCode es opcional). Después arma un prompt de prueba **sin lanzar el agente**: crea `tarea_prueba.md` con un título y una sección «Alcance» vacía, y ejecuta desde `<PROYECTO>`:
- macOS/Linux: `sh .agents/prompts/delegar.sh agy tarea_prueba.md prueba --solo-prompt`
- Windows: `.agents\prompts\delegar.bat agy tarea_prueba.md prueba --solo-prompt`

Confirma que el `prompt.md` generado incluye las reglas, la sección «Lecciones comunes de otros proyectos (base mcp-ia)» y la tarea. Borra `tarea_prueba.md` al terminar.

### Paso 7. Cómo vas a trabajar desde ahora (guárdalo en tu memoria del proyecto)

1. **Antes de resolver cualquier error**, busca en `mcp-ia` (`search_solutions` con el mensaje de error). Si resuelves uno nuevo, guárdalo con `add_solution`.
2. **Para delegar una tarea:** escríbela con `.agents/prompts/PLANTILLA_TAREA.md` (con «Alcance», «Hechos verificados» y comprobaciones de un comando por línea, sin `&&`, `;` ni `|`). Lánzala con `delegar` **solo cuando yo lo pida** y revísala con `REVISION.md`. Códigos: 2 sin sesión, 3 hizo commits (prohibido), 4 error o permiso negado.
3. **Cada error de un agente se convierte en lección** en `.agents/prompts/LECCIONES_AGENTES.md` con ID `<PREFIJO>-NNN`. `delegar` la guarda en la base y la comparte con los demás proyectos.
4. **Si una tarea usa un paquete nuevo**, copia en el prompt las firmas de su API: el agente no puede leer la caché de paquetes (`~/.pub-cache`, `node_modules` global).
5. **Commits:** con mi identidad de git (`git commit -s`), sin firmas de la IA. No hagas push sin que te lo pida.
6. **Nunca muestres secretos** (`.env*`, claves, contraseñas) ni los subas a git.

### Paso 8. Resumen

Termina con una tabla: paso, resultado (✓ / ✗) y qué queda pendiente de mi lado. No hagas commits todavía: pregúntame.
