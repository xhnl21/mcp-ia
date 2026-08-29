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

### 1. Inicialización de la Base de Datos y dependencias
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

---

## 🔌 Configuración del Servidor MCP (Integración con la IA)

El servidor [`mcp_server.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/mcp_server.py) se comunica a través de la entrada y salida estándar (`stdio`) en formato JSON-RPC UTF-8, haciéndolo compatible de forma nativa con los clientes de IA en **Windows, Mac y Linux**.

### Registro en el IDE (Antigravity / VS Code / Cursor)
Edita el archivo de configuración de MCP (ej: `.agents/mcp_config.json` en tu espacio de trabajo o el archivo global de configuración) y añade la entrada del servidor apuntando a la ruta absoluta:

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
*(En Mac/Linux asegúrate de cambiar `python` por `python3` y actualizar la ruta absoluta de los argumentos al estilo `/Users/tu_usuario/...`).*

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

Para compartir los errores aprendidos con tus compañeros de equipo:

```bash
# Subir tu conocimiento local al archivo compartido común
py scripts/sync.py subir

# Descargar las soluciones compartidas por otros y mezclarlas con tu base de datos
py scripts/sync.py bajar
```
Puedes configurar la variable de entorno `FM_SYNC_FILE` para apuntar a una carpeta compartida en tu red local (o OneDrive/Dropbox) o `FM_SYNC_URL` para leer de un servidor HTTP/Gist público.
