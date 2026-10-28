#!/usr/bin/env python3
"""Genera el video del splash y su primer cuadro a partir de marca.json.

El video empieza como el splash nativo (símbolo centrado y opaco sobre
`fondo_splash`) para que la transición sea continua. Después el símbolo crece
con un pequeño rebote (y gira si `simbolo.girar`), sube, entra el título,
la frase y abajo «<pie> <organizacion>».

Salida (carpeta `salida` de marca.json):
  splash.mp4                H.264 yuv420p + faststart (lo reproduce video_player)
  splash_primer_cuadro.png  se muestra mientras carga el video (sin parpadeo)

Uso:
  python generar_video_splash.py --config marca.json
  python generar_video_splash.py --config marca.json --cuadros 0.3,1.2,2.0,3.4
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

from marca import Marca, fuente

LADO_SIMBOLO = 360  # sobre 720 px de ancho: tamaño aparente del logo del splash nativo


def tramo(t, inicio, fin):
    return min(1.0, max(0.0, (t - inicio) / (fin - inicio)))


def suave(x):
    return x * x * (3 - 2 * x)


def rebote(x):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


class Escena:
    def __init__(self, marca):
        self.m = marca
        v = marca.video
        self.ancho, self.alto = v["ancho"], v["alto"]
        self.fps, self.duracion = v["fps"], v["duracion"]
        # Las tipografías escalan con el ancho (diseñado sobre 720 px).
        k = self.ancho / 720
        largo_titulo = sum(len(t) for t, _ in marca.titulo)
        self.f_titulo = fuente("Bold", int(84 * k * min(1.0, 10 / max(10, largo_titulo))))
        self.f_frase = fuente("Medium", int(34 * k))
        self.f_pie = fuente("Medium", int(26 * k))
        self.f_org = fuente("SemiBold", int(40 * k))
        self.lado_simbolo = int(LADO_SIMBOLO * k)

    def linea(self, capa, y, partes, alfa):
        d = ImageDraw.Draw(capa)
        ancho = sum(d.textlength(txt, font=f) for txt, f, _ in partes)
        x = (self.ancho - ancho) / 2
        for txt, f, color in partes:
            d.text((x, y), txt, font=f, fill=color + (int(255 * alfa),), anchor="ls")
            x += d.textlength(txt, font=f)

    def cuadro(self, t):
        m = self.m
        img = Image.new("RGBA", (self.ancho, self.alto), m.fondo_splash + (255,))

        entrada = rebote(tramo(t, 0.0, 0.6))
        subida = suave(tramo(t, 0.6, 1.4))
        escala = (0.85 + 0.15 * entrada) * (1 - 0.25 * subida)
        lado = max(2, int(self.lado_simbolo * escala))
        angulo = 140 * t if m.gira else 0.0
        # Hasta que el símbolo entra, quieto como el splash nativo (todas las
        # ondas visibles: sin parpadeo); después las ondas salen.
        fase = t - 0.6 if m.pulsa and t >= 0.6 else None
        # Sin aparición gradual: el splash nativo ya muestra el símbolo opaco.
        pieza = m.simbolo_imagen(lado, angulo=angulo, escala=2, fase=fase)
        cy = self.alto * (0.5 - 0.14 * subida)
        img.alpha_composite(pieza, (int(self.ancho / 2 - lado / 2), int(cy - lado / 2)))

        capa = Image.new("RGBA", (self.ancho, self.alto), (0, 0, 0, 0))
        p = suave(tramo(t, 1.0, 1.8))
        if p > 0:
            partes = [(txt, self.f_titulo, color) for txt, color in m.titulo]
            self.linea(capa, self.alto * 0.62 + 40 * (1 - p), partes, p)
        p = suave(tramo(t, 1.6, 2.3))
        if p > 0 and m.frase:
            self.linea(capa, self.alto * 0.67 + 20 * (1 - p), [(m.frase, self.f_frase, m.color_frase)], p)
        p = suave(tramo(t, 2.2, 2.9))
        if p > 0:
            if m.pie:
                self.linea(capa, self.alto * 0.90, [(m.pie, self.f_pie, m.color_pie)], p)
            self.linea(capa, self.alto * 0.935, [(m.organizacion, self.f_org, m.color_organizacion)], p)

        img.alpha_composite(capa)
        return img.convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", default="marca.json")
    parser.add_argument("--cuadros", help="instantes (s) a guardar como PNG para revisar, separados por coma")
    args = parser.parse_args()
    m = Marca(args.config)
    escena = Escena(m)

    if args.cuadros:
        for s in args.cuadros.split(","):
            ruta = m.ruta_salida(f"splash_cuadro_{s}s.png")
            escena.cuadro(float(s)).save(ruta)
            print(ruta)
        return

    import imageio_ffmpeg

    salida = m.ruta_salida("splash.mp4")
    escritor = imageio_ffmpeg.write_frames(
        salida,
        (escena.ancho, escena.alto),
        fps=escena.fps,
        codec="libx264",
        pix_fmt_out="yuv420p",
        output_params=["-crf", "26", "-preset", "slow", "-movflags", "+faststart"],
        macro_block_size=16,
    )
    escritor.send(None)
    total = int(escena.duracion * escena.fps)
    for i in range(total):
        escritor.send(np.asarray(escena.cuadro(i / escena.fps)).tobytes())
    escritor.close()
    escena.cuadro(0.0).save(m.ruta_salida("splash_primer_cuadro.png"), optimize=True)
    print(f"{salida} ({total} cuadros, {os.path.getsize(salida) // 1024} KB) y splash_primer_cuadro.png")


if __name__ == "__main__":
    main()
