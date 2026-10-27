#!/usr/bin/env python3
"""Genera el ícono de la app y el logo del splash nativo a partir de marca.json.

Android usa íconos adaptativos: fondo + frente de 108 dp, de los que se ve el
círculo central de 66 dp recortado con la máscara del teléfono (MIUI, Pixel,
círculo…). flutter_launcher_icons añade un 16 % de margen al frente, así que
se ve casi todo el lienzo (98 %). `icono.escala_frente` (0,70 por defecto)
deja el símbolo dentro de la máscara circular.

Salida (carpeta `salida` de marca.json, por defecto assets/branding/):
  icono_fondo.png      degradado (fondo del ícono adaptativo)
  icono_frente.png     símbolo, transparente
  icono_monocromo.png  silueta en un color (íconos temáticos, Android 13+)
  icono_completo.png   ícono cuadrado opaco (Android < 8, iOS y tiendas)
  splash_logo.png      símbolo para el splash nativo (Android 12+)
  icono_vista_previa.png  el ícono con máscaras de MIUI, círculo y squircle

Uso:
  python generar_icono.py --config ruta/al/proyecto/marca.json
"""
import argparse

from PIL import Image, ImageDraw

from marca import Marca, degradado

LADO = 1024


def centrado(imagen, lado, escala):
    lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    tam = int(lado * escala)
    pieza = imagen.resize((tam, tam), Image.LANCZOS)
    lienzo.alpha_composite(pieza, ((lado - tam) // 2, (lado - tam) // 2))
    return lienzo


def vista_previa(fondo, frente, ruta):
    """El ícono con tres máscaras reales y a 48 px, para revisarlo de un vistazo."""
    base = fondo.convert("RGBA")
    base.alpha_composite(frente)
    lienzo = Image.new("RGBA", (1150, 300), (235, 235, 235, 255))
    for i, forma in enumerate(("cuadrado", "circulo", "squircle")):
        tam = 260
        pieza = base.resize((tam, tam), Image.LANCZOS)
        mascara = Image.new("L", (tam, tam), 0)
        d = ImageDraw.Draw(mascara)
        if forma == "circulo":
            d.ellipse((0, 0, tam - 1, tam - 1), fill=255)
        else:
            d.rounded_rectangle((0, 0, tam - 1, tam - 1), tam * (0.25 if forma == "cuadrado" else 0.42), fill=255)
        recorte = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
        recorte.paste(pieza, (0, 0), mascara)
        lienzo.alpha_composite(recorte, (20 + i * 280, 20))
    chico = base.resize((48, 48), Image.LANCZOS)
    lienzo.alpha_composite(chico, (900, 126))
    lienzo.save(ruta)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", default="marca.json")
    m = Marca(parser.parse_args().config)

    fondo = degradado(LADO, m.degradado[0], m.degradado[-1])
    fondo.save(m.ruta_salida("icono_fondo.png"))

    frente = centrado(m.simbolo_imagen(LADO), LADO, m.escala_frente)
    frente.save(m.ruta_salida("icono_frente.png"))

    mono = centrado(m.simbolo_imagen(LADO, solo_silueta=True), LADO, m.escala_frente)
    mono.save(m.ruta_salida("icono_monocromo.png"))

    completo = fondo.convert("RGBA")
    completo.alpha_composite(frente)
    completo.convert("RGB").save(m.ruta_salida("icono_completo.png"))

    # Android 12+ muestra el logo del splash dentro de un círculo de 2/3 del lienzo.
    centrado(m.simbolo_imagen(LADO), LADO, 0.62).save(m.ruta_salida("splash_logo.png"))

    vista_previa(fondo, frente, m.ruta_salida("icono_vista_previa.png"))
    print("Ícono, logo del splash y vista previa en", m.ruta_salida(""))


if __name__ == "__main__":
    main()
