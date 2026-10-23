# Kit del jefe maestro (agentes delegados + mcp-ia)

Configura un proyecto para que la IA del editor actúe como **jefe maestro**: escribe tareas, las delega en Antigravity (`agy`) u OpenCode (`opencode`), las revisa y convierte cada error en una lección compartida entre proyectos a través de la base `mcp-ia`.

**La forma más fácil:** abre tu proyecto con tu IA y pégale [PROMPT_CONFIGURAR_KIT.md](PROMPT_CONFIGURAR_KIT.md). Ella ejecuta todo esto por ti.

## Requisitos

- `git` y Python 3.9 o superior (`python3` en macOS/Linux; `py -3` o `python` en Windows).
- Antigravity CLI (`agy`) con sesión iniciada. OpenCode es opcional.

## Uso manual

| Paso | macOS / Linux | Windows |
|---|---|---|
| 1. Instalar en un proyecto | `sh instalar.sh <proyecto> --prefijo XX --carpetas "lib test docs"` | `instalar.bat <proyecto> --prefijo XX --carpetas "lib test docs"` |
| 2. Registrar la base mcp-ia | `sh registrar_mcp.sh <proyecto>` | `registrar_mcp.bat <proyecto>` |
| 3. Permisos de Antigravity (los ejecutas tú) | `sh permisos_agy.sh <proyecto> --ver` y después sin `--ver` | `permisos_agy.bat <proyecto> --ver` y después sin `--ver` |
| 4. Verificar | `sh verificar.sh <proyecto>` | `verificar.bat <proyecto>` |
| Delegar una tarea (desde el proyecto) | `sh .agents/prompts/delegar.sh agy tarea.md nombre` | `.agents\prompts\delegar.bat agy tarea.md nombre` |

`--solo-prompt` en `delegar` arma el prompt en `.agents/prompts/lotes/` sin lanzar el agente.

## Qué contiene

- `kit_agentes.py`: toda la lógica, solo biblioteca estándar. Los `.sh` y `.bat` son atajos que lo llaman.
- `plantillas/`: `REGLAS.md`, `PLANTILLA_TAREA.md`, `REVISION.md`, `LECCIONES_AGENTES.md` y la sección para `AGENTS.md`.
- `proyecto/`: los atajos `delegar` y `permisos_agy` que se copian en cada proyecto.
- `lecciones.py`: guarda y exporta las lecciones de los agentes en `mcp-ia` (se copia en `mcp-ia/scripts` si falta).

## Qué no toca

- No agrega permisos generales a Antigravity (`write_file(*)`, `command(*)`) ni comandos que modifiquen el repositorio.
- Guarda una copia de seguridad (`.bak-<fecha>`) de cada configuración global que cambia.
- `.mcp.json`, `.agents/prompts/kit.json` y los registros de lotes llevan rutas locales: quedan fuera de git.
- En Windows, y con prompts de más de 24.000 caracteres, `delegar` le pasa al agente la ruta del `prompt.md` en lugar del texto, por el límite de la línea de comandos.
