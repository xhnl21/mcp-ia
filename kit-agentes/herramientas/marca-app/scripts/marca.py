"""Núcleo compartido de la skill marca-app: configuración, colores y símbolos.

Lee `marca.json` del proyecto (ver ../ejemplos/) y dibuja el símbolo de la
app (carrete, monograma o una imagen propia). Todo se dibuja a 4x y se reduce
con LANCZOS para suavizar los bordes.
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTES = os.path.join(AQUI, "..", "fonts")

POR_DEFECTO = {
    "pie": "desarrollado por",
    "frase": "",
    "simbolo": {"tipo": "carrete", "cinta": True, "girar": True},
    "colores": {
        "fondo_splash": "#081830",
        "degradado": ["#1565C0", "#0D2E63"],
        "simbolo": "#FFFFFF",
        "acento": "#FFC107",
        "frase": "#42A5F5",
        "pie": "#AABEDC",
        "organizacion": "#FFFFFF",
    },
    "icono": {"escala_frente": 0.70},
    "video": {"ancho": 720, "alto": 1280, "fps": 30, "duracion": 3.6},
    "salida": "assets/branding",
}


def hex_a_rgb(valor):
    valor = valor.lstrip("#")
    return tuple(int(valor[i : i + 2], 16) for i in (0, 2, 4))


def _mezclar(base, extra):
    salida = dict(base)
    for clave, valor in extra.items():
        if isinstance(valor, dict) and isinstance(salida.get(clave), dict):
            salida[clave] = _mezclar(salida[clave], valor)
        else:
            salida[clave] = valor
    return salida


class Marca:
    """Configuración de marca de un proyecto (marca.json + valores por defecto)."""

    def __init__(self, ruta_config):
        self.ruta_config = os.path.abspath(ruta_config)
        self.raiz = os.path.dirname(self.ruta_config)
        with open(self.ruta_config, encoding="utf-8") as f:
            datos = _mezclar(POR_DEFECTO, json.load(f))
        for obligatorio in ("app", "organizacion"):
            if not datos.get(obligatorio):
                raise SystemExit(f"marca.json: falta «{obligatorio}».")
        self.datos = datos
        self.app = datos["app"]
        self.organizacion = datos["organizacion"]
        self.frase = datos["frase"]
        self.pie = datos["pie"]
        self.simbolo = datos["simbolo"]
        c = datos["colores"]
        self.fondo_splash = hex_a_rgb(c["fondo_splash"])
        self.degradado = [hex_a_rgb(x) for x in c["degradado"]]
        self.color_simbolo = hex_a_rgb(c["simbolo"])
        self.acento = hex_a_rgb(c["acento"])
        self.color_frase = hex_a_rgb(c["frase"])
        self.color_pie = hex_a_rgb(c["pie"])
        self.color_organizacion = hex_a_rgb(c["organizacion"])
        # Título del splash: [["Reel", "#FFFFFF"], ["Keeper", "#FFC107"]] o el nombre en blanco.
        self.titulo = [(t, hex_a_rgb(col)) for t, col in datos.get("titulo", [[self.app, "#FFFFFF"]])]
        self.escala_frente = datos["icono"]["escala_frente"]
        self.video = datos["video"]

    def ruta_salida(self, *partes):
        """Ruta de salida, relativa a la carpeta de marca.json (raíz del proyecto)."""
        ruta = os.path.join(self.raiz, self.datos["salida"], *partes)
        os.makedirs(os.path.dirname(ruta), exist_ok=True)
        return ruta

    def simbolo_imagen(self, lado, angulo=0.0, escala=4, solo_silueta=False):
        """Símbolo de la app sobre fondo transparente, de `lado` x `lado` px."""
        tipo = self.simbolo.get("tipo", "carrete")
        color = self.color_simbolo
        acento = None if solo_silueta else self.acento
        if tipo == "carrete":
            return carrete(lado, color, acento, angulo, self.simbolo.get("cinta", True), escala)
        if tipo == "monograma":
            fondo_letras = None if solo_silueta else self.degradado[-1]
            return monograma(lado, self.simbolo.get("texto", self.app[:2]), color, fondo_letras, escala)
        if tipo == "imagen":
            ruta = os.path.join(self.raiz, self.simbolo["ruta"])
            img = Image.open(ruta).convert("RGBA")
            img.thumbnail((lado, lado), Image.LANCZOS)
            lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
            lienzo.alpha_composite(img, ((lado - img.width) // 2, (lado - img.height) // 2))
            if solo_silueta:
                blanco = Image.new("RGBA", lienzo.size, (255, 255, 255, 255))
                blanco.putalpha(lienzo.getchannel("A"))
                return blanco
            return lienzo
        raise SystemExit(f"marca.json: simbolo.tipo «{tipo}» no existe (carrete, monograma o imagen).")

    @property
    def gira(self):
        return self.simbolo.get("girar", self.simbolo.get("tipo") == "carrete")


def fuente(peso, tam):
    return ImageFont.truetype(os.path.join(FUENTES, f"Montserrat-{peso}.ttf"), tam)


def degradado(lado, c1, c2):
    """Degradado diagonal de c1 (arriba a la izquierda) a c2 (abajo a la derecha)."""
    import numpy as np

    eje = np.linspace(0.0, 1.0, lado)
    t = (eje[None, :] + eje[:, None]) / 2.0
    a = np.array(c1, dtype=float)
    b = np.array(c2, dtype=float)
    pixeles = a + (b - a) * t[..., None]
    return Image.fromarray(pixeles.round().astype("uint8"), "RGB")


def carrete(lado, color, play, angulo=0.0, cinta=True, escala=4):
    """Carrete de película con botón de reproducir (`play` = None lo omite)."""
    L = lado * escala
    img = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = L / 2
    R = L * 0.40
    transparente = (0, 0, 0, 0)

    if cinta:
        ancho = R * 0.34
        y0 = cy + R - ancho
        d.rounded_rectangle((cx, y0, cx + R * 1.15, y0 + ancho), radius=ancho * 0.18, fill=color)
        for i in range(4):
            px = cx + R * (0.40 + i * 0.20)
            d.rectangle((px, y0 + ancho * 0.18, px + R * 0.09, y0 + ancho * 0.36), fill=transparente)
            d.rectangle((px, y0 + ancho * 0.64, px + R * 0.09, y0 + ancho * 0.82), fill=transparente)

    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=color)

    radio_orbita = R * 0.60
    radio_agujero = R * 0.20
    for i in range(5):
        a = math.radians(angulo + i * 72 - 90)
        hx = cx + radio_orbita * math.cos(a)
        hy = cy + radio_orbita * math.sin(a)
        d.ellipse(
            (hx - radio_agujero, hy - radio_agujero, hx + radio_agujero, hy + radio_agujero),
            fill=transparente,
        )

    if play is not None:
        t = R * 0.30
        puntos = [(cx - t * 0.45, cy - t * 0.78), (cx - t * 0.45, cy + t * 0.78), (cx + t * 0.90, cy)]
        d.polygon(puntos, fill=play)
        d.line(puntos + [puntos[0]], fill=play, width=int(t * 0.18), joint="curve")

    return img.resize((lado, lado), Image.LANCZOS)


def monograma(lado, texto, color, color_letras, escala=4):
    """Círculo con iniciales. Con `color_letras` = None, las letras quedan caladas."""
    L = lado * escala
    img = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = L * 0.40
    d.ellipse((L / 2 - R, L / 2 - R, L / 2 + R, L / 2 + R), fill=color)
    tam = int(R * (1.05 if len(texto) <= 2 else 0.75))
    letra = fuente("Bold", tam)
    relleno = (0, 0, 0, 0) if color_letras is None else color_letras
    d.text((L / 2, L / 2), texto, font=letra, fill=relleno, anchor="mm")
    return img.resize((lado, lado), Image.LANCZOS)
