# 🧠 mcp-ia (Memoria Local & Servidor MCP)

¡Bienvenido a la documentación oficial de **mcp-ia**!

**mcp-ia** es un sistema de **memoria persistente local** y **servidor MCP (Model Context Protocol)** diseñado para desarrolladores de Flutter/Dart. Su objetivo principal es actuar como una base de conocimiento offline para tu asistente de Inteligencia Artificial (IDE Antigravity, VS Code, Cursor, etc.), minimizando el consumo de tokens al buscar soluciones localmente antes de consultar a internet.

---

## 💡 Filosofía del Proyecto

> **"Busca primero en local, pregunta a la IA solo si es necesario y guarda la respuesta para que el sistema aprenda."**

Al seguir este flujo, la base de datos local se enriquece de forma progresiva. Con el tiempo, la mayoría de los errores comunes y plantillas de desarrollo se resolverán localmente en menos de 100 ms, ahorrando miles de tokens en llamadas a la API de la IA.

```
                  ┌─────────────────────────────┐
                  │ ¿Ocurrió un error en el IDE? │
                  └──────────────┬──────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │ Busca en local (MCP)  │
                     └───────────┬───────────┘
                                 │
                    ┌────────────┴────────────┐
             Si     │ ¿Existe solución local? │     No
       ┌────────────┤                         ├────────────┐
       │            └─────────────────────────┘            │
┌──────▼────────┐                                  ┌──────▼────────┐
│ Usar solución │                                  │ Consultar IA  │
│  (0 Tokens!)  │                                  │ (Usa Tokens)  │
└───────────────┘                                  └──────┬────────┘
                                                          │
                                                ┌─────────▼─────────┐
                                                │ Guardar en local  │
                                                │ (Aprende para la  │
                                                │   próxima vez)    │
                                                └───────────────────┘
```

---

## 🛠️ Características Principales

* **Búsqueda Instantánea (<100ms):** Búsquedas ultrarrápidas mediante SQLite FTS5 (Full-Text Search) con operadores de prefijo.
* **Tolerancia a Errores (Fuzzy Matching):** Usa `rapidfuzz` para encontrar coincidencias incluso si escribes términos con errores tipográficos (typos).
* **Servidor MCP Integrado:** Protocolo estándar de Anthropic que expone herramientas directamente al Agente IA sobre `stdio` mediante mensajes JSON-RPC 2.0 UTF-8.
* **Lavadero de Juguetes (Limpiador de Logs):** Módulo [`cleaning.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/cleaning.py) que remueve automáticamente direcciones de memoria, rutas de carpetas y trazas confusas de stack traces para aislar el error exacto.
* **Sincronización Compartida:** Herramienta [`sync.py`](#) que permite subir y bajar soluciones en un cofre común para compartir conocimiento en equipos de desarrollo.

---

## 🚀 Guía Rápida de Inicio

1. **Instalar dependencias e inicializar base de datos:**
   Abre tu terminal en la carpeta del repositorio y ejecuta:
   ```bash
   # En Windows
   py scripts/setup.py --path
   
   # En Mac / Linux
   python3 scripts/setup.py
   ```
2. **Registrar en tu IDE:** El script de configuración genera de forma automática los archivos `mcp_config.json` tanto a nivel local (en tu espacio de trabajo de trabajo) como de forma global para el IDE.
3. **Buscar tu primera solución:**
   ```bash
   fm busca "MissingPluginException"
   ```
