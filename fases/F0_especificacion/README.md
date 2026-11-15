# F0 · Especificación funcional (rev. 1.2)

📄 [`F0_especificacion_funcional_rev1.2.pdf`](F0_especificacion_funcional_rev1.2.pdf) · 2 de noviembre de 2026 · **PC0**

Aquí congelamos las reglas del juego antes de diseñar nada:

* Tablero de 8 × 16 con origen arriba a la izquierda: 0 ≤ X ≤ 15, 0 ≤ Y ≤ 7.
* Paletas de 2 LED en X = 0 (J1) y X = 15 (J2), con 0 ≤ YP ≤ 6 y arranque en YP = 3.
* Pelota que sale de (7, 3); se mueve en X cada 200 ms y en Y cada 400 ms. Las paletas se mueven cada 250 ms.
* Gana el primero que llegue a 9.
* Tres pulsadores: START, RESET y PAUSE. La revisión 1.2 agrega la pausa manual con su propio botón.
* FSM de seis estados: ESPERA, JUEGO, PUNTO, PAUSA_RF, FIN y PAUSA_MANUAL.
* Requisitos R01–R12 con sus pruebas T01–T12, y las decisiones D01–D36.

> En F5 cambiamos dos reglas: los controles pasaron a ser cableados y la pelota se mueve en diagonal (X e Y cada 200 ms). Ver [`../README.md`](../README.md).
