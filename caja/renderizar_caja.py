#!/usr/bin/env python3
# ============================================================================
#  renderizar_caja.py  -  Vistas de la caja antes de cortarla
#  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
# ----------------------------------------------------------------------------
#  Armamos la caja "en el computador" con las mismas piezas que van al láser
#  (las extruimos 3 mm y las ponemos en su sitio). Si algo no cuadra en el
#  dibujo, tampoco va a cuadrar en la vida real. Sacamos:
#
#    img/caja_3d.png            caja armada y despiezada, con los controles
#    img/hoja_corte.png         cómo quedan las piezas en la lámina
#    pdf/plantillas_1a1.pdf     tapas a escala real para imprimir en carta
#                               y poner los componentes encima antes de cortar
# ============================================================================

import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import trimesh
from matplotlib.backends.backend_pdf import PdfPages
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from shapely.geometry import Point

import generar_caja as gc

AQUI = os.path.dirname(os.path.abspath(__file__))
MADERA = np.array([0.80, 0.64, 0.45])


def malla(pieza, T):
    g = pieza.cuerpo
    for (x, y, r) in pieza.circulos:
        g = g.difference(Point(x, y).buffer(r, quad_segs=12))
    partes = [trimesh.creation.extrude_polygon(p, T) for p in gc.poligonos(g)]
    return trimesh.util.concatenate(partes)


def matriz(cols):
    """cols = (eje_u, eje_v, eje_w, origen) en 3D."""
    M = np.eye(4)
    M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = cols
    return M


def contornos_a_poligonos(contornos):
    """Junta los contornos de una letra con regla par-impar (así la 'O' queda con su hueco)."""
    from shapely.geometry import Polygon
    g = None
    for pts in contornos:
        p = Polygon(pts).buffer(0)
        g = p if g is None else g.symmetric_difference(p)
    return [] if g is None else gc.poligonos(g)


def grabados_3d(prefijo, piezas, info, explotar=0.0, base_xyz=(0, 0, 0)):
    """Texto y flechas grabados, como triángulos planos un pelito por fuera de la cara."""
    W, D, H, T = info["W"], info["D"], info["H"], info["T"]
    ox, oy, oz = base_xyz
    e = explotar
    caras = {
        "tapa": lambda u, v: (ox + u, oy + v, oz + H + 1.6 * e + 0.08),
        "frente": lambda u, v: (ox + u, oy - e - 0.08, oz + T + v),
        "trasera": lambda u, v: (ox + W - u, oy + D + e + 0.08, oz + T + v),
    }
    quemado = (0.30, 0.18, 0.09)
    planos = []
    for nombre, f in caras.items():
        for poly in contornos_a_poligonos(piezas[f"{prefijo}_{nombre}"].grabado):
            if poly.area < 0.05:
                continue
            vert, caras_t = trimesh.creation.triangulate_polygon(poly, engine="earcut")
            for tri in caras_t:
                planos.append(([f(*vert[i]) for i in tri], quemado))
    return planos


def ubicar(prefijo, piezas, info, explotar=0.0, base_xyz=(0, 0, 0)):
    """Pone cada lámina de una caja en su sitio en 3D. Devuelve (malla, color)."""
    W, D, H, T = info["W"], info["D"], info["H"], info["T"]
    e = explotar
    ox, oy, oz = base_xyz
    X, Y, Z = np.array([1, 0, 0]), np.array([0, 1, 0]), np.array([0, 0, 1])
    o = np.array([ox, oy, oz], dtype=float)
    poses = {
        "base": matriz((X, Y, Z, o + [0, 0, -1.2 * e])),
        "tapa": matriz((X, Y, Z, o + [0, 0, H - T + 1.6 * e])),
        "frente": matriz((X, Z, Y, o + [0, -e, T])),
        "trasera": matriz((-X, Z, Y, o + [W, D - T + e, T])),
        "lateral_izq": matriz((Y, Z, X, o + [-e, 0, T])),
        "lateral_der": matriz((Y, Z, X, o + [W - T + e, 0, T])),
    }
    salida = []
    for nombre, M in poses.items():
        m = malla(piezas[f"{prefijo}_{nombre}"], T)
        m.apply_transform(M)
        salida.append((m, MADERA))
    return salida


def bloque(x0, y0, z0, dx, dy, dz, color):
    m = trimesh.creation.box(extents=(dx, dy, dz))
    m.apply_translation((x0 + dx / 2, y0 + dy / 2, z0 + dz / 2))
    return (m, np.array(color))


def cilindro(x, y, z0, r, h, color):
    m = trimesh.creation.cylinder(radius=r, height=h, sections=24)
    m.apply_translation((x, y, z0 + h / 2))
    return (m, np.array(color))


def componentes(P, info, explotar=0.0):
    """Cajitas sencillas para ver dónde quedan matrices, displays, botones y tarjeta."""
    W, D, H, T = info["W"], info["D"], info["H"], info["T"]
    e = explotar
    cx, cy = W / 2, P["ventana_y"]
    L, nm = P["matriz_lado"], P["n_matrices"]
    ztapa = H - T + 1.6 * e
    out = []
    ancho_m = nm * L + (nm - 1) * P["matriz_separacion"]
    out.append(bloque(cx - ancho_m / 2, cy - L / 2, ztapa + T - 1.2, ancho_m, L, 0.9, (0.12, 0.12, 0.13)))
    for k in range(nm):
        x0 = cx - ancho_m / 2 + k * (L + P["matriz_separacion"])
        for i in range(8):
            for j in range(8):
                if (i + j * 3 + k) % 5 == 0 or (j == 3 and i == 5 and k == 0):
                    out.append(bloque(x0 + 1 + i * 4, cy - L / 2 + 1 + j * 4, ztapa + T - 0.29, 2.2, 2.2, 0.3, (0.95, 0.15, 0.10)))
    if P["siete_segmentos"]:
        vw = nm * L + (nm - 1) * P["matriz_separacion"] + 2 * P["holgura_ventanas"]
        dw = P["display_ancho"] + 2 * P["holgura_ventanas"]
        off = vw / 2 + P["display_separacion"] + dw / 2
        for s in (-1, 1):
            out.append(bloque(cx + s * off - P["display_ancho"] / 2, cy - P["display_alto"] / 2, ztapa + T - 1.2,
                              P["display_ancho"], P["display_alto"], 0.9, (0.15, 0.15, 0.15)))
            # un "8" encendido en rojo, para que se entienda qué va ahí
            for (sx0, sy0, sw, sh) in ((2.5, 16, 7.6, 1.2), (2.5, 8.9, 7.6, 1.2), (2.5, 1.8, 7.6, 1.2),
                                        (1.6, 9.8, 1.2, 6.4), (9.8, 9.8, 1.2, 6.4), (1.6, 2.7, 1.2, 6.4), (9.8, 2.7, 1.2, 6.4)):
                if s == -1 and (sx0, sy0) == (1.6, 2.7):
                    continue
                out.append(bloque(cx + s * off - P["display_ancho"] / 2 + sx0, cy - P["display_alto"] / 2 + sy0,
                                  ztapa + T - 0.31, sw, sh, 0.3, (0.95, 0.15, 0.10)))
    proto = P.get("montaje", "protoboard") == "protoboard"
    blanco, gris = (0.93, 0.93, 0.90), (0.18, 0.18, 0.20)
    if proto:
        # Protoboard de la tapa, a ras, con los 7 pulsadores y los 2 displays
        x0, y0, x1, y1 = info["proto_tapa"]
        zp = H - P["proto_alto"] + 1.6 * e
        out.append(bloque(x0, y0, zp, x1 - x0, y1 - y0, P["proto_alto"], blanco))
        out.append(bloque(x0 - 12, y0 - 4.5, zp - T, (x1 - x0) + 24, (y1 - y0) + 9, T, MADERA))   # soporte
        ytop = zp + P["proto_alto"]
        for k in range(2):  # líneas de los rieles de alimentación
            for yy, col in ((y0 + 3, (0.2, 0.3, 0.8)), (y1 - 3, (0.85, 0.2, 0.2))):
                out.append(bloque(x0 + 8, yy - 0.3, ytop, (x1 - x0) - 16, 0.6, 0.05, col))
        xm = (x0 + x1) / 2
        ym = (y0 + y1) / 2
        for dx in (-72, -58, -16, 0, 16, 58, 72):
            out.append(bloque(xm + dx - 3, ym - 9, ytop, 6, 6, 3.5, gris))
            out.append(cilindro(xm + dx, ym - 6, ytop + 3.5, 1.7, 1.5, (0.05, 0.05, 0.05)))
        for s in (-1, 1):
            xd = xm + s * 37
            out.append(bloque(xd - 6.3, ym, ytop, 12.6, 19, 7, (0.15, 0.15, 0.15)))
            for (sx0, sy0, sw, sh) in ((2.5, 16, 7.6, 1.2), (2.5, 8.9, 7.6, 1.2), (2.5, 1.8, 7.6, 1.2),
                                        (1.6, 9.8, 1.2, 6.4), (9.8, 9.8, 1.2, 6.4), (1.6, 2.7, 1.2, 6.4), (9.8, 2.7, 1.2, 6.4)):
                if s == -1 and (sx0, sy0) in ((1.6, 2.7), (2.5, 8.9)):
                    continue
                out.append(bloque(xd - 6.3 + sx0, ym + sy0, ytop + 7, sw, sh, 0.05, (0.95, 0.15, 0.10)))
    else:
        for i, col in enumerate(((0.10, 0.65, 0.25), (0.95, 0.75, 0.10), (0.85, 0.12, 0.12))):
            x = cx + (i - 1) * P["botones_paso"]
            out.append(cilindro(x, P["botones_y"], ztapa + T, P["boton_diametro"] / 2 - 0.6, 3.5, col))
    # La tarjeta FPGA sobre separadores (solo en el despiece; con la caja
    # cerrada no se ve y matplotlib a veces la deja "asomar" por error)
    if e == 0:
        return out
    bx0, by0, bx1, by1 = info["tarjeta"]
    sep = P.get("separador_tarjeta", 10)
    out.append(bloque(bx0, by0, T + sep - 1.2 * e, bx1 - bx0, by1 - by0, 1.6, (0.10, 0.35, 0.65)))
    if proto:
        x0, y0, x1, y1 = info["proto_interna"]
        out.append(bloque(x0, y0, T - 1.2 * e, x1 - x0, y1 - y0, P["proto_alto"], blanco))
    return out


def componentes_control(P, info, o, explotar=0.0):
    W, D, H, T = info["W"], info["D"], info["H"], info["T"]
    z = o[2] + H - T + 1.6 * explotar + T
    out = []
    for y in (D * 0.70, D * 0.30):
        out.append(cilindro(o[0] + 28, o[1] + y, z, P["boton_diametro"] / 2 - 0.6, 3.5, (0.2, 0.2, 0.22)))
    out.append(cilindro(o[0] + W - 12, o[1] + D - 12, z - 1, P["led_diametro"] / 2 - 0.2, 3, (0.1, 0.9, 0.2)))
    return out


def pintar(ax, objetos, planos=None, luz=(-0.35, -0.55, 0.75)):
    luz = np.array(luz) / np.linalg.norm(luz)
    tris, colores = [], []
    for m, c in objetos:
        v, f = trimesh.remesh.subdivide_to_size(m.vertices, m.faces, max_edge=7.0)
        m = trimesh.Trimesh(v, f, process=False)
        n = m.face_normals
        brillo = 0.45 + 0.55 * np.abs(n @ luz)
        tris.append(m.triangles)
        colores.append(np.clip(c[None, :] * brillo[:, None], 0, 1))
    tris = np.concatenate(tris)
    colores = np.concatenate(colores)
    # Lo grabado va en la misma colección para que matplotlib lo ordene en
    # profundidad junto con las caras (si no, la tapa lo tapa).
    polis = list(tris) + [np.array(p) for p, _ in (planos or [])]
    cols = list(colores) + [np.array(c) for _, c in (planos or [])]
    coll = Poly3DCollection(polis, facecolors=cols, edgecolors=cols, linewidths=0.2)
    ax.add_collection3d(coll)
    todo = tris.reshape(-1, 3)
    mn, mx = todo.min(0), todo.max(0)
    centro, r = (mn + mx) / 2, (mx - mn).max() / 2 * 0.80
    ax.set_xlim(centro[0] - r, centro[0] + r)
    ax.set_ylim(centro[1] - r, centro[1] + r)
    ax.set_zlim(centro[2] - r, centro[2] + r)
    ax.set_box_aspect((1, 1, 1))
    ax.set_axis_off()


def vista_3d(P, piezas, info, ruta):
    ip, ic = info["principal"], info["control"]
    fig = plt.figure(figsize=(16, 9), dpi=150)
    fig.patch.set_facecolor("white")
    escenas = [
        ("Caja armada con sus controles", 0.0),
        ("Despiece (así se arma)", 28.0),
    ]
    for k, (titulo, e) in enumerate(escenas):
        ax = fig.add_subplot(1, 2, k + 1, projection="3d")
        objs = ubicar("pong", piezas, ip, explotar=e)
        objs += componentes(P, ip, explotar=e)
        planos = grabados_3d("pong", piezas, ip, explotar=e)
        if e == 0:
            for j, (nom, dx) in enumerate((("control_j1", -22), ("control_j2", ip["W"] - ic["W"] + 22))):
                o = (dx, -ic["D"] - 45, 0)
                objs += ubicar(nom, piezas, ic, base_xyz=o)
                objs += componentes_control(P, ic, o)
                planos += grabados_3d(nom, piezas, ic, base_xyz=o)
        pintar(ax, objs, planos)
        ax.view_init(elev=28 if e == 0 else 22, azim=-62)
        ax.set_title(titulo, fontsize=15, pad=0)
    fig.suptitle("Caja del Pong en FPGA  ·  MDF de 3 mm  ·  "
                 f"{ip['W']:.0f} × {ip['D']:.0f} × {ip['H']:.0f} mm", fontsize=13, y=0.97)
    fig.subplots_adjust(left=0, right=1, bottom=0, top=0.93, wspace=0)
    fig.savefig(ruta, facecolor="white", bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)


def dibujar_pieza_2d(ax, pieza, ox, oy, k=0.0, ancho_linea=0.35):
    def tr(pts):
        a = np.array(pts)
        return a[:, 0] + ox, a[:, 1] + oy
    cuerpo = pieza.cuerpo.buffer(k / 2, join_style="mitre", mitre_limit=5) if k else pieza.cuerpo
    for poly in gc.poligonos(cuerpo):
        for anillo in [poly.exterior] + list(poly.interiors):
            x, y = tr(list(anillo.coords))
            ax.plot(x, y, color="#e00000", lw=ancho_linea)
    t = np.linspace(0, 2 * np.pi, 80)
    for (x, y, r) in pieza.circulos:
        ax.plot(ox + x + (r - k / 2) * np.cos(t), oy + y + (r - k / 2) * np.sin(t), color="#e00000", lw=ancho_linea)
    # Todo el grabado como un solo trazo compuesto: así los huecos de las
    # letras (la O, la D...) se ven huecos, igual que en el programa del láser.
    if pieza.grabado:
        from matplotlib.path import Path
        from matplotlib.patches import PathPatch
        verts, codes = [], []
        for pts in pieza.grabado:
            x, y = tr(pts)
            verts += list(zip(x, y)) + [(x[0], y[0])]
            codes += [Path.MOVETO] + [Path.LINETO] * (len(pts) - 1) + [Path.CLOSEPOLY]
        ax.add_patch(PathPatch(Path(verts, codes), facecolor="#1f4fd8", edgecolor="none"))
    for pts, cerrada in pieza.marcado:
        x, y = tr(pts + ([pts[0]] if cerrada else []))
        ax.plot(x, y, color="#11a34a", lw=ancho_linea)
    for pts, cerrada in pieza.referencia:
        x, y = tr(pts + ([pts[0]] if cerrada else []))
        ax.plot(x, y, color="#888888", lw=ancho_linea * 0.8, ls="--")


def vista_hoja(P, hoja, ruta, titulo=""):
    hw, hh = P["hoja_ancho"], P["hoja_alto"]
    fig = plt.figure(figsize=(15, 15 * hh / hw + 0.6), dpi=150)
    ax = fig.add_axes([0.01, 0.01, 0.98, 0.94])
    ax.plot([0, hw, hw, 0, 0], [0, 0, hh, hh, 0], color="#bbbbbb", lw=0.8)
    for col in hoja:
        p = col.pieza
        # Para dibujar rotada reusamos la geometría ya transformada
        q = gc.Pieza(p.nombre, 1, 1)
        q.cuerpo = col.geom(p.cuerpo)
        q.circulos = [(*col.f(x, y), r) for (x, y, r) in p.circulos]
        q.grabado = [[col.f(*a) for a in pts] for pts in p.grabado]
        q.marcado = [([col.f(*a) for a in pts], c) for pts, c in p.marcado]
        q.referencia = [([col.f(*a) for a in pts], c) for pts, c in p.referencia]
        dibujar_pieza_2d(ax, q, 0, 0, ancho_linea=0.6)
        bx = q.cuerpo.bounds
        ax.text((bx[0] + bx[2]) / 2, bx[1] + 2.2, p.nombre, fontsize=6, color="#777777", ha="center", va="bottom")
    ax.set_xlim(-5, hw + 5)
    ax.set_ylim(-5, hh + 5)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.suptitle(f"{titulo}Hoja de {hw:.0f} × {hh:.0f} mm   —   rojo: cortar   ·   azul: grabar relleno   ·   "
                 "verde: marcar suave   ·   gris punteado: solo referencia", fontsize=10)
    fig.savefig(ruta, facecolor="white")
    plt.close(fig)


def plantillas(P, piezas, ruta):
    """Tapas a escala 1:1 en hoja carta horizontal (279.4 x 215.9 mm)."""
    cw, ch = 279.4, 215.9
    with PdfPages(ruta) as pdf:
        for nombre, titulo in (("pong_tapa", "Tapa de la caja principal"),
                               ("control_j1_tapa", "Tapa del control J1 (la de J2 es igual con otro letrero)"),
                               ("pong_base", "Base (cara de adentro)")):
            p = piezas[nombre]
            fig = plt.figure(figsize=(cw / 25.4, ch / 25.4))
            ax = fig.add_axes([0, 0, 1, 1])
            ax.set_xlim(0, cw)
            ax.set_ylim(0, ch)
            ax.axis("off")
            ox, oy = (cw - p.ancho) / 2, (ch - p.alto) / 2 - 6
            dibujar_pieza_2d(ax, p, ox, oy, ancho_linea=0.4)
            ax.text(cw / 2, ch - 8, f"{titulo}  —  ESCALA 1:1", ha="center", fontsize=11, weight="bold")
            ax.text(cw / 2, ch - 14, "Imprimir al 100 % (\"tamaño real\", sin \"ajustar a la página\"). "
                    "La barra de abajo debe medir 50 mm con regla.", ha="center", fontsize=8)
            ax.plot([12, 62], [10, 10], color="black", lw=1.5)
            for xx in (12, 62):
                ax.plot([xx, xx], [8, 12], color="black", lw=1.5)
            ax.text(37, 13, "50 mm", ha="center", fontsize=8)
            pdf.savefig(fig)
            plt.close(fig)


def main():
    P = gc.cargar_parametros(sys.argv[1] if len(sys.argv) > 1 else None)
    lista, info = gc.construir(P)
    piezas = {p.nombre: p for p in lista}
    os.makedirs(os.path.join(AQUI, "img"), exist_ok=True)
    os.makedirs(os.path.join(AQUI, "pdf"), exist_ok=True)
    vista_3d(P, piezas, info, os.path.join(AQUI, "img", "caja_3d.png"))
    for f in os.listdir(os.path.join(AQUI, "img")):
        if f.startswith("hoja_"):
            os.remove(os.path.join(AQUI, "img", f))
    for grupo, hoja in gc.hojas_por_grupo(lista, P["hoja_ancho"], P["hoja_alto"]):
        vista_hoja(P, hoja, os.path.join(AQUI, "img", f"hoja_{grupo}.png"), titulo=f"{grupo.upper()}  ·  ")
    plantillas(P, piezas, os.path.join(AQUI, "pdf", "plantillas_1a1_carta.pdf"))
    print("Listo: img/caja_3d.png, img/hoja_*.png, pdf/plantillas_1a1_carta.pdf")


if __name__ == "__main__":
    main()
