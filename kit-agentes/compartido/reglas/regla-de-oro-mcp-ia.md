---
trigger: always_on
description: "REGLA DE ORO, OBLIGATORIA SIEMPRE: todo problema resuelto se registra en mcp-ia (add_solution) en el momento; antes de resolver, search_solutions."
---

# Regla de oro: todo problema resuelto se registra en mcp-ia

**Obligatoria en todos los proyectos y para todos los agentes (Claude Code, Antigravity, OpenCode). No tiene excepciones.**

La base `mcp-ia` es la memoria compartida entre proyectos. Un error resuelto que no se registra se vuelve a pagar entero en el siguiente proyecto.

## Al empezar y al terminar la sesión: sincronizar

Cada máquina tiene su propia base y numera sus soluciones por su cuenta: lo que se registró en otra máquina no aparece hasta sincronizar.

- Ejecuta `sh <mcp-ia>/scripts/sincronizar.sh` (macOS/Linux) o `<mcp-ia>\scripts\sincronizar.bat` (Windows) **al empezar** (para traer lo de las otras máquinas) y **al terminar** (para compartir lo tuyo). Mezcla el `compartido.json` de git (el único punto de encuentro) sin duplicar, y hace commit.
- Después avisa a la persona: falta `git push` en mcp-ia.
- Los ids (`#172`…) son locales: entre máquinas, cita las soluciones por su **título**.
- **Agentes delegados**: no sincronizan; lo hace el jefe maestro.

## Antes de resolver

1. Busca el error en `mcp-ia` con `search_solutions` (el mensaje de error, o el síntoma si no hay mensaje).
2. Si hay solución, aplícala y márcala con `record_usage` (su ID), indicando si funcionó.

## Inmediatamente después de resolver

3. **Registra la solución en el momento**, no al final de la sesión ni del lote: `add_solution` con
   - `title`: `[proyecto] <qué falla, en pocas palabras>`;
   - `problem`: el mensaje de error exacto o el síntoma observable, y dónde aparece;
   - `solution`: la **causa** y el **arreglo** concreto (archivo, configuración o comando), de forma que alguien que no vio el problema lo pueda aplicar;
   - `category` (`compilacion`, `runtime`, `widgets`, `estado`, `plataforma`, `herramientas`…) y `tags` (tecnología y proyecto).
4. Cuenta como «problema resuelto»: errores de compilación o de ejecución, fallos de pruebas, configuraciones de herramientas (Gradle, R8, permisos, hooks, CI), trampas de dispositivos (MIUI, emulador) y decisiones de una biblioteca que no estaban documentadas. Si te costó más de un intento, se registra. **También lo que encuentras al revisar código** (una auditoría, un code review, una prueba manual), aunque todavía no haya fallado al ejecutar: si lo corriges, es un problema resuelto.
   - Varios errores con la misma causa se pueden agrupar en una solución; cada **causa** distinta, en la suya.
5. Si cambia una solución que ya existía, agrega una nueva que la mencione (o actualízala si la herramienta lo permite). No dejes la vieja como si siguiera vigente.

## Antes de cada commit que contenga correcciones

Comprobación obligatoria, para personas y agentes:

1. Lista las causas que corrige el commit (un `fix:` casi siempre tiene al menos una; un `refactor:` o `feat:` también puede tenerlas).
2. Por cada causa: **¿ya tiene su `add_solution`?** Búscala con `search_solutions` o `python3 mcpia.py "<síntoma>"`.
3. Si falta alguna, **regístrala primero y haz el commit después**. Un commit con correcciones sin su registro deja la tarea sin terminar.

El hook `commit-msg` del kit lo recuerda en cada commit `fix:` (no bloquea).

## Si no tienes las herramientas MCP cargadas

- Usa el cliente JSON-RPC: `python3 <mcp-ia>/kit-agentes/compartido/mcpia.py "texto del error"` para buscar, y `Cliente().herramienta("add_solution", {...})` para registrar.
- **Agentes delegados** (Antigravity u OpenCode en un lote): no escriben en la base. Describen cada error resuelto en el informe (**error, causa y solución**). El jefe maestro lo registra al revisar el lote, antes del commit.

## Cómo se comprueba

- Al cerrar una tarea o un lote, **y antes de cada commit con correcciones**: por cada error resuelto (también los encontrados en una revisión), `python3 mcpia.py "<error>"` debe devolver su solución entre los primeros resultados.
- Una respuesta del tipo «lo arreglé» sin el ID de `add_solution` (o el informe con error, causa y solución, en los agentes delegados) deja la tarea **sin terminar**.
