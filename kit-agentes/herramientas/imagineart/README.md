# ImagineArt (servidor MCP) para juegos y apps

Servidor MCP remoto `https://mcp.imagine.art`: imágenes, video, música y efectos de sonido. No se «inicia»: se registra una vez y se autoriza a mano.

## Puesta en marcha

```sh
sh <mcp-ia>/kit-agentes/herramientas/imagineart/scripts/imagine_mcp.sh   # registra y muestra el estado
```
- **Autorizar** solo se puede en una sesión **interactiva** (`/mcp` → imagine) o desde los conectores de claude.ai; una sesión no interactiva responde «needs to sign in again» y no hay forma de saltarlo.
- Las herramientas se cargan **al abrir la sesión**: tras autorizar hay que abrir una sesión nueva.
- **Cambiar de cuenta de Claude** a mitad de una tarea invalida la autorización: hay que repetirla.
- Con varias organizaciones, `select_organization`. Los modelos de pago (p. ej. `seedream-v5-pro`) solo van en la organización personal; la de equipo gratuita no los permite.

## Costos medidos (organización personal, 2026-11)
| Qué | Créditos |
|---|---|
| Imagen `seedream-v5-pro` (cualquier relación de aspecto) | 30 |
| Efecto de sonido (`generate_sound_effect`) | ~3 |
| Música `generate_music` | ~270 a 10 s, ~500 a 45 s (el costo fijo es alto: no conviene pedir muchas pistas) |
| Video `ltx-2.3`, 6 s, 9:16 | ~215 |

Mide siempre **una** llamada con `get_balance` antes de lanzar un lote.

## Reglas que ahorran créditos y tiempo
- **Máximo 10 generaciones simultáneas** por organización (imágenes, música y video cuentan). Un lote que excede el límite se acepta a medias o falla; comprueba que `assets` traiga tantas entradas como prompts.
- Un lote de imágenes admite hasta 8 prompts.
- Descarga de `https://asset.imagine.art/processed/<id>`; devuelve 404 mientras se genera: reintenta (`scripts/procesar_imagen.py`).
- **Un personaje que debe parecerse a un modelo:** nunca generes solo con texto. Sube una referencia pequeña, genera primero un **fotograma fijo** con `image_url` (30 créditos), revisa que se parezca y **después** anima ese fotograma con `generate_video`. Un video hecho solo con texto sale con otro personaje.
- `user_upload` (base64) falla con imágenes grandes porque el agente transcribe el texto a mano: reduce la referencia a un PNG cuantizado de ~1,5 KB (64×105 px, 8 colores) y sube eso. `request_image_upload` no sirve en sesión no interactiva.
- Para sprites pide «on a plain solid white background» y quita el fondo con `sprite()`; para mosaicos pide «seamless tileable … fills the whole image edge to edge».
- Si el modelo de video no deja ver el parecido, compón con Pillow a partir del modelo real (recortes de la hoja de personaje) en vez de gastar más créditos.

## Procesado
`scripts/procesar_imagen.py` (solo Pillow): `bajar`, `sprite`, `tile`, `fondo`. Los videos se comprimen con `imageio-ffmpeg` (`python3 -m pip install --user imageio-ffmpeg`): 540 px de ancho, `-crf 28`, bajan de ~6 MB a ~0,4 MB.

Origen: GameIVP (100 mundos Kepler), noviembre 2026.
