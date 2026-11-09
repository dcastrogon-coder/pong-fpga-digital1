#!/usr/bin/env python3
# ============================================================================
#  verificar_caja.py  -  Revisiones automáticas antes de mandar a cortar
#  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
# ----------------------------------------------------------------------------
#  Cortar una lámina mala cuesta plata y tiempo, así que antes de ir al
#  láser revisamos con código lo que más se suele dañar:
#
#    1. Que los dedos de cada esquina encajen: a cualquier altura, en el
#       cuadradito de la esquina debe haber material de UNA sola pared.
#    2. Que cada agujero de la tapa y de la base caiga justo encima del canal
#       de una ranura en T de alguna pared.
#    3. Que ningún hueco quede pegado a otro o al borde (dejamos mínimo 2 mm
#       de "puente" para que el MDF no se parta).
#    4. Que lo que va adentro quepa (tarjeta, ventanas, alturas).
#    5. Que los DXF estén sanos: todo lo de CORTE cerrado, unidades en mm y
#       sin errores en la auditoría de ezdxf.
#
#  Al final imprime los metros de corte por hoja, que es lo que suelen
#  cobrar en los locales de corte láser.
# ============================================================================

import glob
import math
import os
import sys

import ezdxf
from shapely.geometry import Point

import generar_caja as gc

AQUI = os.path.dirname(os.path.abspath(__file__))
fallas = []


def revisar(cond, msg):
    print(("  PASA  " if cond else "  FALLA ") + msg)
    if not cond:
        fallas.append(msg)


def esquinas(nombre, piezas, info):
    T, Hw, W, D = info["T"], info["Hw"], info["W"], info["D"]
    larga = piezas[f"{nombre}_frente"].cuerpo
    corta = piezas[f"{nombre}_lateral_izq"].cuerpo
    malas = 0
    muestras = 400
    for i in range(muestras):
        v = (i + 0.5) * Hw / muestras
        for ul, uc in ((T / 2, T / 2), (W - T / 2, D - T / 2)):
            a = larga.contains(Point(ul, v))
            b = corta.contains(Point(uc, v))
            if a == b:
                malas += 1
    revisar(malas == 0, f"{nombre}: dedos complementarios en las esquinas ({muestras} alturas, {malas} choques/huecos)")


def ranuras_t(nombre, piezas, info):
    T, W, D = info["T"], info["W"], info["D"]
    d = 3.2
    for cual in ("tapa", "base"):
        p = piezas[f"{nombre}_{cual}"]
        bien = 0
        for (x, y, r) in p.circulos:
            # ¿Está sobre la línea media de alguna pared?
            if abs(y - T / 2) < 1e-6 or abs(y - (D - T / 2)) < 1e-6:
                pared = piezas[f"{nombre}_frente"] if y < D / 2 else piezas[f"{nombre}_trasera"]
                u = x if y < D / 2 else W - x
            elif abs(x - T / 2) < 1e-6 or abs(x - (W - T / 2)) < 1e-6:
                pared = piezas[f"{nombre}_lateral_izq"] if x < W / 2 else piezas[f"{nombre}_lateral_der"]
                u = y
            else:
                continue
            borde = pared.alto - 0.5 if cual == "tapa" else 0.5
            if not pared.cuerpo.contains(Point(u, borde)) and not pared.cuerpo.contains(Point(u, (pared.alto - 7) if cual == "tapa" else 7)):
                bien += 1
        total = sum(1 for (x, y, r) in p.circulos if r * 2 == d and (min(x, W - x) < T or min(y, D - y) < T))
        revisar(bien == total and total > 0, f"{nombre}_{cual}: {bien}/{total} tornillos caen sobre un canal en T")


def puentes(piezas, minimo=2.0):
    peor = (1e9, "")
    for p in piezas:
        geoms = []
        for poly in gc.poligonos(p.cuerpo):
            for h in poly.interiors:
                geoms.append(("hueco", gc.Polygon(h)))
        for (x, y, r) in p.circulos:
            geoms.append(("circulo", Point(x, y).buffer(r, quad_segs=16)))
        exterior = gc.Polygon(p.cuerpo.exterior) if p.cuerpo.geom_type == "Polygon" else None
        for i, (ti, gi) in enumerate(geoms):
            # al borde exterior (los tornillos de tapa/base van a T/2 del borde a propósito)
            if exterior is not None and not (p.tapa_o_base and ti == "circulo" and gi.area < 9):
                dist = exterior.exterior.distance(gi)
                if dist < peor[0]:
                    peor = (dist, f"{p.nombre}: {ti} al borde")
            for tj, gj in geoms[i + 1:]:
                dist = gi.distance(gj)
                if dist < peor[0]:
                    peor = (dist, f"{p.nombre}: {ti}-{tj}")
    revisar(peor[0] >= minimo, f"puente mínimo entre cortes = {peor[0]:.2f} mm (en {peor[1]}), pedimos ≥ {minimo} mm")


def holguras(P, piezas, info):
    T = info["T"]
    W, D, H = info["W"], info["D"], info["H"]
    revisar(P["tarjeta_ancho"] <= W - 2 * T - 10 and P["tarjeta_fondo"] <= D - 2 * T - 10,
            f"la tarjeta {P['tarjeta_ancho']:.0f}x{P['tarjeta_fondo']:.0f} cabe en el interior {W-2*T:.0f}x{D-2*T:.0f}")
    alto_int = H - 2 * T
    sep = P.get("separador_tarjeta", 10)
    # Abajo: separador + PCB 1.6 + conector JTAG ~ 12; arriba: módulo de matrices colgando ~ 18
    revisar(sep + 1.6 + 12 + 18 + 5 <= alto_int, f"altura interior {alto_int:.0f} mm alcanza para tarjeta (~{sep+13.6:.0f}) + matrices (~18) + aire")
    if P.get("montaje", "protoboard") == "protoboard":
        from shapely.geometry import box
        tj = box(*info["tarjeta"])
        pi = box(*info["proto_interna"])
        revisar(tj.distance(pi) >= 3, f"tarjeta y protoboard de adentro no se montan una sobre otra (quedan a {tj.distance(pi):.1f} mm)")
        interior = box(T, T, W - T, D - T)
        revisar(interior.contains(tj) and interior.contains(pi), "tarjeta y protoboard quedan dentro de las paredes")
        # La proto de la tapa queda a ras: su cara de abajo está a H - alto_proto,
        # y debajo va la lámina de soporte (T). Debajo de eso tiene que caber la
        # proto de adentro con sus cables parados (~ 8,5 + 18 mm).
        z_soporte = H - P["proto_alto"] - T
        z_cables = T + P["proto_alto"] + 18
        revisar(z_soporte - z_cables >= 10, f"entre la proto de adentro con cables ({z_cables:.0f} mm) y el soporte de la de arriba ({z_soporte:.0f} mm) quedan {z_soporte - z_cables:.0f} mm")
        tapa = piezas["pong_tapa"]
        sop = piezas["pong_soporte_protoboard"]
        cx, py = W / 2, P["proto_tapa_y"]
        ht = sorted((round(x - cx, 3), round(y - py, 3)) for (x, y, r) in tapa.circulos if abs(y - py) < 40 and 60 < abs(x - cx) < 100)
        hs = sorted((round(x - sop.ancho / 2, 3), round(y - sop.alto / 2, 3)) for (x, y, r) in sop.circulos)
        revisar(ht == hs, f"los 4 tornillos del soporte coinciden con los 4 de la tapa ({len(hs)} de {len(ht)})")
        ventana = box(cx - P["proto_ancho"] / 2, py - P["proto_fondo"] / 2, cx + P["proto_ancho"] / 2, py + P["proto_fondo"] / 2)
        lamina = box(cx - sop.ancho / 2, py - sop.alto / 2, cx + sop.ancho / 2, py + sop.alto / 2)
        revisar(ventana.within(lamina),
                "la protoboard de la tapa queda completa encima de su lámina de soporte")
    tapa = piezas["pong_tapa"]
    revisar(tapa.cuerpo.is_valid and len(tapa.cuerpo.interiors) >= 1, "la tapa tiene ventanas y es una geometría válida")
    for p in piezas.values():
        if not p.cuerpo.is_valid or p.cuerpo.geom_type != "Polygon":
            revisar(False, f"{p.nombre}: geometría inválida o partida")


def dxf_sanos(P):
    archivos = sorted(glob.glob(os.path.join(AQUI, "dxf", "**", "*.dxf"), recursive=True))
    abiertos, errores = 0, 0
    for f in archivos:
        doc = ezdxf.readfile(f)
        aud = doc.audit()
        errores += len(aud.errors)
        if doc.units != ezdxf.units.MM:
            errores += 1
        for e in doc.modelspace().query('LWPOLYLINE[layer=="CORTE"]'):
            if not e.closed:
                abiertos += 1
    revisar(errores == 0, f"{len(archivos)} DXF sin errores de auditoría y en milímetros")
    revisar(abiertos == 0, "todas las polilíneas de CORTE están cerradas")


def metros_de_corte():
    print("\n  Longitudes (para cotizar):")
    for f in sorted(glob.glob(os.path.join(AQUI, "dxf", "hojas_para_laser", "*.dxf"))):
        doc = ezdxf.readfile(f)
        msp = doc.modelspace()
        corte = 0.0
        for e in msp.query('LWPOLYLINE[layer=="CORTE"]'):
            pts = [tuple(q[:2]) for q in e.get_points()]
            corte += sum(math.dist(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts)))
        for c in msp.query('CIRCLE[layer=="CORTE"]'):
            corte += 2 * math.pi * c.dxf.radius
        n_grab = len(msp.query('LWPOLYLINE[layer=="GRABADO"]'))
        print(f"    {os.path.basename(f)}: {corte/1000:.2f} m de corte, {n_grab} contornos de grabado")


def main():
    P = gc.cargar_parametros(sys.argv[1] if len(sys.argv) > 1 else None)
    lista, info = gc.construir(P)
    piezas = {p.nombre: p for p in lista}
    print("Revisando la caja del Pong\n")
    esquinas("pong", piezas, info["principal"])
    esquinas("control_j1", piezas, info["control"])
    ranuras_t("pong", piezas, info["principal"])
    ranuras_t("control_j1", piezas, info["control"])
    puentes(lista)
    holguras(P, piezas, info["principal"])
    dxf_sanos(P)
    metros_de_corte()
    print("\nResultado:", "TODO PASA" if not fallas else f"{len(fallas)} FALLAS")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
