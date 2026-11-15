# F1 · Arquitectura por bloques (rev. 1.1)

📄 [`F1_arquitectura_por_bloques_rev1.1.pdf`](F1_arquitectura_por_bloques_rev1.1.pdf) · 2 de noviembre de 2026 · **PC1**

Define los módulos del sistema y el contrato de entradas y salidas de cada uno (`entradas_rf`, `supervisor_rf`, `entradas_botones`, `temporizadores`, `control_juego`, `paletas`, `pelota`, `colisiones`, `puntaje`, `captura_imagen`, `imagen`, `max7219_tx` y `marcador`).

Tres decisiones de esta fase se mantuvieron hasta el final:

* El próximo estado de la pelota no forma lazo combinacional con las colisiones: el candidato sale de los registros actuales y solo se guarda en el flanco de reloj.
* Un gol llega a la FSM y al puntaje, y se cuenta una sola vez (registro SCORER + `POINT_EN`).
* El transmisor pide una instantánea de las posiciones (`CAPTURE_REQ` / `FRAME_READY`) para que las ocho filas de un cuadro sean coherentes.

La figura de arquitectura actualizada con el montaje real está en [`informes/figuras/`](../../informes/figuras/).
