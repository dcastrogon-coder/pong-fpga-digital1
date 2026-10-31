#!/usr/bin/env python3
# ============================================================================
#  ecuaciones_fsm.py
#  Saca las ecuaciones de estado siguiente de la FSM del transmisor MAX7219
#  a partir de su tabla de transición (sección 4.2 de la guía de la etapa 1).
#  Es lo mismo que haríamos con mapas de Karnaugh de 5 variables, pero con
#  Quine-McCluskey (sympy), para revisar que no nos equivocamos a mano.
#
#  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
#           David Eduardo Chivata Arias
#  Uso:  pip install sympy  &&  python3 ecuaciones_fsm.py
# ============================================================================
from sympy import symbols
from sympy.logic import SOPform

Q2, Q1, Q0, T, U = symbols("Q2 Q1 Q0 T U")
NOMBRES = {0: "CARGA", 1: "BAJO", 2: "ALTO", 3: "CIERRE", 4: "LATCH", 5: "SEPARA"}


def siguiente(q, t, u):
    """Tabla de transición, tal cual está en la guía."""
    if q == 0:
        return 1                                  # CARGA -> BAJO siempre
    if q == 1:
        return 2 if t else 1                      # BAJO
    if q == 2:
        return (3 if u else 1) if t else 2        # ALTO
    if q == 3:
        return 4 if t else 3                      # CIERRE
    if q == 4:
        return 5 if t else 4                      # LATCH
    if q == 5:
        return 0 if t else 5                      # SEPARA
    return 0                                      # 110 y 111 -> CARGA


filas = [(q, t, u, siguiente(q, t, u)) for q in range(8) for t in (0, 1) for u in (0, 1)]


def bits(q, t, u):
    return [(q >> 2) & 1, (q >> 1) & 1, q & 1, t, u]


def mostrar(expr):
    return str(expr).replace("~", "¬").replace("&", "·").replace("|", "+")


print("Con 110 y 111 especificados (lo que usamos):")
for b, nombre in [(2, "D2"), (1, "D1"), (0, "D0")]:
    mins = [bits(q, t, u) for q, t, u, n in filas if (n >> b) & 1]
    print(f"  {nombre} = {mostrar(SOPform([Q2, Q1, Q0, T, U], mins))}")

print("\nCon 110 y 111 como 'no importa' (más corto, pero 111 se va a LATCH):")
nc = [bits(q, t, u) for q in (6, 7) for t in (0, 1) for u in (0, 1)]
for b, nombre in [(2, "D2"), (1, "D1"), (0, "D0")]:
    mins = [bits(q, t, u) for q, t, u, n in filas if q < 6 and (n >> b) & 1]
    print(f"  {nombre} = {mostrar(SOPform([Q2, Q1, Q0, T, U], mins, nc))}")

print("\nSalidas (Moore):  CLK_LED = ¬Q2·Q1·¬Q0     LOAD = Q2·¬Q1·¬Q0")
