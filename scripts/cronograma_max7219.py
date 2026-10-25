#!/usr/bin/env python3
# ============================================================================
#  cronograma_max7219.py
#  Dibuja el diagrama de tiempos DIN / CLK_LED / LOAD de UNA transferencia
#  (16 bits por chip: 64 con el módulo x4) sacada directamente del VCD de
#  tb_max7219.
#
#  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
#           David Eduardo Chivata Arias
#
#  Uso:  python3 scripts/cronograma_max7219.py [--transferencia N]
#        (N = 0 es la primera palabra de configuración, 5 la del dígito 1)
# ============================================================================

import argparse

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def leer_vcd(ruta, nombres):
    """Lector de VCD mínimo: solo señales de 1 bit en el primer alcance."""
    ids, cambios, t = {}, {n: [] for n in nombres}, 0
    with open(ruta) as f:
        en_defs = True
        for linea in f:
            linea = linea.strip()
            if en_defs:
                if linea.startswith("$var"):
                    partes = linea.split()
                    nombre = partes[4]
                    if nombre in nombres and partes[3] not in ids:
                        ids[partes[3]] = nombre
                elif linea.startswith("$enddefinitions"):
                    en_defs = False
                continue
            if not linea:
                continue
            if linea[0] == "#":
                t = int(linea[1:])
            elif linea[0] in "01xz" and linea[1:] in ids:
                v = 1 if linea[0] == "1" else 0
                cambios[ids[linea[1:]]].append((t, v))
    return cambios


def valor_en(serie, t):
    v = 0
    for tc, vc in serie:
        if tc > t:
            break
        v = vc
    return v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vcd", default="sim/tb_max7219.vcd")
    ap.add_argument("--transferencia", type=int, default=5)
    ap.add_argument("--salida", default="docs/img/cronograma_max7219.png")
    args = ap.parse_args()

    s = leer_vcd(args.vcd, ["din_a", "clk_a", "load_a"])
    subidas_load = [t for t, v in s["load_a"] if v == 1]
    # solo las bajadas que siguen a un pulso real (el paso de X a 0 del reinicio no cuenta)
    bajadas_load = [t for t, v in s["load_a"] if v == 0 and t > subidas_load[0]]
    n = args.transferencia
    t_ini = bajadas_load[n - 1] if n > 0 else 0
    t_fin = [t for t in bajadas_load if t > subidas_load[n]][0] + 200_000

    # Bits leídos en cada flanco de subida de CLK
    flancos = [t for t, v in s["clk_a"] if v == 1 and t_ini < t < subidas_load[n]]
    bits = [valor_en(s["din_a"], t - 1) for t in flancos]
    palabra = int("".join(map(str, bits)), 2)

    n_chips = len(flancos) // 16
    fig, ax = plt.subplots(figsize=(8 + 3.5 * n_chips, 4.2))
    escala = 1e-6   # ps -> us
    for i, (nombre, etiqueta) in enumerate([("load_a", "LOAD"), ("clk_a", "CLK_LED"), ("din_a", "DIN")]):
        base = i * 1.6
        xs, ys = [t_ini * escala], [valor_en(s[nombre], t_ini) + base]
        for t, v in s[nombre]:
            if t_ini < t < t_fin:
                xs += [t * escala, t * escala]
                ys += [ys[-1], v + base]
        xs.append(t_fin * escala)
        ys.append(ys[-1])
        ax.plot(xs, ys, lw=1.6, color=["#c0392b", "#2c3e50", "#1f77b4"][i])
        ax.text(t_ini * escala - 1.5, base + 0.4, etiqueta, ha="right", va="center", fontsize=11, weight="bold")

    # Etiquetas de los bits encima de DIN
    for k, t in enumerate(flancos):
        bit = 15 - (k % 16)
        ax.text(t * escala, 4.35, f"D{bit}", ha="center", fontsize=5.5, rotation=90,
                color="#555" if bit > 11 else ("#8e44ad" if bit > 7 else "#16a085"))
    # Separadores entre las palabras de cada chip. La primera palabra que sale
    # termina en el chip más lejano (posición N-1) y la última en el cercano (0).
    for g in range(n_chips):
        ini = flancos[16 * g] * escala
        fin = flancos[16 * g + 15] * escala
        if g > 0:
            ax.axvline((flancos[16 * g - 1] + flancos[16 * g]) / 2 * escala, color="#999", ls="--", lw=0.8)
        pos = n_chips - 1 - g
        nombre = "cercano" if pos == 0 else ("más lejano" if pos == n_chips - 1 else "")
        ax.text((ini + fin) / 2, 5.0, f"→ chip {pos} {nombre}".strip(), ha="center", fontsize=9)

    ax.set_ylim(-0.4, 5.4)
    ax.set_yticks([])
    ax.set_xlabel("tiempo [µs]  (CLK_LED = 1 MHz, DIV_CLK = 25 con reloj de 50 MHz)")
    palabras = [(palabra >> (16 * (n_chips - 1 - g))) & 0xFFFF for g in range(n_chips)]
    ax.set_title(f"Transferencia #{n} hacia {n_chips} MAX7219 en cascada: "
                 + ",  ".join(f"0x{w:04X}" for w in palabras), fontsize=12)
    for lado in ("top", "right", "left"):
        ax.spines[lado].set_visible(False)
    fig.tight_layout()
    fig.savefig(args.salida, dpi=130)
    print(f"Trama 0x{palabra:0{4 * n_chips}X} ({n_chips} chips) -> {args.salida}")


if __name__ == "__main__":
    main()
