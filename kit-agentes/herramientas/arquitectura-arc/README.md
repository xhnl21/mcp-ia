# Reglas de arquitectura ARC-009 a ARC-018

Prompts autocontenidos para que un agente (Claude Code, Antigravity u OpenCode) agregue una regla de arquitectura al pre-commit de un proyecto Dart/Flutter. Todos comparten el mismo auditor (`scripts/script_audit_architecture.dart`, con el AST de `analyzer`), su configuración (`scripts/arc_config.json`) y su prueba (`test/scripts/script_audit_architecture_test.dart`): el código del auditor es idéntico en los nueve prompts. Orden recomendado y dependencias: [ARC INDICE de prompts.md](ARC%20INDICE%20de%20prompts.md).

| Regla | Prompt | Qué exige | Requisito |
|---|---|---|---|
| ARC-009 | [ARC-009 mas de 500 lineas.md](ARC-009%20mas%20de%20500%20lineas.md) | Ningún archivo de `lib/` supera las 500 líneas | Línea base (líneas de más) |
| ARC-010 | [ARC-010 mas de 15 imports.md](ARC-010%20mas%20de%2015%20imports.md) | Ningún archivo de `lib/` supera los 15 imports | Línea base (imports de más) |
| ARC-011 | [ARC-011 SafeEmitMixin.md](ARC-011%20SafeEmitMixin.md) | Todo Cubit/Bloc usa `SafeEmitMixin` | — |
| ARC-012 | [ARC-012 pinning en Dio HttpClient.md](ARC-012%20pinning%20en%20Dio%20HttpClient.md) | Todo `Dio(`/`HttpClient(` va con la clase de pinning | Pinning previo (o excepción con vencimiento) |
| ARC-013 | [ARC-013 errores de datasources.md](ARC-013%20errores%20de%20datasources.md) | Todo `catch` de un datasource pasa por el manejador central o relanza | Manejador previo |
| ARC-015 | [ARC-015 avisos repetidos en listeners.md](ARC-015%20avisos%20repetidos%20en%20listeners.md) | Un listener que muestra un aviso según el estado lleva `listenWhen` | `flutter_bloc` |
| ARC-016 | [ARC-016 Equatable props completos.md](ARC-016%20Equatable%20props%20completos.md) | Todo campo de un `Equatable` está en `props` | `equatable` |
| ARC-017 | [ARC-017 clave de cifrado en el codigo.md](ARC-017%20clave%20de%20cifrado%20en%20el%20codigo.md) | La clave de SQLCipher (`PRAGMA key`) no es un literal | Una base SQLCipher; si no, no se activa |
| ARC-018 | [ARC-018 id del comercio de la sesion.md](ARC-018%20id%20del%20comercio%20de%20la%20sesion.md) | El id de la sesión sale de un único resolutor | Un dato de sesión con varios nombres; si no, no se activa |
| Aviso | [Aviso codificacion de archivos md.md](Aviso%20codificacion%20de%20archivos%20md.md) | El pre-commit avisa (sin bloquear) de un `.md` con tildes dañadas | — |

Uso: pasarle al agente el prompt de la regla dentro del proyecto. Si el auditor ya existe (otro prompt ARC lo creó), solo se agrega la regla a `activeRules`.

## Adopción (2026-11-03)

| Proyecto | Auditor | Reglas activas | Notas |
|---|---|---|---|
| walkietalkie | Referencia (analyzer 8.4.1) | 009 a 013, 015, 017 | `safeEmitMixin = ErrorHandlerMixin`, `pinningClass = TrustedServerStore`, `errorHandlerClass = Logger`, tres carpetas `data_sources/`. Sin `equatable` (016 n/a). `app_database.dart` interpola la clave (017 pasa) |
| estilo_neutral | Referencia (analyzer 14.7.0) | 009 a 013, 015, 016 | `errorHandlerClass = Failure`; `DioClient` sin pinning con excepción hasta 2027-05-03; `abono_state` y `carga_lote_state` con excepción de 016 hasta 2027-11-03. Avisos de acción: `mostrarAvisoDeAccion`/`avisoDeAccionCambio` en `design_system/widgets` |
| estilo_neutral_cliente | Referencia (analyzer 14.7.0) | 009 a 013, 015, 016 | Datasources = `lib/data/`, `errorHandlerClass = ClienteApiException`; el `Dio` y los catch intencionales de `cliente_api.dart` y `google_auth.dart` con excepción hasta 2027-05-03 |
| ReelKeeper | Propio (por líneas, ARC-001 a ARC-007) | 009 a 013, 015, 016 portadas | Sin línea base ni excepciones; sin clientes HTTP; `errorHandlerClass = Failure` (Either). Aviso en su propio `.githooks/pre-commit` (no usa el `.local` del kit). Sus `Failure` llevan `e.toString()` en `message`: la vista muestra `userMessage` |
| indios | — | — | No es un proyecto Dart ni tiene hook |

ARC-018 no está activa en ningún proyecto: ninguno tiene un dato de sesión con varios nombres. El aviso de codificación está en los cuatro proyectos Dart.

## Lo aprendido al aplicarlas

- **analyzer < 13:** `node.name` en lugar de `node.namePart.typeName`, los miembros en `declaration.members` (no en `body.childEntities`) y los argumentos con nombre son `NamedExpression` (`a.name.label.name`, `a.expression`), no `NamedArgument`.
- **No subir analyzer de más:** `flutter pub add --dev analyzer` puede mover dependencias transitivas de drift/freezed. Fijarlo en la versión ya resuelta: `flutter pub add --dev "analyzer:>=8.4.1 <9.0.0"`.
- **Guardián del hook:** dentro de comillas simples, `grep -E` necesita `\.`, no `\\.`. Corregido en estos prompts el 2026-11-03; en Dart, `RegExp('\\b…')` (cadena no cruda) sí lleva el doble.
- **Prueba genérica:** la prueba del detector lee los parámetros del auditor y salta los grupos de reglas inactivas (`skip: !activeRules.contains(...)`); el mismo archivo sirve en todos los proyectos.
- **Activar ARC-012/013 antes de tener pinning o manejador central:** `pinningClass` lleva el nombre que tendrá la clase; lo que ya existía va a `excepciones` con motivo y `vence`.
- **Datasources de features futuras:** un patrón (`datasourcesPath`) en vez de una lista fija de carpetas.
- **ARC-015 hace crecer archivos de la línea base ARC-009:** no subir la línea base; extraer lo repetido (en estilo_neutral, el listener de SnackBar de tres páginas) o compactar el mismo archivo (`builder: (c, s) => switch (s) {...}`, un `if` anidado que se junta).
- **Commit `style:` aparte:** solo si el formato no hace crecer un archivo de la línea base; si lo hace, el hook lo bloquea y el formato va en el mismo commit del arreglo.
- **Aviso de codificación:** no escribir las secuencias dañadas literalmente en el `AGENTS.md`/`CLAUDE.md` de un proyecto con el hook, porque el aviso salta solo; describirlas («una é convertida en dos caracteres raros»).
- **Auditor por líneas (ReelKeeper):** un detector nuevo necesita su prueba de que falla. El primer port de ARC-016 no detectaba nada (la cabecera de la clase salía vacía y no aceptaba `props => const [...]`), y aun así la auditoría de `lib/` daba «APROBADO».
