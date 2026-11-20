# `pong_f4_visual_top.v`: prueba de las matrices (F4)

[Volver al índice](README.md) · Código: [`rtl/pong_f4_visual_top.v`](../rtl/pong_f4_visual_top.v)

## Qué es

Es el top que usamos en F4 para encender por primera vez las dos matrices LED desde la FPGA. En ese momento todavía no teníamos los mandos ni los pulsadores conectados, así que este archivo instancia el núcleo de F3, [`pong_top`](pong_top.md), y fija todas las entradas a valores constantes:

```verilog
.START_RAW(1'b0), .RESET_RAW(1'b0), .PAUSE_RAW(1'b0),   // pulsadores sin presionar
.CMD_RX1(2'b00),  .FRAME_1_VALID(1'b0),                 // sin enlaces
.CMD_RX2(2'b00),  .FRAME_2_VALID(1'b0),
```

Solo saca a pines las tres líneas de las matrices: `DIN`, `CLK_LED` y `LOAD`. Las salidas del marcador quedan sin conectar.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS` | entrada | Reloj de 50 MHz |
| `DIN`, `CLK_LED`, `LOAD` | salida | Líneas seriales de las matrices |

## Qué se ve con este top

Como ningún enlace está vigente, la máquina de estados se queda en ESPERA y el juego no arranca. Pero el transmisor funciona de todos modos: configura las matrices y refresca la imagen sin parar. Lo que aparece es el estado inicial del juego:

* La paleta del jugador 1 en la columna 0, filas 3 y 4.
* La paleta del jugador 2 en la columna 15, filas 3 y 4.
* La pelota en la columna 7, fila 3.

Eso es justo lo que necesitábamos para comprobar la comunicación serial, la cascada de los dos controladores y la orientación de las matrices. Con este top encontramos que la imagen salía invertida y corregimos la orientación en [`imagen`](imagen.md) y [`transmisor_max7219`](transmisor_max7219.md).

La foto del resultado está en `fases/F4_interfaz_visual/F4_Prueba_Visual_MAX7219.png`.

## Por qué lo dejamos

Es la forma más rápida de comprobar solo la parte visual: si en algún momento las matrices dejaran de funcionar, con este top se puede descartar que el problema esté en los mandos o en la lógica del juego. Para usarlo hay que ponerlo como top en Quartus y asignar los pines de las tres líneas (ver [proyecto de Quartus](proyecto_quartus.md)).

## Historia

Escrito en F4. Desde F5 el top del proyecto es otro (primero [`pong_f5_controles_top`](pong_f5_controles_top.md), después [`pong_f6_integracion_top`](pong_f6_integracion_top.md)).
