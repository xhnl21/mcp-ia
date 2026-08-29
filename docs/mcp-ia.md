# 🔌 Arquitectura del Servidor MCP

Esta página explica cómo funciona el servidor **MCP (Model Context Protocol)** implementado en `mcp-ia` y cómo interactúa de forma directa con la Inteligencia Artificial de tu IDE.

---

## ¿Qué es MCP?

El **Model Context Protocol** (Protocolo de Contexto de Modelo) es un estándar abierto desarrollado por Anthropic que permite a los modelos de lenguaje (como Gemini, Claude, GPT, etc.) conectarse a fuentes de datos locales o herramientas de forma segura y uniforme.

En lugar de que cada IDE implemente extensiones propietarias para cada herramienta, MCP proporciona un protocolo común basado en **JSON-RPC 2.0** que funciona sobre la entrada y salida estándar (`stdin`/`stdout`).

---

## 🛠️ Diseño del Servidor `mcp_server.py`

El servidor [`mcp_server.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/mcp_server.py) está diseñado bajo la filosofía **Zero-Dependency** (cero dependencias externas). Implementa el protocolo JSON-RPC 2.0 usando únicamente la biblioteca estándar de Python (`json`, `sys`, `os`), lo que garantiza:
* **Portabilidad:** Se ejecuta instantáneamente en Windows, Mac y Linux sin requerir instalar el SDK oficial de MCP.
* **Aislamiento:** Al no depender de paquetes complejos, no entra en conflictos de versiones de paquetes de Python en tu sistema.
* **UTF-8 Nativo:** El script reconfigura los canales `stdin` y `stdout` a UTF-8 de forma explícita, evitando bloqueos por caracteres especiales (como emojis o letras con tildes) en la consola de Windows.

---

## 🔄 Flujo de Comunicación (Lifecycle)

Cuando abres tu IDE o inicias una conversación, se realiza la siguiente secuencia de mensajes a nivel de protocolo stdio:

### 1. Inicialización (`initialize`)
El IDE inicia el proceso del servidor Python y le envía una petición para sincronizar capacidades:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "Antigravity", "version": "1.0.0"}
  }
}
```
El servidor responde indicando que es un servidor de herramientas (`tools`):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {"tools": {}},
    "serverInfo": {"name": "mcp-ia", "version": "1.0.0"}
  }
}
```
Posteriormente, el cliente envía la notificación `notifications/initialized` confirmando que la conexión está establecida.

### 2. Descubrimiento de Herramientas (`tools/list`)
El IDE solicita la lista de herramientas disponibles para el Agente:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}
```
El servidor le devuelve las cuatro herramientas con sus firmas de entrada en formato JSON Schema.

### 3. Ejecución de Herramientas (`tools/call`)
Cuando el Agente decide buscar o guardar conocimiento, envía:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "search_solutions",
    "arguments": {
      "query": "MissingPluginException"
    }
  }
}
```
El servidor ejecuta la búsqueda SQLite localmente y devuelve la respuesta al agente en un formato de texto amigable.

---

## 🧰 Herramientas Expuestas

El servidor expone cuatro herramientas fundamentales:

| Herramienta | Argumentos | Descripción |
| :--- | :--- | :--- |
| `search_solutions` | `query` (str), `category` (str), `tag` (str) | Realiza la consulta FTS5 local + fuzzy matching y devuelve las mejores soluciones. |
| `add_solution` | `title` (str), `problem` (str), `solution` (str), `category` (str), `tags` (list), `url` (str) | Añade una solución nueva calculando su hash SHA-256 para evitar duplicados. |
| `record_usage` | `solution_id` (int), `resolved` (bool) | Incrementa las estadísticas de uso de una solución para subir su relevancia en el ranking. |
| `get_report` | *ninguno* | Genera el reporte del CLI con estadísticas de errores comunes y tags. |

> [!WARNING]
> **Canal Seguro de Diagnósticos:**
> Cualquier diagnóstico, log de depuración o print de desarrollo en `mcp_server.py` **debe ser escrito en `sys.stderr`** usando la función `log()`. Si escribes texto normal o de depuración en `sys.stdout`, corromperás el flujo JSON-RPC y el IDE desconectará el servidor por error de parseo.
