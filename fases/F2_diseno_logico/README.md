# F2 · Diseño lógico formal (rev. 1.2)

Documento: [`F2_diseno_logico_formal_rev1.2.pdf`](F2_diseno_logico_formal_rev1.2.pdf) · 2 de noviembre de 2026 · **PC1**

Diseñamos diez bloques con tablas de verdad, tablas de transición y ecuaciones:

1. Paletas: ecuaciones de inversión T0–T2 y posición efectiva `YPi_EFF`.
2. Pelota: candidatos `Xc`, `Yc`, reflexión vertical `RY` y fase.
3. Colisiones: `EL`, `ER`, coincidencia con la paleta, `HIT` y `GOAL` por jugador.
4. Puntaje: registro SCORER, contadores BCD 0–9 y predicción de victoria `WIN_NEXT`.
5. FSM del juego de seis estados: ecuaciones D2, D1, D0 y salidas `GAME_EN`, `CAPTURE_GOAL`, `POINT_EN`, `CENTER_EN`, `REARM_TIMERS`.
6. Temporizadores de 200 ms y 250 ms.
7. Instantánea y generador de filas.
8. Transmisor doble MAX7219: FSM de 13 estados, 14 instrucciones de inicialización.
9. Buses BCD y tabla de minitérminos de cada segmento.
10. Botones, reset seguro y supervisión RF (timeout de 500 ms).

También dejamos definida la política de inicialización global (`INIT_GLOBAL = POR_REQ + RESET_CLEAN + FAULT_RECOVER`) y los detectores de códigos inválidos.
