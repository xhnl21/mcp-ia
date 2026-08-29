# 📥 Cómo Agregar Conocimiento

El sistema de memoria local `mcp-ia` ofrece tres métodos distintos para registrar nuevas soluciones, guías o plantillas en su base de datos. De esta forma, el aprendizaje se adapta a tu flujo de trabajo sin importar si estás en la terminal, en medio de una conversación con la IA o automatizando tareas.

---

## 🛠️ Método 1: Búsqueda y Auto-Captura (`learn.py`)

El script [`learn.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/learn.py) es el método recomendado cuando te enfrentas a un error nuevo que no sabes cómo resolver. Funciona como un flujo interactivo:

```powershell
py scripts/learn.py "MissingPluginException on channel shared_preferences" --auto-import
```

### Comportamiento del script:
1. **Búsqueda Local:** Primero limpia el error usando [`cleaning.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/cleaning.py) e intenta buscar una solución local. Si existe, la imprime y termina (ahorrando tokens).
2. **Registro del Patrón:** Si no hay solución local, extrae la firma del error (`MissingPluginException`) y la registra en la tabla `patrones_error` con contador de frecuencia.
3. **Auto-Importación:** Si incluiste el flag `--auto-import` y tienes conexión a internet, consultará automáticamente la API de Stack Overflow buscando respuestas relevantes y las insertará como candidatas en la base de datos para que la IA pueda leerlas en tu próxima consulta.

---

## 💻 Método 2: Comandos de Terminal CLI (`fm agregar`)

Si has resuelto un problema tú mismo o tienes un fragmento de código (snippet) que quieres reutilizar en el futuro, puedes agregarlo directamente mediante el comando CLI:

```powershell
fm agregar "Estructura de initState" "Cómo inicializar variables en Flutter" "Usa initState() llamando a super.initState() al inicio." --tag lifecycle --tag widgets --cat widgets
```

### Sintaxis del comando:
* **Título (1er argumento):** Un título representativo y conciso.
* **Problema (2do argumento):** El mensaje de error exacto o descripción de lo que buscas resolver.
* **Solución (3er argumento):** La explicación paso a paso o código de solución.
* **Filtros opcionales:**
  - `--cat <slug>`: Categoría a la que pertenece (compilacion, runtime, widgets, estado, etc.).
  - `--tag <nombre>`: Etiquetas individuales libres para búsqueda granular. Puedes usar este flag múltiples veces.
  - `--url <url>`: Enlace opcional de referencia (Stack Overflow, documentación, etc.).

---

## 🤖 Método 3: Guardado Autónomo por la IA (Herramientas MCP)

Una vez que has configurado el servidor MCP en tu IDE (como se detalla en el [`README.md`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/README.md)), **tú no tienes que hacer nada**. 

Cuando conversas con el Agente de IA y este te ayuda a solucionar un error de código, el propio Agente llamará a la herramienta `add_solution` en segundo plano para guardar la solución.

### Ejemplo de cómo lo hace la IA por debajo:
1. Resuelves un problema de null safety con el agente.
2. El agente genera una respuesta exitosa.
3. El agente llama automáticamente a:
   ```json
   {
     "name": "add_solution",
     "arguments": {
       "title": "Error String? can't be assigned to String",
       "problem": "El argumento de tipo String nullable no se puede asignar...",
       "solution": "Usa el operador de coalescencia ?? o la aserción !",
       "category": "compilacion",
       "tags": ["null-safety", "types"]
     }
   }
   ```
4. En tu próximo chat o archivo, si vuelve a salir el error, la IA lo buscará en la memoria local y lo resolverá al instante.

---

## 🧬 Deduplicación de Conocimiento

Para evitar que la base de datos crezca sin control con soluciones repetidas (por ejemplo, al importar varias veces el mismo hilo de Stack Overflow o GitHub), el módulo [`manager.py`](file:///c:/Users/user/Desktop/autoaprendizaje/mcp-ia/scripts/manager.py) calcula un hash único SHA-256:

$$\text{Hash} = \text{SHA256}(\text{Título} + \text{Problema} + \text{Solución})$$

Si intentas agregar una solución cuyo hash ya existe en la base de datos, el sistema simplemente ignorará el duplicado y te devolverá el ID de la solución existente de forma segura.
