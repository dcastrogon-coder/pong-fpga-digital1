#!/usr/bin/env python3
# ============================================================================
#  generar_caja.py  -  Archivos de corte láser para la caja del Pong
#  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
#  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
#           David Eduardo Chivata Arias
# ----------------------------------------------------------------------------
#  Con este script sacamos todos los DXF de la caja (se abren directo en
#  AutoCAD, LightBurn, RDWorks o CorelDRAW). Preferimos hacerlo con código y
#  no dibujando a mano porque así, cuando midamos los componentes de verdad,
#  solo cambiamos un número en parametros_caja.json y volvemos a correr esto.
#
#  Qué sale:
#    - La caja principal: tapa, base, frente, trasera y dos laterales, unidas
#      con dedos (finger joints) en las esquinas y con tornillo M3 + tuerca en
#      ranura en T para la tapa y la base, así la podemos abrir cuando
#      queramos sin despegar nada.
#    - Dos barras que sostienen las matrices por debajo de la tapa.
#    - Dos cajitas para los controles inalámbricos (J1 y J2), con el mismo
#      sistema de unión.
#
#  Capas (todas en milímetros):
#    CORTE      rojo   -> se corta de lado a lado
#    GRABADO    azul   -> se graba relleno (letras, flechas)
#    MARCADO    verde  -> línea suave, sin atravesar (marcos decorativos)
#    REFERENCIA gris   -> solo en los archivos de guía, NO se manda al láser
#
#  Uso:   python3 generar_caja.py            (usa parametros_caja.json)
#         python3 generar_caja.py otro.json  (por si queremos probar medidas)
# ============================================================================

import json
import math
import os
import sys

import ezdxf
from ezdxf import units
from ezdxf.addons import text2path
from ezdxf.enums import TextEntityAlignment
from ezdxf.fonts import fonts
from ezdxf.math import Matrix44
from shapely import affinity
from shapely.geometry import LineString, Polygon, box as rect

AQUI = os.path.dirname(os.path.abspath(__file__))

AUTORES = [
    "Daniel Felipe Castro González",
    "Juan David Ortiz Muñoz",
    "David Eduardo Chivata Arias",
]


def cargar_parametros(ruta=None):
    ruta = ruta or os.path.join(AQUI, "parametros_caja.json")
    with open(ruta, encoding="utf-8") as f:
        P = json.load(f)
    return {k: v for k, v in P.items() if not k.startswith("_")}


# ----------------------------------------------------------------------------
#  Una "pieza" es una lámina: su contorno (con huecos) más lo que se graba.
#  Guardamos todo en medidas nominales; la compensación del kerf la hacemos
#  solo al momento de escribir el DXF.
# ----------------------------------------------------------------------------
class Pieza:
    def __init__(self, nombre, ancho, alto, descripcion=""):
        self.nombre = nombre
        self.descripcion = descripcion
        self.cuerpo = rect(0, 0, ancho, alto)
        self.circulos = []      # (x, y, r) huecos redondos
        self.grabado = []       # listas de puntos cerradas (relleno)
        self.marcado = []       # (puntos, cerrada)
        self.referencia = []    # (puntos, cerrada)
        self.cantidad = 1
        self.tapa_o_base = False

    @property
    def ancho(self):
        return self.cuerpo.bounds[2]

    @property
    def alto(self):
        return self.cuerpo.bounds[3]

    def quitar(self, geom):
        self.cuerpo = self.cuerpo.difference(geom)

    def agujero(self, x, y, diametro):
        self.circulos.append((x, y, diametro / 2.0))


# ----------------------------------------------------------------------------
#  Ayudas de geometría
# ----------------------------------------------------------------------------
def rect_centro(cx, cy, w, h):
    return rect(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)


def rect_redondeado(cx, cy, w, h, r):
    # Un rectángulo encogido y luego "inflado" con esquinas redondas
    return rect_centro(cx, cy, w - 2 * r, h - 2 * r).buffer(r, quad_segs=8)


def ranura_redonda(x1, y1, x2, y2, ancho):
    # Ranura con puntas redondas (para ventilación y para la tarjeta)
    return LineString([(x1, y1), (x2, y2)]).buffer(ancho / 2, quad_segs=8)


def puntos_rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def puntos_rect_redondeado(cx, cy, w, h, r):
    return list(rect_redondeado(cx, cy, w, h, r).exterior.coords)[:-1]


def texto(P, s, x, y, h, peso=700, alinear=TextEntityAlignment.MIDDLE_CENTER):
    """Convierte un texto en contornos cerrados para grabar.

    Lo pasamos a polilíneas en vez de dejarlo como TEXT porque cada programa
    de láser interpreta las fuentes a su manera; así se ve igual en todos.
    """
    ff = fonts.FontFace(family=P["fuente_texto"], weight=peso)
    camino = text2path.make_path_from_str(s, ff, size=h, align=alinear)
    camino = camino.transform(Matrix44.translate(x, y, 0))
    contornos = []
    for sub in camino.sub_paths():
        pts = [(v.x, v.y) for v in sub.flattening(0.02)]
        if len(pts) > 2:
            if math.dist(pts[0], pts[-1]) < 1e-6:
                pts = pts[:-1]
            contornos.append(pts)
    return contornos


def triangulo(cx, cy, lado, hacia_arriba=True):
    h = lado * math.sqrt(3) / 2
    s = 1 if hacia_arriba else -1
    return [(cx - lado / 2, cy - s * h / 3), (cx + lado / 2, cy - s * h / 3), (cx, cy + s * 2 * h / 3)]


def impar_mas_cercano(x, minimo=3):
    n = max(minimo, int(round(x)))
    return n if n % 2 == 1 else n + 1


# ----------------------------------------------------------------------------
#  La caja genérica: tapa y base "encima" de las paredes (sujetas con
#  ranuras en T) y paredes unidas entre sí con dedos en las cuatro esquinas.
#
#  Sistema de coordenadas en 3D (lo usamos también para el render):
#    x hacia la derecha, y hacia el fondo (y = 0 es el frente, donde están
#    los jugadores), z hacia arriba. La base ocupa z = [0, T], las paredes
#    z = [T, H - T] y la tapa z = [H - T, H].
# ----------------------------------------------------------------------------
def ranura_t(P, pieza, x, borde_arriba):
    """Ranura en T: un canal para el tornillo y un bolsillo para la tuerca."""
    T_alto = pieza.alto
    d = P["tornillo_diametro"]
    L = P["ranura_t_largo"]
    a = P["ranura_t_tuerca_desde"]
    w = P["tuerca_ancho"]
    e = P["tuerca_espesor"]
    if borde_arriba:
        canal = rect(x - d / 2, T_alto - L, x + d / 2, T_alto + 1)
        tuerca = rect(x - w / 2, T_alto - a - e, x + w / 2, T_alto - a)
    else:
        canal = rect(x - d / 2, -1, x + d / 2, L)
        tuerca = rect(x - w / 2, a, x + w / 2, a + e)
    pieza.quitar(canal.union(tuerca))


def construir_caja(P, prefijo, W, D, H, pos_t_largas, pos_t_cortas):
    T = P["material_espesor"]
    Hw = H - 2 * T
    n = impar_mas_cercano(Hw / P["ancho_dedo"])
    seg = Hw / n

    def pared(nombre, largo, dedos_en_pares, posiciones_t, descripcion):
        p = Pieza(f"{prefijo}_{nombre}", largo, Hw, descripcion)
        for i in range(n):
            # En las paredes largas los segmentos pares son dedos y los
            # impares son muescas; en las cortas es al revés. Así encajan.
            es_muesca = (i % 2 == 1) if dedos_en_pares else (i % 2 == 0)
            if es_muesca:
                p.quitar(rect(-1, i * seg, T, (i + 1) * seg))
                p.quitar(rect(largo - T, i * seg, largo + 1, (i + 1) * seg))
        for x in posiciones_t:
            ranura_t(P, p, x, borde_arriba=True)
            ranura_t(P, p, x, borde_arriba=False)
        return p

    frente = pared("frente", W, True, pos_t_largas, "Pared del frente (lado de los jugadores)")
    trasera = pared("trasera", W, True, [W - x for x in pos_t_largas], "Pared de atrás (cables)")
    izq = pared("lateral_izq", D, False, pos_t_cortas, "Pared lateral izquierda")
    der = pared("lateral_der", D, False, pos_t_cortas, "Pared lateral derecha")

    def plancha(nombre, descripcion):
        p = Pieza(f"{prefijo}_{nombre}", W, D, descripcion)
        p.tapa_o_base = True
        d = P["tornillo_diametro"]
        for x in pos_t_largas:
            p.agujero(x, T / 2, d)
            p.agujero(x, D - T / 2, d)
        for y in pos_t_cortas:
            p.agujero(T / 2, y, d)
            p.agujero(W - T / 2, y, d)
        return p

    tapa = plancha("tapa", "Tapa (va encima de las paredes)")
    base = plancha("base", "Base (va debajo de las paredes)")
    info = dict(W=W, D=D, H=H, T=T, Hw=Hw, n_dedos=n, seg=seg,
                pos_t_largas=list(pos_t_largas), pos_t_cortas=list(pos_t_cortas))
    return dict(tapa=tapa, base=base, frente=frente, trasera=trasera,
                lateral_izq=izq, lateral_der=der), info


# ----------------------------------------------------------------------------
#  Caja principal del Pong
# ----------------------------------------------------------------------------
def caja_principal(P):
    """Hay dos formas de armar la caja, según el montaje que elijamos:

    "protoboard" (la de ahora): la protoboard de los botones y del marcador
        queda encajada en la tapa, a ras, para poder presionar los botones y
        ver los displays. La tarjeta y otra protoboard (matrices, receptores
        RF) van adentro, sobre la base. Así podemos meter el montaje tal cual
        lo tenemos, sin pasarlo a pulsadores de panel.
    "panel": la versión con pulsadores de 12 mm y ventanas para los displays
        en la tapa (sirve si después pasamos todo a baquela).
    """
    W, D, H = P["caja_ancho"], P["caja_fondo"], P["caja_alto"]
    T = P["material_espesor"]
    proto = P.get("montaje", "protoboard") == "protoboard"
    piezas, info = construir_caja(P, "pong", W, D, H,
                                  pos_t_largas=[0.25 * W, 0.75 * W],
                                  pos_t_cortas=[0.5 * D])
    tapa, base = piezas["tapa"], piezas["base"]
    trasera, izq, der = piezas["trasera"], piezas["lateral_izq"], piezas["lateral_der"]
    hol = P["holgura_ventanas"]
    Hw = info["Hw"]
    extra = []

    # ---------------- Tapa: pantalla de matrices ----------------
    cx, cy = W / 2, P["ventana_y"]
    L = P["matriz_lado"]
    nm = P["n_matrices"]
    vw = nm * L + (nm - 1) * P["matriz_separacion"] + 2 * hol
    vh = L + 2 * hol
    tapa.quitar(rect_centro(cx, cy, vw, vh))
    tapa.referencia.append((puntos_rect(cx - vw / 2 + hol, cy - L / 2, cx + vw / 2 - hol, cy + L / 2), True))
    for k in range(1, nm):
        xs = cx - vw / 2 + hol + k * L + (k - 0.5) * P["matriz_separacion"]
        tapa.referencia.append(([(xs, cy - L / 2), (xs, cy + L / 2)], False))

    # Huecos para las barras que aprietan las matrices desde abajo
    sx, sy = P["sujecion_dx"], P["sujecion_dy"]
    if P["sujecion_matrices"]:
        for dx in (-sx, sx):
            for dy in (-sy, sy):
                tapa.agujero(cx + dx, cy + dy, P["tornillo_diametro"])

    if proto:
        # ---------- Protoboard encajada en la tapa ----------
        # La ventana es del tamaño de la protoboard más una holgura, porque
        # las protoboards traen unas pestañitas a los lados para unirse.
        pw, pf, hp = P["proto_ancho"], P["proto_fondo"], P["holgura_proto"]
        py = P["proto_tapa_y"]
        ww, wf = pw + 2 * hp, pf + 2 * hp
        tapa.quitar(rect_centro(cx, py, ww, wf))
        tapa.marcado.append((puntos_rect_redondeado(cx, py, ww + 8, wf + 8, 3), True))
        # Cuatro tornillos sostienen por debajo una lámina donde se pega la
        # protoboard (con su propio adhesivo), de modo que quede a ras.
        hx, hy = ww / 2 + 8, P["proto_soporte_dy"]
        for dx in (-hx, hx):
            for dy in (-hy, hy):
                tapa.agujero(cx + dx, py + dy, P["tornillo_diametro"])
        soporte = Pieza("pong_soporte_protoboard", 2 * hx + 12, 2 * hy + 20,
                        "Lámina donde se pega la protoboard de la tapa")
        for dx in (6, 6 + 2 * hx):
            for dy in (10, 10 + 2 * hy):
                soporte.agujero(dx, dy, P["tornillo_diametro"])
        soporte.marcado.append((puntos_rect(soporte.ancho / 2 - pw / 2, soporte.alto / 2 - pf / 2,
                                            soporte.ancho / 2 + pw / 2, soporte.alto / 2 + pf / 2), True))
        extra.append(soporte)
        # Ranura para que los cables de la protoboard bajen a la tarjeta
        rw, rh = P["ranura_cables_tapa_ancho"], P["ranura_cables_tapa_alto"]
        ry = py + wf / 2 + 4 + 2.5 + rh / 2
        tapa.quitar(rect_redondeado(cx, ry, rw, rh, rh / 2 - 0.01))
        # Marco de la pantalla y título
        tapa.marcado.append((puntos_rect_redondeado(cx, cy, vw + 32, vh + 16, 4), True))
        tapa.grabado += texto(P, "PONG", cx, D - 10, 9, peso=800)
    else:
        # ---------- Versión con pulsadores de panel ----------
        marco_medio = vw / 2 + 8
        if P["siete_segmentos"]:
            dw, dh = P["display_ancho"] + 2 * hol, P["display_alto"] + 2 * hol
            off = vw / 2 + P["display_separacion"] + dw / 2
            for signo, nombre in ((-1, "J1"), (1, "J2")):
                x = cx + signo * off
                tapa.quitar(rect_centro(x, cy, dw, dh))
                tapa.grabado += texto(P, nombre, x, cy - dh / 2 - 6, 5)
            marco_medio = off + dw / 2 + 8
        tapa.marcado.append((puntos_rect_redondeado(cx, cy + 1.5 - 5, 2 * marco_medio, vh + 25, 4), True))
        tapa.grabado += texto(P, "PONG", cx, min(D - 14, cy + vh / 2 + 20), 10, peso=800)
        by, paso = P["botones_y"], P["botones_paso"]
        r_b = P["boton_diametro"] / 2
        for i, nombre in enumerate(("START", "PAUSA", "RESET")):
            x = cx + (i - 1) * paso
            tapa.agujero(x, by, P["boton_diametro"])
            tapa.grabado += texto(P, nombre, x, by + r_b + 5, 4)
            tapa.marcado.append((list(rect_redondeado(x, by, 2 * r_b + 6, 2 * r_b + 6, r_b + 3).exterior.coords)[:-1], True))

    tapa.grabado += texto(P, "ELECTRÓNICA DIGITAL 1  ·  UNAL BOGOTÁ", cx, 11, 3.2, peso=600)

    # ---------------- Base: separadores de la tarjeta ----------------
    # Todavía no tenemos la medida exacta de los agujeros de la A-C4E6E10,
    # así que en vez de un hueco redondo dejamos una ranura en diagonal.
    # Cada ranura deja correr el tornillo unos milímetros en x y en y.
    tw, tf, m = P["tarjeta_ancho"], P["tarjeta_fondo"], P["tarjeta_agujero_margen"]
    bx0 = T + P["tarjeta_x0"] if proto else (W - tw) / 2
    by1 = D - T - P["tarjeta_separacion_pared_trasera"]
    by0 = by1 - tf
    bcx, bcy = (bx0 + bx0 + tw) / 2, (by0 + by1) / 2
    Ls = P["ranura_tarjeta_largo"]
    for hx_ in (bx0 + m, bx0 + tw - m):
        for hy_ in (by0 + m, by1 - m):
            ux, uy = hx_ - bcx, hy_ - bcy
            nrm = math.hypot(ux, uy)
            ux, uy = ux / nrm, uy / nrm
            base.quitar(ranura_redonda(hx_ - ux * Ls / 2, hy_ - uy * Ls / 2,
                                       hx_ + ux * Ls / 2, hy_ + uy * Ls / 2, P["tornillo_diametro"]))
    base.referencia.append((puntos_rect(bx0, by0, bx0 + tw, by1), True))
    # Entre el borde de la tarjeta y los tornillos de atrás cabe justo una línea
    base.grabado += texto(P, "ATRÁS  (esta cara va hacia adentro)", W / 2, (by1 + D - T) / 2 + 0.5, 3, peso=600)
    # Ventilación debajo de la tarjeta
    for i in range(7):
        x = bcx + (i - 3) * 9
        base.quitar(ranura_redonda(x, bcy - 22, x, bcy + 22, 3))
    info["tarjeta"] = (bx0, by0, bx0 + tw, by1)

    if proto:
        # Dónde va la protoboard de adentro (matrices y receptores RF): solo
        # la marcamos, porque se pega con su propio adhesivo.
        pw, pf = P["proto_ancho"], P["proto_fondo"]
        ix0, iy0 = (W - pw) / 2, T + P["proto_interna_y0"]
        base.marcado.append((puntos_rect(ix0, iy0, ix0 + pw, iy0 + pf), True))
        base.grabado += texto(P, "PROTOBOARD", W / 2, iy0 + pf / 2, 4, peso=600)
        info["proto_interna"] = (ix0, iy0, ix0 + pw, iy0 + pf)
        info["proto_tapa"] = (cx - pw / 2, P["proto_tapa_y"] - pf / 2, cx + pw / 2, P["proto_tapa_y"] + pf / 2)
    else:
        base.grabado += texto(P, "FRENTE", W / 2, 14, 3.5, peso=600)

    # ---------------- Trasera: salida de cables y créditos ----------------
    # Ojo: la trasera se mira desde afuera, así que su x va al revés (u = W - x)
    sw, sh, sy0 = P["salida_cables_ancho"], P["salida_cables_alto"], P["salida_cables_y"]
    lineas = [f"Pong en FPGA  ·  Electrónica Digital 1  ·  UNAL Bogotá  ·  {P['semestre']}"] + AUTORES
    if proto:
        u_sal = W - bcx                       # la salida queda detrás de la tarjeta
        trasera.quitar(rect_redondeado(u_sal, sy0 + sh / 2, sw, sh, 2))
        for du in (-sw / 2 + 6, sw / 2 - 6):  # antenas, encima de la salida
            trasera.agujero(u_sal + du, sy0 + sh + 8, 3)
        u_txt = (u_sal - sw / 2) / 2 + 2      # créditos en el pedazo libre
        yt = sy0 + sh + 14
        for i, s in enumerate(lineas):
            trasera.grabado += texto(P, s, u_txt, yt - i * 5.2 - (0 if i == 0 else 0.6),
                                     3.0 if i == 0 else 2.8, peso=700 if i == 0 else 500)
    else:
        trasera.quitar(rect_redondeado(W / 2, sy0 + sh / 2, sw, sh, 2))
        for dx in (-50, 50):            # antenas de los dos receptores RF
            trasera.agujero(W / 2 + dx, 15, 3)
        yt = sy0 + sh + 21
        for i, s in enumerate(lineas):
            trasera.grabado += texto(P, s, W / 2, yt - i * 5.2, 3.4 if i == 0 else 3.0, peso=700 if i == 0 else 500)

    # ---------------- Laterales: ventilación ----------------
    for lat in (izq, der):
        for i in range(6):
            y = D / 2 + (i - 2.5) * 8
            lat.quitar(ranura_redonda(y, Hw / 2 - 12, y, Hw / 2 + 12, 3))

    # ---------------- Barras para sostener las matrices ----------------
    if P["sujecion_matrices"]:
        barra = Pieza("pong_barra_matrices", 2 * sx + 8, 10, "Barra que aprieta las matrices por detrás")
        barra.agujero(4, 5, P["tornillo_diametro"])
        barra.agujero(4 + 2 * sx, 5, P["tornillo_diametro"])
        barra.cantidad = 2
        extra.append(barra)

    lista = [tapa, base, piezas["frente"], trasera, izq, der] + extra
    return lista, info


# ----------------------------------------------------------------------------
#  Cajita de cada control inalámbrico
# ----------------------------------------------------------------------------
def caja_control(P, jugador):
    W, D, H = P["control_ancho"], P["control_fondo"], P["control_alto"]
    pref = f"control_{jugador.lower()}"
    piezas, info = construir_caja(P, pref, W, D, H,
                                  pos_t_largas=[0.25 * W, 0.75 * W],
                                  pos_t_cortas=[0.5 * D])
    tapa, frente, trasera = piezas["tapa"], piezas["frente"], piezas["trasera"]
    db = P["boton_diametro"]
    xb = 28
    for y, arriba in ((D * 0.70, True), (D * 0.30, False)):
        tapa.agujero(xb, y, db)
        tapa.grabado.append(triangulo(xb + db / 2 + 9, y, 7, hacia_arriba=arriba))
    tapa.grabado += texto(P, jugador, 0.70 * W, D / 2 + 4, 16, peso=800)
    tapa.grabado += texto(P, "PONG · ED1", 0.70 * W, D / 2 - 14, 4, peso=600)
    tapa.agujero(W - 12, D - 12, P["led_diametro"])
    tapa.marcado.append((puntos_rect_redondeado(xb + 5, D / 2, db + 26, D - 14, 5), True))

    Hw = info["Hw"]
    # Interruptor de balancín en el frente y salida de la antena atrás
    frente.quitar(rect_centro(W / 2, Hw / 2, P["interruptor_ancho"], P["interruptor_alto"]))
    frente.grabado += texto(P, "ON", W / 2 + P["interruptor_ancho"] / 2 + 6, Hw / 2, 3.2, peso=600)
    trasera.agujero(W / 2, Hw / 2, 3)

    for p in piezas.values():
        p.descripcion += f" - control {jugador}"
    lista = [tapa, piezas["base"], frente, trasera, piezas["lateral_izq"], piezas["lateral_der"]]
    return lista, info


def construir(P):
    principal, info_p = caja_principal(P)
    c1, info_c = caja_control(P, "J1")
    c2, _ = caja_control(P, "J2")
    return principal + c1 + c2, dict(principal=info_p, control=info_c)


# ----------------------------------------------------------------------------
#  Acomodar las piezas en hojas (estantes sencillos, de la más alta a la más
#  baja). No es el acomodo óptimo, pero es predecible y deja aire entre
#  piezas para que el láser no queme bordes vecinos.
# ----------------------------------------------------------------------------
class Colocada:
    def __init__(self, pieza, dx, dy, girada):
        self.pieza, self.dx, self.dy, self.girada = pieza, dx, dy, girada

    def f(self, x, y):
        if self.girada:   # 90° antihorario
            x, y = self.pieza.alto - y, x
        return (x + self.dx, y + self.dy)

    def geom(self, g):
        if self.girada:
            g = affinity.rotate(g, 90, origin=(0, 0))
            g = affinity.translate(g, self.pieza.alto, 0)
        return affinity.translate(g, self.dx, self.dy)

    @property
    def w(self):
        return self.pieza.alto if self.girada else self.pieza.ancho

    @property
    def h(self):
        return self.pieza.ancho if self.girada else self.pieza.alto


def acomodar(piezas, hoja_w, hoja_h, margen=6.0, aire=4.0):
    instancias = []
    for p in piezas:
        for _ in range(p.cantidad):
            instancias.append(p)
    # Dejamos el lado largo horizontal y ordenamos por altura
    orden = sorted(instancias, key=lambda p: -min(p.ancho, p.alto))
    hojas = [[]]
    x, y, alto_fila = margen, margen, 0.0
    for p in orden:
        girada = p.alto > p.ancho
        w = p.alto if girada else p.ancho
        h = p.ancho if girada else p.alto
        if x + w > hoja_w - margen:
            x, y = margen, y + alto_fila + aire
            alto_fila = 0.0
        if y + h > hoja_h - margen:
            hojas.append([])
            x, y, alto_fila = margen, margen, 0.0
        hojas[-1].append(Colocada(p, x, y, girada))
        x += w + aire
        alto_fila = max(alto_fila, h)
    return hojas


def hojas_por_grupo(piezas, hoja_w, hoja_h):
    """La caja y los controles van en hojas separadas: así podemos cortar la
    caja ya y dejar los controles para cuando el circuito inalámbrico esté listo."""
    grupos = [("caja", [p for p in piezas if p.nombre.startswith("pong_")]),
              ("controles", [p for p in piezas if p.nombre.startswith("control_")])]
    salida = []
    for nombre, lista in grupos:
        hojas = acomodar(lista, hoja_w, hoja_h)
        for k, h in enumerate(hojas, 1):
            salida.append((nombre if len(hojas) == 1 else f"{nombre}{k}", h))
    return salida


# ----------------------------------------------------------------------------
#  Escritura de los DXF
# ----------------------------------------------------------------------------
CAPAS = {"CORTE": 1, "GRABADO": 5, "MARCADO": 3, "REFERENCIA": 8}


def documento_nuevo():
    doc = ezdxf.new("R2010", setup=True)
    doc.units = units.MM
    doc.header["$MEASUREMENT"] = 1
    for nombre, color in CAPAS.items():
        doc.layers.add(nombre, color=color)
    return doc


def poligonos(g):
    return [g] if g.geom_type == "Polygon" else list(g.geoms)


def dibujar(msp, col, P, con_referencia):
    p, k = col.pieza, P["kerf"]
    # Compensación del kerf: inflamos la pieza medio kerf. El contorno crece
    # y los huecos se achican, que es justo lo que se come el láser.
    cuerpo = col.geom(p.cuerpo).buffer(k / 2, join_style="mitre", mitre_limit=5)
    for poly in poligonos(cuerpo):
        msp.add_lwpolyline(list(poly.exterior.coords)[:-1], close=True, dxfattribs={"layer": "CORTE"})
        for hueco in poly.interiors:
            msp.add_lwpolyline(list(hueco.coords)[:-1], close=True, dxfattribs={"layer": "CORTE"})
    for (x, y, r) in p.circulos:
        msp.add_circle(col.f(x, y), r - k / 2, dxfattribs={"layer": "CORTE"})
    for pts in p.grabado:
        msp.add_lwpolyline([col.f(*q) for q in pts], close=True, dxfattribs={"layer": "GRABADO"})
    for pts, cerrada in p.marcado:
        msp.add_lwpolyline([col.f(*q) for q in pts], close=cerrada, dxfattribs={"layer": "MARCADO"})
    if con_referencia:
        for pts, cerrada in p.referencia:
            msp.add_lwpolyline([col.f(*q) for q in pts], close=cerrada, dxfattribs={"layer": "REFERENCIA"})
        cx, cy = col.f(p.ancho / 2, 4.5) if not col.girada else col.f(p.ancho / 2, p.alto / 2)
        msp.add_text(p.nombre, height=2.5, dxfattribs={"layer": "REFERENCIA"}).set_placement(
            (cx, cy), align=TextEntityAlignment.MIDDLE_CENTER)


def escribir_hoja(colocadas, ruta, P, con_referencia, marco=None):
    doc = documento_nuevo()
    msp = doc.modelspace()
    for col in colocadas:
        dibujar(msp, col, P, con_referencia)
    if con_referencia and marco:
        msp.add_lwpolyline(puntos_rect(0, 0, *marco), close=True, dxfattribs={"layer": "REFERENCIA"})
    doc.saveas(ruta)
    return doc


def main():
    P = cargar_parametros(sys.argv[1] if len(sys.argv) > 1 else None)
    piezas, info = construir(P)

    d_piezas = os.path.join(AQUI, "dxf", "piezas")
    d_hojas = os.path.join(AQUI, "dxf", "hojas_para_laser")
    d_guia = os.path.join(AQUI, "dxf", "guia_con_referencias")
    for d in (d_piezas, d_hojas, d_guia):
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith(".dxf"):
                os.remove(os.path.join(d, f))

    for p in piezas:
        escribir_hoja([Colocada(p, 0, 0, False)], os.path.join(d_piezas, f"{p.nombre}.dxf"), P, False)

    hw, hh = P["hoja_ancho"], P["hoja_alto"]
    hojas = hojas_por_grupo(piezas, hw, hh)
    for i, (grupo, hoja) in enumerate(hojas, 1):
        escribir_hoja(hoja, os.path.join(d_hojas, f"hoja_{i}_{grupo}_{int(hw)}x{int(hh)}mm.dxf"), P, False)
        escribir_hoja(hoja, os.path.join(d_guia, f"hoja_{i}_{grupo}_guia.dxf"), P, True, marco=(hw, hh))

    print(f"Piezas distintas: {len(piezas)}  |  láminas a cortar: {sum(p.cantidad for p in piezas)}")
    print(f"Hojas de {hw:.0f} x {hh:.0f} mm: {len(hojas)} ({', '.join(n for n, _ in hojas)})")
    ip = info["principal"]
    print(f"Caja principal {ip['W']:.0f} x {ip['D']:.0f} x {ip['H']:.0f} mm, "
          f"{ip['n_dedos']} dedos de {ip['seg']:.2f} mm por esquina")
    return piezas, info, hojas


if __name__ == "__main__":
    main()
