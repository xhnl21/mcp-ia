# Sistema de tags y categorías para errores Flutter

## Categorías (nivel 1 — el "dónde")

| Categoría | Slug | Ejemplos |
|-----------|------|----------|
| Compilación | `compilacion` | `dart analyze`, errores de tipos, build |
| Runtime | `runtime` | Excepciones, LateInitializationError, null check |
| Widgets | `widgets` | Layout, render, keys, build errors |
| Estado | `estado` | Provider, Riverpod, Bloc, setState |
| Asincronía | `asincronia` | Future, Stream, async/await, isolate |
| Red | `red` | HTTP, Dio, WebSockets, conectividad |
| Persistencia | `persistencia` | Hive, SharedPreferences, sqflite, Drift |
| Dependencias | `dependencias` | pub, versionado, conflictos |
| Plataforma | `plataforma` | Android/iOS/web, plugins nativos |
| Testing | `testing` | test, mockito, integration test |
| Performance | `performance` | FPS, memoria, jank |
| Build errors | `build_errors` | Gradle, Kotlin, Xcode |

Usa `--cat <slug>` al agregar.

## Tags (nivel 2 — el "qué")

Tags libres y granulares. Convención: **minúsculas, sin espacios**, separa con `-`.

| Área | Tags recomendados |
|------|-------------------|
| Excepciones | `missingpluginexception`, `nullcheck`, `lateinit` |
| Estado | `provider`, `riverpod`, `bloc`, `context`, `dispose` |
| Null safety | `null-safety`, `nullable`, `non-null` |
| Widgets | `key`, `listview`, `constrainedbox`, `overflow` |
| Red | `http`, `dio`, `json`, `api` |
| Persistencia | `hive`, `sharedpreferences`, `sqflite`, `drift` |
| Construcción | `gradle`, `kotlin`, `xcode`, `android`, `ios` |
| Fuente | `stackoverflow`, `github`, `docs`, `awesome`, `recurso` |

## Buenas prácticas

1. **Categoría siempre** que se pueda (agrupa el reporte).
2. **2–4 tags** por solución es suficiente.
3. Usa tags de **excepción** (p.ej. `missingpluginexception`) para que fuzzy search
   los encuentre aunque escribas con variaciones.
4. Los tags de **fuente** ayudan a saber de dónde vino cada solución.

## Frecuencia (cómo el sistema "recuerda" lo útil)

- `veces_usada`: sube con `fm usar <id>` → incrementa el ranking.
- `veces_resuelta`: sube con `fm usar <id>` (por defecto) → doble peso.
- `veces_buscada`: sube sola cuando aparece en resultados → para reportes.

Las soluciones con más usos/resoluciones aparecen **primero** en las búsquedas.
