# Schema de base de datos (SQLite + FTS5)

Archivo: `data/flutter_memory.db`. Se crea automáticamente (WAL mode, índice full-text).

## Modelo relacional

### `categorias`
| columna | tipo | nota |
|---------|------|------|
| id | INTEGER PK | |
| nombre | TEXT UNIQUE | slug p.ej. `compilacion` |
| descripcion | TEXT | |

### `tags`
| columna | tipo | nota |
|---------|------|------|
| id | INTEGER PK | |
| nombre | TEXT UNIQUE | |
| usos | INTEGER | nº de soluciones que lo usan |

### `soluciones` (tabla principal)
| columna | tipo | nota |
|---------|------|------|
| id | INTEGER PK | |
| titulo | TEXT NOT NULL | |
| problema | TEXT NOT NULL | |
| solucion | TEXT NOT NULL | |
| categorias_id | INTEGER FK→categorias | |
| url | TEXT | |
| fuente | TEXT | `manual/stackoverflow/github/awesome/flutterdocs` |
| lenguaje | TEXT default `dart` | |
| framework | TEXT default `flutter` | |
| veces_usada | INTEGER default 0 | ↑ con `fm usar` |
| veces_buscada | INTEGER default 0 | ↑ sola al aparecer en resultados |
| veces_resuelta | INTEGER default 0 | ↑ con `fm usar` (doble peso) |
| last_used | TEXT | |
| creada_en / actualizada_en | TEXT | |
| hash | TEXT UNIQUE | dedupe (sha256 titulo+problema+solucion) |

### `solucion_tag` (N:M)
| columna | tipo |
|---------|------|
| solucion_id | INTEGER FK→soluciones (CASCADE) |
| tag_id | INTEGER FK→tags (CASCADE) |
| PK | (solucion_id, tag_id) |

### `patrones_error` (detección de recurrencia)
| columna | tipo |
|---------|------|
| id | INTEGER PK |
| texto_deteccion | TEXT | substring/patrón a buscar |
| etiqueta | TEXT UNIQUE | nombre corto p.ej. `MissingPluginException` |
| conteo | INTEGER | veces detectado |
| solucion_id | INTEGER FK | solución recomendada |

### `soluciones_fts` (virtual FTS5)
Índice full-text sobre `(titulo, problema, solucion)` con triggers `ai/ad/au`
que lo mantienen sincronizado automáticamente. Permite `MATCH` e `bm25()` ranking.

## Por qué esta combinación escala

- **FTS5**: búsqueda full-text nativa y muy rápida; tolerante a palabras incompletas
  (usa sufijo `*`).
- **Fuzzy (rapidfuzz)**: recupera errores con typos o variaciones de escritura
  que el FTS exacto no captaría.
- **Índice de frecuencia**: prioriza lo que más te ha funcionado.
- **WAL mode**: lecturas concurrentes sin bloqueo, ideal para consultas desde el CLI
  y desde un script de captura simultánea.
- **Hash único**: evita duplicados al re-importar.

## Escalar a "miles de soluciones"

- El FTS5 + LIMIT temprano (500 candidatos → top N) mantiene la búsqueda <100 ms
  incluso con 10k+ filas.
- Si algún día quieres más: periódicamente ejecuta `VACUUM` y mantén el índice FTS
  con un `rebuild` tras grandes importes (opcional).
