# Hooks al nivel del CI y auditor de arquitectura ARC (referencia: zas)

Cómo hacer que cada `git commit` y cada `git push` de un proyecto Dart o Flutter revisen lo mismo que haría un CI: secretos (gitleaks), vulnerabilidades de dependencias (osv-scanner), código generado, versión del SDK, cobertura y el auditor de arquitectura ARC (ARC-001 a ARC-029). Sirve también cuando el proyecto no tiene CI o el CI está apagado, como en zas.

La implementación de referencia es la de **zas** (Zas! Payments), copiada en [`referencia-zas/`](referencia-zas/) con las mismas rutas que en el proyecto. `referencia-zas/VERSION.txt` dice de qué commit sale.

- **Actualizar la copia** cuando cambie algo en zas: `sh copiar_desde_zas.sh [ruta-de-zas]`. Después, revisar `git diff`, actualizar las tablas de abajo si cambiaron las reglas, y hacer commit en mcp-ia.
- **No es una skill:** no tiene `SKILL.md`, así que `enlazar_compartido` no la enlaza. Se le pasa este README al agente dentro del proyecto destino.

## 1. Piezas y para qué sirve cada una

| Archivo en `referencia-zas/` | Qué hace | ¿Se copia tal cual? |
|---|---|---|
| `docs/devops/configurar_hooks_desde_cero.md` | Guía para una máquina sin nada instalado, con un prompt para IA: instalación, verificación y problemas frecuentes | Adaptar nombres y versiones |
| `docs/devops/git-hooks.md` | Detalle de cada revisión de los hooks | Adaptar |
| `.githooks/pre-commit.local` | Gate 5 del pre-commit común del kit: SDK, gitleaks, `pubspec.lock`, código generado, pruebas por capa, toques auditados y auditoría ARC | Adaptar (rutas y scripts del proyecto) |
| `.githooks/pre-push.local` | Ramas protegidas, SDK, `pubspec.lock`, osv-scanner, ARC, cobertura global y cobertura de las líneas cambiadas | Adaptar (ramas y umbrales) |
| `.githooks/obligatorio.sh` | Lo que se ejecuta incluso con `SKIP_PRE_COMMIT=1` (la auditoría ARC) | Sí |
| `.gitleaks.toml` | Reglas por defecto de gitleaks más lo permitido (claves de cliente de Firebase, `test/`) | Sí; cada excepción nueva, con revisión |
| `scripts/check_sdk_version.sh` | Falla si el Flutter en uso no es el de `.fvmrc` | Sí |
| `scripts/check_generated_code.sh` | `flutter gen-l10n` y `build_runner` al día si cambian `.arb` o tablas de drift | Solo si el proyecto los usa |
| `scripts/check_layer_tests.dart` | Todo archivo nuevo de `application/` o `infrastructure/` trae su prueba | Sí (rutas DDD) |
| `scripts/check_coverage.sh` | Cobertura global mínima (en zas, 54 %; solo puede subir) | Sí, con el umbral del proyecto |
| `scripts/check_diff_coverage.dart` | Cobertura de las líneas cambiadas frente a `origin/dev` (en zas, 80 %) | Sí, con la rama base del proyecto |
| `scripts/check_audited_screens.dart` | Toques de pantalla registrados en la auditoría (`auditedCallback`) | Solo con auditoría de toques |
| `scripts/script_audit_architecture.dart` | **Auditor ARC**: recorre todo `lib/` con el AST de `analyzer`, sin resolver tipos, y falla con `exit 1` | Ver sección 3 |
| `scripts/arc_accessibility.dart` | Detector de ARC-027 (accesibilidad) | Sí |
| `scripts/arc_modules_report.dart` | Reporte DDD por módulo (`--modulos`) | Sí |
| `scripts/arc_config.json` | Excepciones con vencimiento y línea base de zas | **No**: en un proyecto nuevo se genera con `--generar-linea-base` |
| `test/scripts/*_test.dart` | Pruebas del detector y del reporte | Sí, junto con el auditor |
| `scripts/mr_report.dart` + `.gitlab/merge_request_templates/default.md` | Descripción del MR como informe ejecutivo (resumen, tabla de cambios, verificación) | Opcional |
| `.gitlab-ci.yml` | El CI de GitLab de zas: está apagado (`when: never`) por falta de minutos y atrasado respecto de los hooks | Solo como punto de partida |

## 2. Herramientas que hay que instalar

| Herramienta | Instalación (macOS) | Versión probada | Sin ella |
|---|---|---|---|
| `fvm` | `brew tap leoafarias/fvm && brew install fvm`, después `fvm install` en el proyecto | 3.47.7 (Flutter de zas) | Los hooks fallan |
| `gitleaks` | `brew install gitleaks` | 8.30.1 | El hook avisa y omite la revisión de secretos |
| `osv-scanner` | `brew install osv-scanner` | 2.7.0 | El hook avisa y omite la revisión de dependencias |

En Linux, `gitleaks` y `osv-scanner` se instalan desde sus releases de GitHub; en Windows, con Git Bash o WSL.

Cómo los llaman los hooks:

- **Pre-commit:** `gitleaks git --pre-commit --staged --no-banner --redact`. Revisa solo lo que se va a subir, no toda la historia.
- **Pre-push:** `osv-scanner scan source -L pubspec.lock`. Sin conexión, solo avisa.
- Hallazgos viejos en la historia (`gitleaks git .`) no bloquean. Se resuelven rotando la clave, no agregándola a `.gitleaks.toml`.

## 3. El auditor ARC

| Reglas | Qué revisan | ¿Generales? |
|---|---|---|
| ARC-001, 006, 022 a 026 | Capas DDD: presentation no importa infrastructure, domain es Dart puro, la presentación usa casos de uso, cada módulo tiene interfaz, repositorio y caso de uso, y las vistas no usan cubits | Sí, si el proyecto tiene `lib/domain`, `application`, `infrastructure` y `presentation` |
| ARC-002, 003, 011, 015, 016 | `setState` en pantallas, cubits en `views/`, `SafeEmitMixin`, `listenWhen` y `props` de Equatable | Con `flutter_bloc` y `equatable` |
| ARC-004, 012, 017, 020 | `http://`, pinning en Dio, clave de cifrado en el código y datos sensibles en el `Logger` | Sí (ARC-012 si hay pinning) |
| ARC-005, 019 | El operador `!` postfijo | Sí |
| ARC-007, 008, 013, 028 | `catch` vacío, casts sobre JSON y errores que pasan por el manejador central y la auditoría | Con un manejador central (`CentralErrorHandler` en zas) |
| ARC-009, 010 | Más de 500 líneas o 15 imports | Sí |
| ARC-014, 018 | Reinicio de cubits al cerrar sesión e id del comercio de la sesión | Propias de zas |
| ARC-021 | `// ignore:` sin motivo | Sí |
| ARC-027 | Accesibilidad: `Semantics`, `tooltip` y `semanticLabel` | Sí |
| ARC-029 | Toques de pantalla auditados | Con auditoría de toques |

Prompts por regla, para aplicarlas de a una: [`../arquitectura-arc/`](../arquitectura-arc/) (ARC-009 a ARC-019). Regla compartida de accesibilidad y auditoría: `compartido/reglas/regla-accesibilidad-y-auditoria-flutter.md`.

## 4. Cómo adoptarlo en un proyecto nuevo

1. Instalar los hooks comunes del kit: `sh <mcp-ia>/kit-agentes/hooks.sh <proyecto>`.
2. Instalar las herramientas de la sección 2 y fijar Flutter con `.fvmrc`.
3. Copiar `.gitleaks.toml`, `.githooks/obligatorio.sh` y los `scripts/` que apliquen. Adaptar `pre-commit.local` y `pre-push.local`, quitando lo que el proyecto no tenga (drift, l10n, auditoría de toques).
4. Elegir el auditor y generar la línea base del proyecto con `dart run scripts/script_audit_architecture.dart --generar-linea-base`:
   - **Proyecto con la misma estructura DDD y piezas que zas** (flutter_bloc, `CentralErrorHandler`, auditoría de toques): copiar el auditor de zas con sus detectores y pruebas. Tiene todas las reglas activas.
   - **Proyecto distinto:** usar el auditor de los prompts de [`../arquitectura-arc/`](../arquitectura-arc/), que trae `activeRules`, y agregar regla por regla. Las reglas que no estén en esos prompts se toman de `referencia-zas/scripts/script_audit_architecture.dart` (se encuentran con `grep -n "ARC-0xx"`).
5. Copiar `docs/devops/configurar_hooks_desde_cero.md` y cambiar el nombre del proyecto, las versiones y los umbrales.
6. Verificar con la tabla de la sección 4 de esa guía: cada comando con su resultado real.
7. Agregar las reglas en el `AGENTS.md` del proyecto (ver el de zas: «cero violaciones de arquitectura» y «hooks de git»).

Prohibido, en todos los proyectos: usar `--no-verify` o `SKIP_PRE_COMMIT=1` para saltar la auditoría, y editar el auditor, su prueba, `arc_config.json` o `.gitleaks.toml` para que pase una violación.
