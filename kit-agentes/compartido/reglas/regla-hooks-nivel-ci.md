# Hooks al nivel del CI y auditor ARC en proyectos Dart/Flutter

Vale para todos los proyectos Dart o Flutter. La referencia completa está en `<mcp-ia>/kit-agentes/herramientas/hooks-nivel-ci/README.md`, con la implementación de zas copiada en `referencia-zas/`.

## Al crear o configurar un proyecto

- Instala los hooks comunes del kit (`sh <mcp-ia>/kit-agentes/hooks.sh <proyecto>`). Después agrega las revisiones que haría un CI: en el pre-commit, **gitleaks** sobre lo que se va a subir; en el pre-push, **osv-scanner** sobre `pubspec.lock`, la cobertura global y la de las líneas cambiadas. En los dos, el SDK de `.fvmrc` y el auditor ARC.
- Herramientas: `brew install gitleaks osv-scanner` y `fvm`. Si faltan, el hook avisa y omite esa revisión. Instálalas: no se rodean.
- El proyecto lleva su guía `docs/devops/configurar_hooks_desde_cero.md`, adaptada de la de zas, con un prompt para un agente que no tiene nada configurado.

## El auditor de arquitectura (ARC-001 a ARC-029)

- `scripts/script_audit_architecture.dart` recorre todo `lib/` y bloquea el commit y el push. Su línea base está en `scripts/arc_config.json`: en un proyecto nuevo se genera, no se copia la de zas.
- Si el proyecto no tiene las piezas de zas, se adopta regla por regla con los prompts de `kit-agentes/herramientas/arquitectura-arc/`.

## Prohibido, en todos los proyectos

- Usar `--no-verify` o `SKIP_PRE_COMMIT=1` para saltar la auditoría.
- Editar el auditor, su prueba, `arc_config.json` o `.gitleaks.toml` para que pase una violación.
- Agregar a `.gitleaks.toml` un secreto real como «falso positivo»: se saca del código y se rota la clave.

## Cuando mejore en zas

Ejecuta `sh <mcp-ia>/kit-agentes/herramientas/hooks-nivel-ci/copiar_desde_zas.sh`, actualiza el README si cambiaron las reglas y haz commit en mcp-ia.
