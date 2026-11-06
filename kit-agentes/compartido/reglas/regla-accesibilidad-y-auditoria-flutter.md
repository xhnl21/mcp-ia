# Accesibilidad, errores auditados y toques auditados (Flutter)

Vale para todos los proyectos Flutter. En zas la hace cumplir el auditor ARC (`scripts/script_audit_architecture.dart`, reglas ARC-027 a ARC-029), que es la implementación de referencia, copiada en `kit-agentes/herramientas/hooks-nivel-ci/referencia-zas/` (ver `hooks-nivel-ci/README.md`). En los proyectos que no tienen auditor, el agente la revisa a mano.

## 1. Accesibilidad (ARC-027, sin línea base)

Aplica en la capa de presentación (`lib/presentation/` o equivalente).

- Todo `GestureDetector` va dentro de un `Semantics` (o de `MergeSemantics` o `Tooltip`), o lleva `excludeFromSemantics: true` si no es una acción (cerrar el teclado, pegar con pulsación larga).
- Todo `IconButton` (también `.filled`, `.filledTonal` y `.outlined`) lleva `tooltip:` en el idioma de la app («Volver», «Cerrar», «Mostrar u ocultar la contraseña»).
- Toda imagen (`Image.asset/network/file/memory`, `SvgPicture.*`) lleva `semanticLabel` (o `semanticsLabel`), o `excludeFromSemantics: true` si es decorativa.
- Un botón con `onPressed: () {}` no hace nada, pero un lector de pantalla lo anuncia como botón: si es decorativo, se usa un `Icon`.

## 2. Errores auditados (ARC-028)

Aplica en todas las capas DDD (application, infrastructure) y en los cubits o blocs.

- Un `catch` genérico (`catch (e)` sin tipo) pasa por el manejador central de errores, que lo registra en la auditoría (`CentralErrorHandler` y `AuditLogger` en zas), o relanza. Registrarlo solo con `Logger` no alcanza.
- Un error esperado se captura por su tipo (`on FormatException catch (e)`).
- Quedan exentos la propia infraestructura de auditoría y el manejador central, porque si no se llaman a sí mismos.
- Si el proyecto ya tiene casos, se fija una línea base: no se agregan nuevos y el número solo baja.

## 3. Toques auditados (ARC-029)

- Toda pantalla con toques directos los registra (`auditedCallback` o `AuditableAction` en zas), o lleva `// auditoria: exento - <motivo>`.
- Nunca se registra lo que escribe el usuario ni sus datos personales.

## Cómo aplicarla

- Si un archivo supera su límite de líneas al agregar `tooltip` o `Semantics`, se extrae un widget. No se sube la línea base.
- Un auditor sin resolución de tipos (`parseString`) lee `const Image.network(...)` como un tipo con prefijo: hay que tomar el prefijo como tipo. Detalle en mcp-ia: «[zas] Auditor ARC sin resolución de tipos: `const Image.network(...)` llega como tipo con prefijo».
