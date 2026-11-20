# `pong_f5_controles_top.v`: juego con mandos cableados (F5)

[Volver al índice](README.md) · Código: [`rtl/pong_f5_controles_top.v`](../rtl/pong_f5_controles_top.v)

## Qué es

Es el top con el que validamos el juego completo en la tarjeta en F5: mandos cableados, pulsadores, movimiento diagonal y las dos matrices. Es casi idéntico al top final [`pong_f6_integracion_top`](pong_f6_integracion_top.md); la única diferencia es que **no saca el marcador** a pines:

```verilog
.SCORE_J1_BCD(),
.SCORE_J2_BCD()
```

Por eso esta versión usa 14 pines (1 reloj, 9 entradas y 4 salidas), y la de F6, 22.

## Parámetros y puertos

Son los mismos que en [`pong_f6_integracion_top`](pong_f6_integracion_top.md), sin `SCORE_J1_BCD` ni `SCORE_J2_BCD`:

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `HCT_WAIT_CYCLES` | 2 500 000 | Espera de 50 ms antes de subir `HCT_EN` |
| `NDB_RESET_TOP` | 1 000 000 | Liberación del RESET (20 ms) |

| Puertos | Dirección |
|---------|-----------|
| `CLK_SYS`, `START_N`, `RESET_N`, `PAUSE_N`, `J1_UP_N`, `J1_DOWN_N`, `J1_DETECT_N`, `J2_UP_N`, `J2_DOWN_N`, `J2_DETECT_N` | entrada |
| `DIN`, `CLK_LED`, `LOAD`, `HCT_EN` | salida |

## Cómo funciona

Igual que el top final: niega los pulsadores para pasarlos activos en alto al núcleo [`pong_f5_core`](pong_f5_core.md), mantiene el núcleo en reset mientras `HCT_EN = 0` y genera `HCT_EN` con un contador de 50 ms. La explicación completa está en [`pong_f6_integracion_top`](pong_f6_integracion_top.md).

## Por qué lo dejamos

* Varios bancos de prueba de F5 lo instancian (`tb_hct_arranque_f5`, `tb_hct_init_max7219_f5`, `tb_hct_filas_f5`, `tb_hct_refresco_f5` y `tb_gc7219_temporizacion_f5`), y siguen pasando en la regresión. Como el núcleo y el contador son los mismos del top final, esas pruebas también cubren el diseño actual.
* Con él se puede probar el juego sin el marcador conectado.

## Historia

Escrito en F5. En F6 lo copiamos como `pong_f6_integracion_top` y le agregamos las salidas BCD.
