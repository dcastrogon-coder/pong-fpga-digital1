#!/usr/bin/env python3
# ============================================================================
#  animar_partida.py
#  Convierte el registro de la simulación de integración (sim/partida.txt)
#  en un GIF que se ve como la matriz LED real con los dos marcadores.
#
#  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
#           David Eduardo Chivata Arias
#
#  Ojo: lo que dibujamos NO es la imagen interna del diseño, sino lo que
#  quedó guardado en los registros de los dos modelos de MAX7219 después de
#  recibir las tramas seriales. O sea, es lo que de verdad veríamos en los LEDs.
#
#  Uso:
#      python3 scripts/animar_partida.py                 # GIF de los primeros 20 s
#      python3 scripts/animar_partida.py --desde 0 --hasta 40 --salida docs/img/otra.gif
# ============================================================================

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ESTADOS = {0: "ESPERA", 1: "JUEGO", 2: "PUNTO", 3: "PAUSA", 4: "FIN"}

# Colores pensados para parecerse a los módulos rojos con MAX7219
FONDO      = (18, 20, 24)
PLACA      = (12, 70, 45)       # el PCB verde de los módulos
LED_ON     = (255, 45, 35)
LED_BRILLO = (255, 140, 120)
LED_OFF    = (60, 22, 22)
SEG_ON     = (255, 60, 40)
SEG_OFF    = (50, 25, 25)
TEXTO      = (220, 220, 220)

# Segmentos de un display: (x0, y0, x1, y1) relativos a una celda de 40 x 70
SEGMENTOS = {
    "a": (8, 0, 32, 6),
    "b": (32, 4, 38, 34),
    "c": (32, 38, 38, 68),
    "d": (8, 66, 32, 72),
    "e": (2, 38, 8, 68),
    "f": (2, 4, 8, 34),
    "g": (8, 33, 32, 39),
}
DIGITOS = {
    0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg",
    5: "acdfg", 6: "acdefg", 7: "abc", 8: "abcdefg", 9: "abcdfg",
}


def leer_registro(ruta):
    cuadros = []
    for linea in Path(ruta).read_text().splitlines():
        if not linea or linea.startswith("#"):
            continue
        t, est, p1, p2, pix = linea.split()
        cuadros.append((int(t), int(est), int(p1), int(p2), pix))
    return cuadros


def fuente(tam):
    for nombre in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(nombre, tam)
        except OSError:
            pass
    return ImageFont.load_default()


def dibujar_display(d, x, y, valor):
    encendidos = DIGITOS.get(valor, "g")
    d.rounded_rectangle((x - 8, y - 8, x + 48, y + 82), 6, fill=(25, 25, 28))
    for nombre, (x0, y0, x1, y1) in SEGMENTOS.items():
        color = SEG_ON if nombre in encendidos else SEG_OFF
        d.rounded_rectangle((x + x0, y + y0, x + x1, y + y1), 2, fill=color)


def dibujar_cuadro(t, est, p1, p2, pix, f_txt, f_peq):
    cols = len(pix) // 8      # 16 con dos matrices, 32 con el módulo x4
    n_mod = cols // 8
    paso = 26 if cols <= 16 else 20   # separación entre LEDs
    radio = 9 if cols <= 16 else 7
    margen_x, margen_y = 110, 40
    hueco = 14 if cols <= 16 else 4   # en el módulo x4 las matrices van casi pegadas
    ancho = margen_x * 2 + cols * paso + hueco * (n_mod - 1)
    alto = margen_y + 8 * paso + 70

    img = Image.new("RGB", (ancho, alto), FONDO)
    d = ImageDraw.Draw(img)

    # Placas de los módulos
    for m in range(n_mod):
        x0 = margen_x + m * (8 * paso + hueco) - 8
        d.rounded_rectangle((x0, margen_y - 8, x0 + 8 * paso + 2, margen_y + 8 * paso + 2), 6, fill=PLACA)

    for f in range(8):
        for c in range(cols):
            cx = margen_x + c * paso + hueco * (c // 8) + paso // 2 - 4
            cy = margen_y + f * paso + paso // 2 - 4
            on = pix[f * cols + c] == "1"
            if on:
                d.ellipse((cx - radio - 3, cy - radio - 3, cx + radio + 3, cy + radio + 3), fill=(120, 25, 20))
                d.ellipse((cx - radio, cy - radio, cx + radio, cy + radio), fill=LED_ON)
                d.ellipse((cx - 4, cy - 5, cx + 2, cy + 1), fill=LED_BRILLO)
            else:
                d.ellipse((cx - radio, cy - radio, cx + radio, cy + radio), fill=LED_OFF)

    # Marcadores a los lados
    dibujar_display(d, 30, margen_y + 8 * paso // 2 - 40, p1)
    dibujar_display(d, ancho - 70, margen_y + 8 * paso // 2 - 40, p2)
    d.text((32, margen_y - 10), "J1", font=f_txt, fill=TEXTO)
    d.text((ancho - 66, margen_y - 10), "J2", font=f_txt, fill=TEXTO)

    # Barra inferior con tiempo y estado
    y_txt = margen_y + 8 * paso + 22
    d.text((margen_x - 8, y_txt), f"t = {t / 1000:6.2f} s", font=f_peq, fill=TEXTO)
    d.text((ancho // 2 - 40, y_txt), ESTADOS.get(est, "?"), font=f_txt, fill=(255, 210, 90))
    d.text((ancho - margen_x - 150, y_txt), "simulación RTL", font=f_peq, fill=(150, 150, 150))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--registro", default="sim/partida.txt")
    ap.add_argument("--salida", default="docs/img/partida_simulada.gif")
    ap.add_argument("--desde", type=float, default=0.0, help="segundo inicial")
    ap.add_argument("--hasta", type=float, default=20.0, help="segundo final")
    ap.add_argument("--cada", type=int, default=2, help="usar uno de cada N cuadros (40 ms cada uno)")
    ap.add_argument("--foto", default="docs/img/pantalla_simulada.png",
                    help="cuadro suelto en PNG para el README")
    args = ap.parse_args()

    cuadros = leer_registro(args.registro)
    sel = [c for c in cuadros if args.desde * 1000 <= c[0] <= args.hasta * 1000][:: args.cada]
    if not sel:
        raise SystemExit("No hay cuadros en ese intervalo; ¿corriste tb_integracion?")

    f_txt, f_peq = fuente(20), fuente(15)
    imagenes = [dibujar_cuadro(*c, f_txt, f_peq) for c in sel]
    # Paleta reducida para que el GIF no pese tanto
    imagenes = [im.convert("P", palette=Image.ADAPTIVE, colors=32) for im in imagenes]
    Path(args.salida).parent.mkdir(parents=True, exist_ok=True)
    imagenes[0].save(args.salida, save_all=True, append_images=imagenes[1:],
                     duration=40 * args.cada, loop=0, optimize=True)
    print(f"GIF con {len(imagenes)} cuadros -> {args.salida}")

    # Foto: el primer cuadro en JUEGO con la pelota lejos de las paletas
    for c in cuadros:
        if c[1] == 1 and c[0] > 3000 and c[4].count("1") == 7:
            dibujar_cuadro(*c, f_txt, f_peq).save(args.foto)
            print(f"Foto -> {args.foto}")
            break


if __name__ == "__main__":
    main()
