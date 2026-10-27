## 0. Reglas obligatorias (si rompes una, el lote se rechaza entero)

0. **Antes de empezar, lee `.agents/prompts/LECCIONES_AGENTES.md`** y aplica cada lección. Son errores reales de lotes anteriores. No edites ese archivo.

1. **No hagas commits, ni `git add`, ni `git stash`, ni push.** Deja los cambios sin preparar en el árbol de trabajo. El jefe maestro revisa y hace los commits.
2. **Solo puedes modificar los archivos listados en cada tarea.** Si crees que hace falta tocar otro, no lo toques: anótalo en el informe final.
3. **Respeta la sección «Alcance» de la tarea:** solo puedes tocar los directorios y archivos que permita. Nunca toques `.githooks/`, `scripts/`, `pubspec.yaml`, `android/` ni `ios/`, salvo que la tarea lo pida de forma explícita.
4. **No inventes nada.** Cada frase nueva que escribas debe salir de un comando que hayas ejecutado: un `grep`, un `ls` o leer el archivo. Si no lo puedes comprobar, no lo escribas: anótalo como «no verificado» en el informe.
5. **No borres secciones enteras salvo que la tarea lo diga.** Corrige el dato concreto y conserva el resto del documento, su estilo y sus encabezados.
6. **No escribas puntuaciones, porcentajes ni certificaciones** («100 %», «10/10», «cumple», «blindado», «clase mundial»).
7. **Nunca muestres secretos:** ni el contenido de `.env*`, ni claves de API, ni contraseñas.
8. **Idioma:** español, con frases cortas.
9. **Si una tarea no se puede hacer tal como está escrita, detente en esa tarea**, explica por qué en el informe y pasa a la siguiente.
10. **Comandos permitidos:** Solo puedes ejecutar comandos de lectura (strings, sqlite3, xxd, -l , otool, sleep, ls, cat, grep, grep -rn, git grep, find, git status, git diff, git diff --name-only, git diff --stat, openssl s_client -connect, \*.sh) y comandos de prueba y análisis (flutter test, flutter analyze). Prohibido usar rm, mv, sed, awk o cualquier script que modifique archivos fuera de tu control.
11. **Limpieza de código:** Si modificas una función, variable o clase, asegúrate de no dejar imports, variables o funciones sin usar (código muerto). Si no puedes limpiarlo sin salirte del alcance, anótalo en el informe.
12. **No ejecutes pruebas en bucle.** Si una prueba falla, anota el error exacto y detente. No intentes «arreglar» el código de pruebas (test/) para que pasen.
13. **Si tienes dudas, pregunta o detente.** No asumas intenciones. Si una instrucción es ambigua, anótalo como «requiere aclaración» en el informe y no actúes.
14. **No reformatees código ni archivos.** No cambies comillas, sangrías, saltos de línea ni el orden de los elementos si no es estrictamente necesario para la tarea. Respeta el estilo original del proyecto.
15. **Un comando por llamada, sin operadores de shell.** No encadenes con `&&`, `;` ni `|`, no redirijas con `>` y no pongas comentarios `#`. Si aparecen en una comprobación de la tarea, ejecuta cada parte por separado. En modo sin pantalla, un comando encadenado se niega aunque cada parte esté permitida, y el lote se corta (lección J-006 de la base mcp-ia).
16. **REGLA DE ORO: todo problema resuelto queda registrado en `mcp-ia`.** Antes de resolver un error, búscalo con `search_solutions` (el mensaje de error); si hay solución, aplícala y anota su ID en el informe. **Cada error que resuelvas y no estuviera en la base va en el informe con su error, causa y solución**, y el jefe maestro lo registra con `add_solution` antes del commit. Un lote con errores resueltos y sin esa sección en el informe **se rechaza**. Tú no escribes en la base. Detalle: `compartido/reglas/regla-de-oro-mcp-ia.md` del kit.
