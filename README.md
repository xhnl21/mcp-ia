# 🧠 mcp-ia (Memoria Local de Conocimiento & Servidor MCP)

Sistema de **memoria persistente local** y **servidor MCP (Model Context Protocol)** multiplataforma (Windows, Mac y Linux) para minimizar el consumo de tokens en tu IDE con IA (Antigravity, VS Code, Claude Desktop, Cursor, etc.) enfocado en **Flutter/Dart**.

La idea central: **buscar primero en tu propia base local de soluciones, y solo recurrir a la IA si no existe una respuesta local**. Cada vez que la IA resuelve un error nuevo, lo guarda directamente a través del servidor MCP, de modo que el sistema "aprende" y ahorra tokens de forma progresiva y automatizada.

- **100% offline y multiplataforma** para todo lo esencial (búsqueda local, almacenamiento, reportes).
- Compatible con **Windows, Mac y Linux** usando codificación nativa en UTF-8.
- Búsqueda **instantánea** (<100 ms) impulsada por SQLite FTS5 y fuzzy matching (`rapidfuzz`).
- **Limpieza de Stack Traces** integrada para extraer el error central y evitar ruidos en la búsqueda.
- **Sincronización** mediante JSON para compartir conocimientos entre múltiples miembros de un equipo.

---

## 📦 Estructura del Repositorio

```
mcp-ia/
├── bin/                    # Acceso rápido (fm.cmd / fm.ps1 para el PATH de Windows)
├── data/
│   ├── flutter_memory.db   # Base SQLite (se crea sola en el primer arranque)
│   ├── sync/               # Archivo json para la sincronización compartida
│   └── backups/            # Backups automáticos de seguridad
├── docs/                   # Guías detalladas de uso, schema y categorías
├── knowledge/              # Notas manuales en Markdown
└── scripts/                # Código fuente en Python
    ├── db.py               # Schema y conexión SQLite (modo WAL)
    ├── search.py           # Motor de búsqueda (FTS5 + RapidFuzz + Frecuencia)
    ├── manager.py          # Operaciones de base de datos y reporte
    ├── importers.py        # Importadores en línea (Stack Overflow, GitHub, Docs)
    ├── learn.py            # Aprendizaje continuo y auto-captura (con parser)
    ├── cleaning.py         # El "lavadero de juguetes": parser y limpiador de stack traces
    ├── mcp_server.py       # Servidor MCP zero-dependency (stdio JSON-RPC)
    ├── sync.py             # Sincronización del cofre de conocimiento
    ├── backup.py           # Copias de seguridad automáticas
    ├── setup.py            # Instalación de dependencias
    └── fm.py               # CLI principal
```

---

## 🚀 Instalación y Setup

Requisito: Python 3.9+ (instalado y en el PATH del sistema).

### 1. Inicialización de la Base de Datos, Dependencias y Registro MCP
Abre una terminal en la carpeta del repositorio y ejecuta el script de configuración:

**En Windows:**
```powershell
py scripts/setup.py --path
```

**En Mac y Linux:**
```bash
python3 scripts/setup.py
```

*Nota: El argumento `--path` en Windows añade la carpeta `bin/` al PATH de tu usuario para que puedas usar el comando corto `fm` desde cualquier consola.*

**¿Qué hace este script automáticamente?**
1. Instala las dependencias necesarias (`rapidfuzz`, `requests`).
2. Inicializa la base de datos SQLite y carga los datos de prueba iniciales (seed).
3. **Registra automáticamente el servidor MCP en el IDE** creando el archivo `mcp_config.json` en dos lugares clave para una integración transparente:
   - **Localmente** en tu espacio de trabajo: `.agents/mcp_config.json`
   - **Globalmente** para Antigravity: `~/.gemini/config/mcp_config.json` (en Windows: `C:\Users\tu_usuario\.gemini\config\mcp_config.json`).

---

## 🔌 Configuración del Servidor MCP (Manual)

Si necesitas registrarlo manualmente en algún otro cliente de IA (como Claude Desktop o Cursor), el servidor [`mcp_server.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/mcp_server.py) se comunica a través de la entrada y salida estándar (`stdio`) en formato JSON-RPC UTF-8.

Añade la siguiente sección a la configuración de tu cliente MCP:

```json
{
  "mcpServers": {
    "mcp-ia": {
      "command": "python",
      "args": ["c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/mcp_server.py"],
      "env": {}
    }
  }
}
```
*(En Mac/Linux asegúrate de usar `"python3"` y la ruta de archivo absoluta equivalente).*

Al cargarse, la IA tendrá acceso a las siguientes herramientas automáticas:
1. `search_solutions`: Busca respuestas locales usando el limpiador de logs.
2. `add_solution`: Permite a la IA guardar una nueva solución cuando resuelva algo útil.
3. `record_usage`: Incrementa la prioridad de una solución existente al confirmarse que funcionó.
4. `get_report`: Obtiene estadísticas de errores del desarrollador.

---

## 🔍 Uso del CLI Diario

Si tienes el comando en el PATH, puedes escribir directamente `fm`. De lo contrario, ejecuta `py scripts/fm.py` (Windows) o `python3 scripts/fm.py` (Mac/Linux).

```bash
# Buscar una solución localmente (¡cero tokens!)
fm busca "MissingPluginException"
fm busca "LateInitializationError" --cat runtime

# Indicar que una solución te funcionó (incrementa su relevancia)
fm usar <ID_DE_SOLUCION>

# Ver qué errores ocurren más seguido y qué te ha ahorrado más tokens
fm reporte

# Aprendizaje y auto-captura (limpia el error y busca o importa de Stack Overflow)
py scripts/learn.py "MissingPluginException: No implementation found for method getAll" --auto-import
```

---

## 🤝 Sincronización del Conocimiento (`sync.py`)

**Entre tus máquinas (Mac, Windows…), en un paso:**

```bash
sh scripts/sincronizar.sh        # macOS / Linux
scripts\sincronizar.bat          # Windows
git push
```

Trae `origin`, mezcla con tu base local el `data/sync/compartido.json` de git **y la copia de Google Drive** (sin duplicados: compara un hash del contenido), avanza la rama, exporta la unión y hace commit. Ejecútalo **al empezar y al terminar** cada sesión en una máquina. Los ids (`#172`…) son **locales de cada máquina**: para citar una solución entre máquinas, usa su título.

| Punto de encuentro | Quién lo usa | Cómo se actualiza |
|---|---|---|
| `data/sync/compartido.json` en git | Todo el que clona mcp-ia (principal) | `sincronizar` + `git push` |
| [Copia en Google Drive](https://drive.google.com/file/d/1728stc7O7fLAZ_N6FWBKsCvkapYIc1Hp/view) (`FM_DRIVE_ID`) | Quien no tiene el repo | Se **lee** sola en `sincronizar`. Para **subirla**: en Drive, clic derecho en el archivo → *Administrar versiones* → *Subir nueva versión* con tu `data/sync/compartido.json` (conserva el enlace y el id). Con Google Drive para escritorio, apunta `FM_SYNC_FILE` a ese archivo y `sync.py subir` lo actualiza solo |

**Agentes de IA:** la regla compartida `kit-agentes/compartido/reglas/regla-de-oro-mcp-ia.md` (enlazada en Claude Code y Antigravity con `enlazar_compartido`) les indica ejecutar `sincronizar` al empezar y al terminar, y avisar a la persona si falta el `git push` o subir la copia a Drive (un agente no puede reemplazar el contenido de un archivo de Drive).

**A mano:**

Para compartir los errores aprendidos con tus compañeros de equipo:

```bash
# Subir tu conocimiento local al archivo compartido común
py scripts/sync.py subir

# Descargar las soluciones compartidas por otros y mezclarlas con tu base de datos
py scripts/sync.py bajar
```
Puedes configurar la variable de entorno `FM_SYNC_FILE` para apuntar a una carpeta compartida en tu red local (o OneDrive/Dropbox) o `FM_SYNC_URL` para leer de un servidor HTTP/Gist público.
