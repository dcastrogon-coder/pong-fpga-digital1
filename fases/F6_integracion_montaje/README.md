# F6 · Integración, síntesis y montaje

Documento: [`F6_integracion_sintesis_y_montaje.pdf`](F6_integracion_sintesis_y_montaje.pdf) · 14 de noviembre de 2026 · **PC5–PC6**

En esta fase agregamos el marcador físico: los dos buses BCD salen por el conector LCD (J2) de la tarjeta, pasan por un segundo SN74HCT245N y llegan a dos CD4511BE que manejan dos displays 5161AS de cátodo común. Los dos búferes los habilitamos con `HCT_EN` (pin 49) a través de dos 2N3904. Las conexiones completas están en [`hardware/`](../../hardware/).

| Compilación completa (Quartus Prime 25.1 Lite) | Resultado |
|------------------------------------------------|-----------|
| Top | `pong_f6_integracion_top` |
| Errores / advertencias | 0 / 8 |
| Celdas lógicas | 660 (de 10 320) |
| Entradas / salidas | 10 / 12 |
| Peor *slack* de setup (lento, 85 °C) | +6,686 ns |
| Peor *slack* de hold (rápido, 0 °C) | +0,186 ns |
| Restricciones SDC | Diseño totalmente restringido |

| Prueba física | Resultado |
|---------------|-----------|
| Displays aislados con BCD forzado | 0–0 y 1–0 |
| Primera carga por JTAG | 100 %, matrices con el Pong, marcador en 0–0 |
| `HCT_EN` con la FPGA configurada | 3,27 V medidos |
| Matrices + marcador a la vez | Funcionan juntos |
| Partida completa | Marcador real hasta **9–6** |
| Victoria | El juego se detiene al llegar a 9 |
| RESET y nueva partida | Vuelve a 0–0 y START permite jugar otra vez |
