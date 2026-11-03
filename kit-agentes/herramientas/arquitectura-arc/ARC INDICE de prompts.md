# Reglas de pre-commit para proyectos Dart/Flutter: índice de prompts

> Origen: proyecto zas (Zas! Payments), noviembre de 2026. Cada prompt es autocontenido y trae el código (auditor de arquitectura y pruebas) probado contra el `lib/` de zas con analyzer 13.3.0 y Flutter 3.47.7. Todos comparten el mismo auditor, así que se aplican en cualquier orden.

## Cómo usarlos

1. Entrega **un prompt por vez** al agente (Claude Code, Antigravity u OpenCode) dentro del proyecto destino, y revisa su informe antes del siguiente.
2. El agente primero comprueba si la regla **aplica** (sección 0.1 de cada prompt). Si no aplica, informa y termina sin tocar nada.
3. Orden recomendado: primero las que aplican a cualquier proyecto, luego las que dependen de bibliotecas, y al final las que necesitan piezas propias del proyecto.

## Prompts

| Orden | Archivo | Qué evita | Requisito para aplicar | Lo existente |
|---|---|---|---|---|
| 1 | `ARC-009 mas de 500 lineas.md` | Archivos gigantes que mezclan responsabilidades | Ninguno | Línea base: puede encoger, no crecer |
| 2 | `ARC-010 mas de 15 imports.md` | Archivos con demasiadas dependencias | Ninguno | Línea base |
| 3 | `Aviso codificacion de archivos md.md` | `.md` con tildes dañadas (`Ã©`, `Ć³`) | Ninguno (cualquier lenguaje) | Solo avisa |
| 4 | `ARC-011 SafeEmitMixin.md` | `StateError` por emitir tras cerrar un Cubit | `flutter_bloc`/`bloc` | Se corrige antes de activar |
| 5 | `ARC-015 avisos repetidos en listeners.md` | Diálogos y SnackBars que se repiten | `flutter_bloc` | Se corrige antes de activar |
| 6 | `ARC-016 Equatable props completos.md` | Pantallas que no se actualizan por un campo fuera de `props` | `equatable` | Se corrige antes de activar |
| 7 | `ARC-012 pinning en Dio HttpClient.md` | Clientes HTTP nuevos sin pinning | Pinning ya implementado | Se corrige antes de activar |
| 8 | `ARC-013 errores de datasources.md` | Texto técnico de errores visible al usuario y errores sin auditar | Manejador central de errores | Se corrige antes de activar |
| 9 | `ARC-017 clave de cifrado en el codigo.md` | Clave de la base cifrada escrita en el código | SQLCipher | Se corrige antes de activar (con migración) |
| 10 | `ARC-018 id del comercio de la sesion.md` | Lecturas a mano de un dato de sesión con varios nombres | Un método único que lo resuelve | Línea base |
| 11 | `ARC-019 force-unwrap fuera del dominio.md` | `Null check operator used on a null value` por un `!` sobre un dato nulo | Ninguno (también TypeScript, Kotlin y Swift) | Línea base: puede bajar, no subir |

## Qué queda en el proyecto destino

- `scripts/script_audit_architecture.dart`: el auditor (las reglas adoptadas en `activeRules`).
- `scripts/arc_config.json`: excepciones con vencimiento y línea base.
- `test/scripts/script_audit_architecture_test.dart`: pruebas del detector.
- El bloque de auditoría en el pre-commit (`.githooks/pre-commit.local` con el kit de mcp-ia, o el hook del proyecto).
- Una línea por regla en `AGENTS.md`.

## No incluidas (específicas de zas)

- **ARC-001 a ARC-008:** capas, `setState`, vistas, `http://`, `!` en el dominio, `catch` vacío y casts; dependen de la estructura de carpetas de zas. Están en `scripts/script_audit_architecture.dart` de zas si se quieren adaptar.
- **ARC-014:** todo Cubit global de `lib/app/providers.dart` se reinicia al cerrar sesión; depende de `providers.dart` y `logout_helper.dart` de zas.
