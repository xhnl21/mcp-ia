## Flujo de trabajo: jefe maestro y agentes delegados

La IA del editor (Claude Code) actúa como **jefe maestro**: escribe la tarea con `.agents/prompts/PLANTILLA_TAREA.md`, la delega en Antigravity (`agy -p`) u OpenCode (`opencode run`), la revisa con `REVISION.md` y hace los commits. Los agentes delegados no hacen commits, no salen del «Alcance» de la tarea y ejecutan un comando por llamada.

- Delegar: `sh .agents/prompts/delegar.sh agy <tarea.md> [nombre]` (macOS/Linux) o `.agents\prompts\delegar.bat agy <tarea.md> [nombre]` (Windows). Códigos: 2 sin sesión, 3 hizo commits, 4 error o permiso negado. Con `--solo-prompt` arma el prompt sin lanzar el agente.
- Permisos de Antigravity para este proyecto: `permisos_agy.sh` / `permisos_agy.bat` (con `--ver` solo muestra lo que haría).

## Base de soluciones mcp-ia y lecciones compartidas

> **REGLA DE ORO (todos los proyectos, todos los agentes): todo problema resuelto se registra en `mcp-ia` con `add_solution` en el momento de resolverlo, no al final.** Antes de resolver, `search_solutions`. Sin herramientas MCP: `python3 <mcp-ia>/kit-agentes/compartido/mcpia.py`. Una tarea con errores resueltos y sin su registro no está terminada. Texto completo: `<mcp-ia>/kit-agentes/compartido/reglas/regla-de-oro-mcp-ia.md` (enlazado como regla global de Claude Code y Antigravity con `enlazar_compartido`).

- **Antes de resolver un error, consulta `mcp-ia`** (herramienta MCP `search_solutions` con el mensaje de error). Si hay solución, aplícala y márcala con `record_usage`. Si resuelves uno nuevo, guárdalo con `add_solution`.
- **Lecciones de los agentes:** las de este proyecto van en `.agents/prompts/LECCIONES_AGENTES.md` con IDs `{PREFIJO}-001`, `{PREFIJO}-002`… `delegar` las guarda en la base (categoría «agentes») y agrega al prompt las de los demás proyectos.
- El servidor se registra en `.mcp.json` (ruta local, ignorado por git) y en Antigravity (`~/.gemini/config/mcp_config.json`).
