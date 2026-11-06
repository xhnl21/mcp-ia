# Configurar los hooks de zas desde cero

Guía para quien llega al proyecto sin nada instalado, persona o agente de IA. Al terminar, cada `git commit` y cada `git push` hacen las mismas revisiones que haría un CI. El CI de GitLab está apagado: **estos hooks son la única barrera de calidad del proyecto.**

Tiempo estimado: 30 a 45 minutos, casi todo en descargas.

---

## 1. Prompt para un agente de IA

Copia este bloque en el agente (Claude Code, Antigravity, OpenCode…) con el repositorio abierto:

```text
Configura este repositorio (zas, Flutter) para que sus git hooks funcionen.
Asume que la máquina no tiene nada instalado. Sigue
docs/devops/configurar_hooks_desde_cero.md paso a paso y no te saltes ninguna
verificación de la sección 4.

Reglas:
- Usa siempre el Flutter que fija .fvmrc a través de fvm
  (.fvm/flutter_sdk/bin). Antepón export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
  a cada comando de dart o flutter.
- Instala con el gestor de paquetes del sistema (brew en macOS). Si un paso
  necesita una contraseña o un permiso de administrador, detente y pídeselo a
  la persona.
- No edites .githooks/pre-commit, .githooks/pre-push ni .githooks/commit-msg
  (son del kit compartido y están protegidos por hash en kit_hooks.json), ni
  scripts/script_audit_architecture.dart, scripts/arc_config.json o
  test/scripts/script_audit_architecture_test.dart para que algo pase.
- Nunca uses --no-verify ni SKIP_PRE_COMMIT=1.
- Al final, entrega la tabla de la sección 4 con el resultado real de cada
  comando. Si algo falla, busca el síntoma en la sección 8 antes de improvisar.
```

---

## 2. Qué se instala y para qué

| Herramienta | Para qué la usan los hooks | Obligatoria |
|---|---|---|
| `git` | Los hooks son de git | Sí |
| `fvm` | Instala y fija el Flutter del proyecto (`.fvmrc`: **3.47.7**) | Sí |
| Flutter (vía fvm) | `analyze`, `format`, `test`, el auditor ARC y los scripts de `scripts/` | Sí |
| `gitleaks` | Busca secretos (claves, tokens) en lo que vas a subir | Muy recomendada: sin ella se omite esa revisión |
| `osv-scanner` | Busca vulnerabilidades conocidas en las dependencias (`pubspec.lock`) | Muy recomendada: sin ella se omite esa revisión |

Los hooks son scripts `sh`. Funcionan en macOS y Linux; en Windows, usa Git Bash o WSL.

---

## 3. Instalación paso a paso

### 3.1 Herramientas del sistema (macOS)

```sh
# Homebrew, si no está: https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install git
brew tap leoafarias/fvm && brew install fvm
brew install gitleaks osv-scanner
```

En Linux: `git` con el gestor de la distribución, `fvm` con `curl -fsSL https://fvm.app/install.sh | bash`, y `gitleaks` y `osv-scanner` desde sus releases de GitHub (binario en el `PATH`).

Comprueba:

```sh
git --version
fvm --version
gitleaks version        # 8.30 o superior
osv-scanner --version   # 2.7 o superior
```

### 3.2 El proyecto

```sh
git clone <url-del-repositorio> zas
cd zas

# Flutter del proyecto: lee .fvmrc, descarga 3.47.7 y crea .fvm/flutter_sdk
fvm install
fvm use 3.47.7          # solo si .fvm/flutter_sdk no quedó creado

# En esta terminal, usa ese Flutter antes que cualquier otro
export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
flutter --version       # debe decir Flutter 3.47.7

flutter pub get
```

> El `PATH` importa. Si en la máquina hay otro Flutter (por ejemplo uno global), `dart run` compila los scripts con ese SDK y luego falla con «Can't load Kernel binary: Invalid SDK hash». Los hooks ya ponen `.fvm/flutter_sdk/bin` primero; tú hazlo en tu terminal.

### 3.3 Activar los hooks

```sh
sh scripts/setup_hooks.sh
```

El script:

- da permisos de ejecución a los hooks;
- configura `git config core.hooksPath .githooks`;
- crea enlaces en `.git/hooks`, para los clientes gráficos que ignoran `core.hooksPath`.

---

## 4. Verificar que todo funciona

Corre cada comando desde la raíz del repositorio, con el `PATH` de fvm. Anota el resultado real.

| # | Comando | Resultado esperado |
|---|---|---|
| 1 | `git config core.hooksPath` | `.githooks` |
| 2 | `sh scripts/check_sdk_version.sh && echo ok` | `ok` |
| 3 | `gitleaks git --pre-commit --staged --no-banner --redact` | `no leaks found` (es lo que hace el hook: revisa solo lo que vas a subir) |
| 4 | `osv-scanner scan source -L pubspec.lock` | `No issues found` |
| 5 | `dart run scripts/script_audit_architecture.dart` | `✅ [APROBADO]: Cero violaciones detectadas.` |
| 6 | `dart run scripts/script_audit_architecture.dart --modulos` | Tabla de módulos sin `⚠️` |
| 7 | `flutter analyze` | `No issues found!` |
| 8 | `sh .githooks/obligatorio.sh && echo ok` | `ok` |
| 9 | `git commit --allow-empty -m "chore: probar hooks"` y después `git reset --soft HEAD~1` | El pre-commit dice «No hay archivos modificados en el área de preparación» y el commit se crea: el hook está activo. El reset deshace el commit de prueba |

Opcional (tarda de 3 a 5 minutos): `flutter test --coverage`, y luego `sh scripts/check_coverage.sh 54` y `git fetch origin && dart run scripts/check_diff_coverage.dart`. Es lo mismo que hará el pre-push.

---

## 5. Qué hace cada hook

Los tres hooks principales (`pre-commit`, `pre-push`, `commit-msg`) son **comunes del kit de agentes** y se comparten entre proyectos: no se editan aquí. Las reglas propias de zas están en los archivos `.local` y en `obligatorio.sh`, y el hook común las llama.

### 5.1 `commit-msg`: al escribir el mensaje

- **Conventional Commits:** `tipo(área): descripción`, con tipo `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` o `revert`. El área va sin tildes ni eñes: `(ui)` sí, `(diseño)` no.
- **Un `fix` que toca `lib/` necesita su prueba de regresión** en `test/` (`commit-msg.local`, `scripts/check_fix_has_test.dart`). Si de verdad no aplica, agrega al mensaje una línea `Sin-prueba: <motivo>`.
- **Recordatorio de mcp-ia:** ¿cada causa corregida ya tiene su `add_solution`? Solo avisa, no bloquea.

### 5.2 `pre-commit`: al hacer el commit

| Gate | Qué revisa |
|---|---|
| 0 | Aplica `dart format` a los `.dart` del commit y los vuelve a agregar |
| 1 | Archivos sensibles y patrones de secretos |
| 2 | Marcas de conflicto, código de depuración, bypass de SSL y funciones con nombre repetido |
| 3 | `dart format` (comprobación) |
| 4 | `flutter analyze` de los archivos del commit |
| 5 | Reglas de zas (`.githooks/pre-commit.local`, abajo) |
| 6 | Las pruebas asociadas a los archivos del commit |

**Gate 5, reglas de zas, en este orden:**

1. **Versión de Flutter:** debe ser la de `.fvmrc` (`scripts/check_sdk_version.sh`).
2. **Secretos con `gitleaks`**, solo en lo que se va a subir.
3. **`pubspec.lock` coherente** con `pubspec.yaml`, si cambió alguno de los dos.
4. **Código generado al día** (`scripts/check_generated_code.sh`): si cambió un `.arb`, corre `flutter gen-l10n`; si cambió una tabla de drift, corre `build_runner`, que tarda unos minutos.
5. **Aviso** si hay cambios en `lib/` sin agregar: la auditoría también los ve.
6. **Sistema de diseño (DTCG):** sin tokens legacy u ordinales, sin `Color(0x…)` ni `Colors.X` fuera de `app_colors.dart` y `app_theme.dart`.
7. **ARC-002:** sin `setState()` en `lib/presentation/screens/`.
8. **Pruebas espejo:** un archivo nuevo de `lib/application` o `lib/infrastructure` trae su prueba (`scripts/check_layer_tests.dart`).
9. **Auditoría de toques:** las pantallas registran sus toques (`scripts/check_audited_screens.dart`).
10. **Tokens en todo el repositorio** (`scripts/verify_legacy_tokens.sh`).
11. **Auditoría ARC-001 a ARC-029 sobre todo `lib/`** (sección 6).

**`obligatorio.sh`** repite la auditoría ARC. Se ejecuta **siempre**, incluso si alguien pone `SKIP_PRE_COMMIT=1`.

### 5.3 `pre-push`: al subir

1. `flutter analyze` del proyecto completo.
2. `flutter test --coverage` con la suite completa.
3. Reglas de zas (`.githooks/pre-push.local`):
   - **Ramas protegidas:** no se sube directo a `dev`, `main` ni `master`; se usa un merge request. La excepción autorizada es `PERMITIR_PUSH_RAMA_PROTEGIDA=1 git push`.
   - Versión de Flutter y `pubspec.lock`.
   - **Vulnerabilidades** con `osv-scanner`. Sin conexión, solo avisa.
   - Auditoría ARC.
   - **Cobertura global** mínima de **54 %** (`scripts/check_coverage.sh`). El mínimo solo se sube, nunca se baja.
   - **Cobertura de las líneas cambiadas** frente a `origin/dev`: mínimo **80 %** (`scripts/check_diff_coverage.dart`).

---

## 6. Cómo funciona el auditor de arquitectura

`scripts/script_audit_architecture.dart` lee el **árbol sintáctico (AST)** de cada archivo de `lib/` con el paquete `analyzer`. Revisa todo `lib/`, no solo lo que cambiaste: **una violación en cualquier archivo bloquea el commit y el push de todo el equipo.**

### 6.1 Reglas

El detalle y los ejemplos están en `AGENTS.md` y en `.agents/rules/rule_arc_zero_tolerance.md`.

| Regla | Qué prohíbe |
|---|---|
| ARC-001, 006 | Importar capas en la dirección equivocada; `domain` es Dart puro |
| ARC-002, 003 | `setState` en pantallas; cubits o `flutter_bloc` dentro de `views/` |
| ARC-004, 012, 017 | URLs `http://`; `Dio` sin pinning de certificados; claves de cifrado en el código |
| ARC-005, 019 | El operador `!` |
| ARC-007, 008, 013 | `catch` vacío; casts `as String` sobre JSON; datasources que devuelven `e.toString()` |
| ARC-009, 010 | Más de 500 líneas o 15 imports por archivo |
| ARC-011, 014, 015, 016 | Cubits sin `SafeEmitMixin`; cubits que no se reinician al cerrar sesión; listeners sin `listenWhen`; `props` incompletos |
| ARC-018 | Leer el comercio de la sesión sin `getCurrentMerchantId()` |
| ARC-020 | Tokens, contraseñas, PIN, OTP, teléfonos o documentos dentro de un `Logger` |
| ARC-021 | `// ignore:` sin motivo |
| ARC-022 a 024 | Romper el flujo DDD (la presentación usa repositorios; `application` importa `infrastructure`; repositorios sin interfaz) |
| ARC-025 | Vistas y widgets de pantalla (`views/`, `widget/`, `widgets/`) que usan cubits, el locator o casos de uso |
| ARC-026 | Módulos con datos a los que les falta interfaz, repositorio o caso de uso |
| ARC-027 | Accesibilidad: `GestureDetector` sin `Semantics`, `IconButton` sin `tooltip`, imágenes sin `semanticLabel` |
| ARC-028 | Un `catch` genérico en application, infrastructure o cubits que no pasa por `CentralErrorHandler` (que audita con `AuditLogger`) ni relanza |
| ARC-029 | Pantallas con toques sin registrar en la auditoría de movimientos, en todo `lib/` |

### 6.2 `scripts/arc_config.json`

- **`excepciones`:** casos aprobados de ARC-001 a ARC-006, cada uno con `motivo` y fecha de `vence`. Al vencer, vuelven a contar como violación.
- **`linea_base`:** casos que ya existían para ARC-007 a 010, 018 a 020, 022, 025, 028 y 029. **No se pueden agregar archivos ni subir números, solo bajarlos.** Después de corregir, actualízala con `dart run scripts/script_audit_architecture.dart --generar-linea-base`; el script se niega a subirla.

### 6.3 Comandos

```sh
dart run scripts/script_audit_architecture.dart                       # auditoría (sale con 1 si hay violaciones)
dart run scripts/script_audit_architecture.dart --modulos             # flujo DDD y capa de diseño por módulo
dart run scripts/script_audit_architecture.dart --generar-linea-base  # baja la línea base tras corregir
```

**Los guardianes también se vigilan.** Si un commit cambia el auditor, su prueba, `arc_config.json` o los hooks, el pre-commit corre siempre la prueba del detector (`test/scripts/script_audit_architecture_test.dart`). Así nadie lo debilita sin que falle el commit.

---

## 7. Herramientas de apoyo

| Comando | Para qué |
|---|---|
| `dart run scripts/mr_report.dart` | Genera la descripción del merge request como informe ejecutivo (`build/mr_resumen.md`); `--rapido` omite la verificación |
| `flutter test integration_test/pantallas_en_dispositivo_test.dart -d <dispositivo> --dart-define=EN_DISPOSITIVO=true` | Corre las pruebas de pantallas en un emulador o teléfono. No suma a la cobertura del pre-push |
| `dart run scripts/check_diff_coverage.dart` | Cobertura de tus líneas cambiadas frente a `origin/dev` (requiere `flutter test --coverage` y `git fetch`) |

---

## 8. Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `Can't load Kernel binary: Invalid SDK hash` | Los scripts se compilaron con otro Flutter | `rm -rf .dart_tool/hooks_runner` y repite con `export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"` |
| `❌ Flutter X no es el del proyecto` | El `PATH` no usa el de fvm, o falta instalarlo | `fvm install`, luego `fvm use 3.47.7` y exporta el `PATH` |
| `No se pudo ejecutar la auditoría de arquitectura` | Error de compilación o SDK | Lee las últimas líneas que muestra; casi siempre es el caso anterior |
| `gitleaks encontró un posible secreto` | Hay una clave o un token en el código | Sácalo del código (almacenamiento seguro o `--dart-define`). Si es un falso positivo, se agrega a `.gitleaks.toml` solo con revisión |
| `gitleaks git .` (toda la historia) muestra 8 hallazgos | Ya conocidos: un JWT en `login_response.json` y claves en `env copy`/`env copy.dev` (solo en commits viejos), claves de Google en `AndroidManifest.xml` y `AppDelegate.swift`, y 2 falsos positivos en `ios/Podfile.lock` | No bloquean: el hook revisa solo lo nuevo. No los agregues a `.gitleaks.toml` sin revisión |
| `osv-scanner no pudo revisar…` | Sin conexión | Solo avisa; repite con red antes del merge |
| `Cobertura de las líneas cambiadas por debajo del mínimo` | Faltan pruebas de tu código | Escribe las pruebas; el script lista las líneas sin cubrir |
| `No se sube directo a 'dev'` | Push a una rama protegida | Sube tu rama y crea un merge request |
| `VIOLACIÓN ARC-009` en un archivo que solo tocaste | Superaste su línea base de líneas | Divide el archivo o mueve código; no subas la línea base |
| Un commit `fix` rechazado por falta de prueba | `check_fix_has_test.dart` | Agrega la prueba de regresión o la línea `Sin-prueba: <motivo>` |
| El pre-commit tarda minutos | Cambió una tabla de drift y corre `build_runner` | Es normal; solo pasa cuando cambian esas tablas |
| Tras un commit rechazado, `git checkout -- archivo` no deshace tu cambio | El archivo quedó agregado al índice | Usa `git checkout HEAD -- archivo` |

---

## 9. Prohibido

- `git commit --no-verify`, `git push --no-verify` y `SKIP_PRE_COMMIT=1`. Además, la auditoría ARC corre igual.
- Editar los hooks comunes (`pre-commit`, `pre-push`, `commit-msg`). Una mejora se comparte con `python3 <mcp-ia>/kit-agentes/kit_agentes.py hooks . --compartir`.
- Editar el auditor, su prueba, `arc_config.json` o `.gitleaks.toml` para que una violación pase.
- Bajar `COBERTURA_GLOBAL_MINIMA` en `.githooks/pre-push.local`.
