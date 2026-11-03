# Reglas de arquitectura ARC-009 a ARC-013

Prompts autocontenidos para que un agente (Claude Code, Antigravity u OpenCode) agregue una regla de arquitectura al pre-commit de un proyecto Dart/Flutter. Todos comparten el mismo auditor (`scripts/script_audit_architecture.dart`, con el AST de `analyzer`), su configuración (`scripts/arc_config.json`) y su prueba (`test/scripts/script_audit_architecture_test.dart`): las secciones 4 a 6 son idénticas en los cinco.

| Regla | Prompt | Qué exige | Línea base |
|---|---|---|---|
| ARC-009 | [ARC-009 mas de 500 lineas.md](ARC-009%20mas%20de%20500%20lineas.md) | Ningún archivo de `lib/` supera las 500 líneas | Sí (líneas de más) |
| ARC-010 | [ARC-010 mas de 15 imports.md](ARC-010%20mas%20de%2015%20imports.md) | Ningún archivo de `lib/` supera los 15 imports | Sí (imports de más) |
| ARC-011 | [ARC-011 SafeEmitMixin.md](ARC-011%20SafeEmitMixin.md) | Todo Cubit/Bloc usa `SafeEmitMixin` | No |
| ARC-012 | [ARC-012 pinning en Dio HttpClient.md](ARC-012%20pinning%20en%20Dio%20HttpClient.md) | Todo `Dio(`/`HttpClient(` va con la clase de pinning | No; requiere pinning previo |
| ARC-013 | [ARC-013 errores de datasources.md](ARC-013%20errores%20de%20datasources.md) | Todo `catch` de un datasource pasa por el manejador central o relanza | No; requiere manejador previo |

Uso: pasarle al agente el prompt de la regla dentro del proyecto. Si el auditor ya existe (otro prompt ARC lo creó), solo se agrega la regla a `activeRules`.

## Adopción (2026-11-03)

| Proyecto | Auditor | Reglas activas | Notas |
|---|---|---|---|
| walkietalkie | Referencia (analyzer 8.4.1) | 009, 010, 011, 012, 013 | `safeEmitMixin = ErrorHandlerMixin`, `pinningClass = TrustedServerStore`, `errorHandlerClass = Logger`, tres carpetas `data_sources/` |
| estilo_neutral | Referencia (analyzer 14.7.0) | 009 a 013 | `errorHandlerClass = Failure` (lib/core/error), datasources de cualquier feature; `DioClient` sin pinning con excepción hasta 2027-05-03 |
| estilo_neutral_cliente | Referencia (analyzer 14.7.0) | 009 a 013 | Datasources = `lib/data/`, `errorHandlerClass = ClienteApiException`; el `Dio` y cinco catch intencionales de `cliente_api.dart` (y uno de `google_auth.dart`) con excepción hasta 2027-05-03 |
| ReelKeeper | Propio (por líneas, ARC-001 a ARC-007) | 009 a 013 portadas | Sin línea base (nada pasaba los límites); sin clientes HTTP; `errorHandlerClass = Failure` (Either). Sus `Failure` llevan `e.toString()` en `message`: la vista muestra `userMessage` (mcp-ia #341), ya que ARC-013 no lo detecta |
| indios | — | — | No es un proyecto Dart |

## Lo aprendido al aplicarlas

- **analyzer < 13:** además de `node.name` en lugar de `node.namePart.typeName`, los miembros de una clase están en `declaration.members` (no en `body.childEntities`). Ver la tabla de errores de cada prompt.
- **No subir analyzer de más:** `flutter pub add --dev analyzer` puede mover dependencias transitivas de drift/freezed. Fijarlo en la versión que ya estaba resuelta: `flutter pub add --dev "analyzer:>=8.4.1 <9.0.0"`.
- **Guardián del hook:** dentro de comillas simples, `grep -E` necesita `\.`, no `\\.` (las versiones anteriores de estos prompts traían el doble).
- **Prueba genérica:** la prueba del detector puede leer los parámetros del auditor (`safeEmitMixin`, `pinningClass`, `errorHandlerClass`, `datasourcesDirs`, `stateBaseClasses`) y saltar los grupos de reglas inactivas (`skip: !activeRules.contains(...)`); así el mismo archivo sirve en todos los proyectos.
- **Activar ARC-012/013 antes de tener pinning o manejador central:** se puede, para que el proyecto no crezca sin ellos. `pinningClass` lleva el nombre que tendrá la clase (`CertificatePinningConfig`): mientras no exista, ningún cliente HTTP nuevo pasa. Lo que ya existía va a `excepciones` con motivo concreto y `vence`; al vencer vuelve a bloquear y obliga a decidir.
- **Datasources de features futuras:** en vez de una lista fija de carpetas, un patrón (`datasourcesPath = RegExp(r'^lib/(features/\w+/)?infrastructure/datasources/')`), y la prueba elige un ejemplo que lo cumpla.
- **Proyectos con formato automático en el pre-commit:** al tocar muchos Cubits sin formato previo, hacer primero un commit `style:` solo con `dart format` y las llaves que pida el análisis, y después el cambio real, para que el diff se pueda revisar.
