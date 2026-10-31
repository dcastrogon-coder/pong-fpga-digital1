#!/usr/bin/env python3
# ============================================================================
#  graficar_etapa1.py
#  Saca las dos figuras de la simulación de la etapa 1:
#    1. etapa1_ondas.png    -> DIN, CLK_LED, LOAD y el estado de la FSM del
#                              transmisor, leídos del VCD de tb_etapa1.
#    2. etapa1_pantallas.png -> cómo se ve la pantalla 8 x 32 en algunos
#                              pasos, armada con los registros de los 4 chips.
#
#  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
#           David Eduardo Chivata Arias
#
#  Uso (desde etapas/etapa1_pantalla, después de correr la simulación):
#      python3 graficar_etapa1.py
# ============================================================================

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

AQUI = Path(__file__).resolve().parent
SALIDA = AQUI.parent.parent / "docs" / "paso_a_paso" / "img"

ESTADOS = {0: "CARGA", 1: "BAJO", 2: "ALTO", 3: "CIERRE", 4: "LATCH", 5: "SEPARA"}
COLOR_ESTADO = {0: "#f4a261", 1: "#a8dadc", 2: "#457b9d", 3: "#e9c46a", 4: "#e76f51", 5: "#b5b5b5"}


# ---------------------------------------------------------------- VCD
def leer_vcd(ruta):
    """Lector sencillo de VCD: devuelve {nombre: [(t_ps, valor_entero), ...]}."""
    ids, cambios, t = {}, {}, 0
    en_defs = True
    for linea in Path(ruta).read_text().splitlines():
        linea = linea.strip()
        if not linea:
            continue
        if en_defs:
            if linea.startswith("$var"):
                p = linea.split()
                ids[p[3]] = p[4]
                cambios.setdefault(p[4], [])
            elif linea.startswith("$enddefinitions"):
                en_defs = False
            continue
        if linea[0] == "#":
            t = int(linea[1:])
        elif linea[0] == "b":
            valor, ident = linea[1:].split()
            if ident in ids:
                v = int(valor, 2) if set(valor) <= {"0", "1"} else None
                cambios[ids[ident]].append((t, v))
        elif linea[0] in "01xz" and linea[1:] in ids:
            v = int(linea[0]) if linea[0] in "01" else None
            cambios[ids[linea[1:]]].append((t, v))
    return cambios


def valor_en(serie, t):
    v = None
    for tc, vc in serie:
        if tc > t:
            break
        v = vc
    return v


def tramos(serie, t0, t1):
    """Lista de (inicio, fin, valor) dentro de [t0, t1]."""
    res = []
    actual = valor_en(serie, t0)
    inicio = t0
    for tc, vc in serie:
        if t0 < tc < t1:
            res.append((inicio, tc, actual))
            inicio, actual = tc, vc
    res.append((inicio, t1, actual))
    return res


def dibujar_digital(ax, serie, t0, t1, base, color):
    xs, ys = [], []
    for a, b, v in tramos(serie, t0, t1):
        v = v or 0
        xs += [a / 1e6, b / 1e6]
        ys += [base + 0.8 * v, base + 0.8 * v]
    ax.plot(xs, ys, color=color, lw=1.4)


def dibujar_estados(ax, serie, t0, t1, base, con_nombres):
    for a, b, v in tramos(serie, t0, t1):
        if v is None:
            continue
        ax.add_patch(Rectangle((a / 1e6, base), (b - a) / 1e6, 0.8,
                               facecolor=COLOR_ESTADO.get(v, "white"), edgecolor="white", lw=0.4))
        if con_nombres and (b - a) / 1e6 > (t1 - t0) / 1e6 * 0.035:
            ax.text((a + b) / 2e6, base + 0.4, ESTADOS.get(v, "?"), ha="center", va="center",
                    fontsize=7.5, color="black" if v != 2 else "white")


def panel(ax, s, t0, t1, titulo, con_nombres):
    filas = [("load", "LOAD", "#c0392b"), ("clk_led", "CLK_LED", "#2c3e50"), ("din", "DIN", "#1f77b4")]
    for i, (nombre, etiqueta, color) in enumerate(filas):
        dibujar_digital(ax, s[nombre], t0, t1, i * 1.2, color)
        ax.text(t0 / 1e6 - (t1 - t0) / 1e6 * 0.01, i * 1.2 + 0.4, etiqueta, ha="right", va="center",
                fontsize=8.5, weight="bold")
    dibujar_estados(ax, s["estado"], t0, t1, 3 * 1.2, con_nombres)
    ax.text(t0 / 1e6 - (t1 - t0) / 1e6 * 0.01, 3 * 1.2 + 0.4, "estado", ha="right", va="center",
            fontsize=8.5, weight="bold")
    ax.set_xlim(t0 / 1e6, t1 / 1e6)
    ax.set_ylim(-0.3, 4.6)
    ax.set_yticks([])
    ax.set_title(titulo, fontsize=10, loc="left")
    ax.set_xlabel("tiempo [µs]", fontsize=8.5)
    ax.tick_params(labelsize=8)
    for lado in ("top", "right", "left"):
        ax.spines[lado].set_visible(False)


def figura_ondas(vcd, destino):
    s = leer_vcd(vcd)
    # La ventana grabada arranca justo cuando termina la configuración, o sea
    # en la CARGA de la primera palabra de imagen (dígito 1 = fila 0). Esa
    # transferencia es la que dibujamos: va desde esa CARGA hasta que se
    # termina su pulso de LOAD.
    # (la grabación empieza en la palabra de configuración idx = 4, así que
    # la CARGA que nos interesa es la que viene después de su LOAD)
    bajada_cfg = [t for t, v in s["load"] if v == 1][0]
    t_carga = [t for t, v in s["estado"] if v == 0 and t > bajada_cfg][0]
    subida = [t for t, v in s["load"] if v == 1 and t > t_carga][0]
    bajada = [t for t, v in s["load"] if v == 0 and t > subida][0]
    t_ini = t_carga - 450_000
    t_fin = bajada + 1_500_000
    flancos = [t for t, v in s["clk_led"] if v == 1 and t_carga < t < subida]
    idx = valor_en(s["idx"], subida - 1)
    pos = valor_en(s["pos"], subida - 1)

    fig = plt.figure(figsize=(13, 8.2))
    gs = fig.add_gridspec(2, 2, height_ratios=[1, 1], hspace=0.45, wspace=0.18)
    ax1 = fig.add_subplot(gs[0, :])
    ax2 = fig.add_subplot(gs[1, 0])
    ax3 = fig.add_subplot(gs[1, 1])

    panel(ax1, s, t_ini, t_fin,
          f"(a) Una transferencia: 64 flancos de CLK_LED (16 bits × 4 chips) y un pulso de LOAD "
          f"— dígito {idx - 4} (fila {idx - 5}), con el punto en X={pos % 32}, Y={pos // 32}", False)
    ax1.set_ylim(-0.3, 5.3)
    for g in range(1, 4):
        x = (flancos[16 * g - 1] + flancos[16 * g]) / 2e6
        ax1.axvline(x, color="#999", ls="--", lw=0.7)
    for g in range(4):
        x = (flancos[16 * g] + flancos[16 * g + 15]) / 2e6
        ax1.text(x, 4.75, f"palabra para el chip {3 - g}", ha="center", fontsize=8, color="#444")

    panel(ax2, s, t_ini, flancos[2] + 900_000, "(b) Acercamiento al inicio: CARGA y los primeros bits", True)
    panel(ax3, s, flancos[-2] - 600_000, t_fin, "(c) Acercamiento al final: último bit, CIERRE, LATCH y SEPARA", True)

    # Leyenda de colores de estado
    manijas = [Rectangle((0, 0), 1, 1, facecolor=COLOR_ESTADO[k]) for k in range(6)]
    fig.legend(manijas, [ESTADOS[k] for k in range(6)], loc="lower center", ncol=6, fontsize=9,
               frameon=False, bbox_to_anchor=(0.5, -0.005))
    fig.suptitle("Simulación de la etapa 1: lo que sale de la FPGA hacia el módulo MAX7219 ×4 "
                 "(CLK_LED = 1 MHz, igual que en la tarjeta)", fontsize=11.5, y=0.995)
    fig.savefig(destino, dpi=150, bbox_inches="tight")
    print(f"-> {destino}")


# ---------------------------------------------------------------- Pantallas
TITULOS = {"Calibracion (SW2 en ON)": "Patrón de calibración (SW2 en ON)"}


def figura_pantallas(txt, destino):
    filas = []
    for linea in Path(txt).read_text().splitlines():
        if ";" in linea:
            titulo, bits = linea.rsplit(";", 1)
            filas.append((TITULOS.get(titulo.strip(), titulo.strip()), bits.strip()))

    fig, axes = plt.subplots(len(filas), 1, figsize=(9, 1.75 * len(filas)))
    for ax, (titulo, bits) in zip(axes, filas):
        ax.set_facecolor("#0d3b2e")
        for m in range(4):
            ax.add_patch(Rectangle((m * 8.25 - 0.45, -0.45), 7.9, 7.9, facecolor="#11553f", edgecolor="none"))
        for f in range(8):
            for c in range(32):
                on = bits[f * 32 + c] == "1"
                ax.add_patch(plt.Circle((c + (c // 8) * 0.25, 7 - f), 0.36,
                                        color="#ff3b2f" if on else "#3b1d1d"))
        ax.set_xlim(-0.8, 32 + 0.25 * 3 - 0.2)
        ax.set_ylim(-0.8, 7.8)
        ax.set_aspect("equal")
        ax.axis("off")
        ax.set_title(titulo, fontsize=10, loc="left")
    fig.suptitle("Pantalla reconstruida a partir de los registros de los 4 modelos de MAX7219",
                 fontsize=11, y=1.0)
    fig.tight_layout()
    fig.savefig(destino, dpi=150, bbox_inches="tight")
    print(f"-> {destino}")


if __name__ == "__main__":
    SALIDA.mkdir(parents=True, exist_ok=True)
    figura_ondas(AQUI / "sim" / "tb_etapa1.vcd", SALIDA / "etapa1_ondas.png")
    figura_pantallas(AQUI / "sim" / "pantallas_etapa1.txt", SALIDA / "etapa1_pantallas.png")
