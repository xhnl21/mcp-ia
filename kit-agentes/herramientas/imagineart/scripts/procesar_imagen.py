"""Procesa imágenes generadas con ImagineArt para usarlas en un juego (solo Pillow).

    from procesar_imagen import bajar, sprite, tile, fondo
    sprite(id, 'salida.webp', 128)            # quita el fondo blanco, recorta y reduce
    tile(id, 'suelo.webp', 64)                # mosaico cuadrado, píxeles nítidos
    fondo(id, 'fondo.webp', (720, 1280))      # fondo vertical, JPEG -> webp

El id es el uuid que devuelve generate_image / generate_image_batch / generate_music.
"""
import io
import time
import urllib.request

from PIL import Image, ImageDraw


def bajar(id_asset: str, intentos: int = 45) -> bytes:
    """Descarga el asset; devuelve 404 mientras se genera, por eso reintenta."""
    for _ in range(intentos):
        try:
            return urllib.request.urlopen(f"https://asset.imagine.art/processed/{id_asset}", timeout=60).read()
        except Exception:
            time.sleep(8)
    raise SystemExit(f"PENDIENTE {id_asset}")


def sprite(id_asset, destino, tam=128, nearest=False, umbral=238):
    """Quita el fondo blanco (relleno desde las esquinas + casi blancos), recorta y reduce.
    umbral=256 conserva los blancos internos (nubes, brillos) y solo quita el relleno desde las esquinas."""
    im = Image.open(io.BytesIO(bajar(id_asset))).convert("RGBA")
    w, h = im.size
    for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if sum(im.getpixel(xy)[:3]) > 720:
            ImageDraw.floodfill(im, xy, (255, 255, 255, 0), thresh=60)
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and min(r, g, b) > umbral:
                px[x, y] = (r, g, b, 0)
    im = im.crop(im.getbbox())
    im.thumbnail((tam, tam), Image.NEAREST if nearest else Image.LANCZOS)
    im.save(destino, quality=88)
    return im.size


def tile(id_asset, destino, tam=64):
    Image.open(io.BytesIO(bajar(id_asset))).convert("RGB").resize((tam, tam), Image.NEAREST).save(destino, quality=90)


def fondo(id_asset, destino, tam=(720, 1280), nearest=False):
    Image.open(io.BytesIO(bajar(id_asset))).convert("RGB").resize(tam, Image.NEAREST if nearest else Image.LANCZOS).save(destino, quality=80)
