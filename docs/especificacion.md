# Especificación funcional (Fase 0 · PC0)

Estas son las reglas del juego tal como quedaron congeladas antes de escribir una sola línea de Verilog. Cada regla apunta a la decisión que la justifica en [`decisiones.md`](decisiones.md).

## Reglas del juego

1. **Encendido.** El sistema arranca en ESPERA con el marcador en 0-0, las dos paletas en las filas 2-4 y la pelota titilando en el centro (D-02, D-13). Los MAX7219 se configuran solos al encender.
2. **Inicio.** START inicia la partida, siempre que los dos controles tengan enlace (D-11, D-12).
3. **Paletas.** Cada jugador mueve su paleta de 3 LEDs con *subir* y *bajar*. Un toque mueve una fila; si se mantiene presionado, después de 180 ms la paleta sigue moviéndose una fila cada 90 ms. Nunca sale de las filas 0-7 (D-01, D-03).
4. **Conflicto.** Subir y bajar al mismo tiempo no mueve la paleta (D-04).
5. **Pelota.** Se mueve siempre en diagonal, una casilla por paso. El paso dura 260 ms al empezar cada jugada y se acorta a 200, 150 y 110 ms cada 3 rebotes en paleta (D-06, D-07).
6. **Paredes.** En la fila 0 y en la 7 la pelota rebota invirtiendo su dirección vertical.
7. **Paletas y efecto.** Si la pelota llega a la columna vecina a una paleta y la paleta cubre su fila, rebota. Si golpea la fila de arriba de la paleta sale hacia arriba, si golpea la de abajo sale hacia abajo, y si golpea el centro conserva su dirección vertical (D-05).
8. **Gol.** Si la paleta no cubre la fila de la pelota, la pelota pasa a la columna de la paleta y se suma **un** punto al rival (D-08).
9. **Después del gol.** El juego se congela 1 s y la pelota sale del centro hacia el jugador que perdió el punto (D-09).
10. **Victoria.** Gana el primero en llegar a 9. La mitad de la pantalla del ganador y su display titilan; START prepara una partida nueva en 0-0 (D-10, D-14).
11. **Pausa.** START durante el juego pausa; START de nuevo reanuda. Si se pierde la señal de algún control, el juego entra en pausa y las órdenes de ese control se ignoran hasta que vuelva el enlace (D-11).
12. **Reinicio.** RESET en cualquier momento devuelve todo al estado de encendido (salvo la pantalla, que no necesita reconfigurarse).

## Inventario de entradas, salidas y estados

| Tipo | Señal | Origen / destino | Notas |
|------|-------|------------------|-------|
| Entrada | `CLK_SYS` | oscilador de la tarjeta | 50 MHz (por confirmar) |
| Entrada | `J1_UP`, `J1_DOWN`, `J2_UP`, `J2_DOWN` | receptores RF (en simulación, el testbench) | polaridad por parámetro |
| Entrada | `J1_VT`, `J2_VT` | pin VT del HT12D | 1 = transmisión válida |
| Entrada | `START_PIN`, `RESET_PIN` | pulsadores de la tarjeta | activos en bajo |
| Salida | `DIN`, `CLK_LED`, `LOAD` | 2 × MAX7219 en cascada | a 5 V a través del SN74AHCT125 |
| Salida | `SEG_J1[6:0]`, `SEG_J2[6:0]` | displays de 7 segmentos | `{g,f,e,d,c,b,a}` |
| Salida | `LED[3:0]` | LEDs de la tarjeta | jugando, pausa, enlace J1, enlace J2 |
| Estado | `YP1`, `YP2` | paletas | 3 bits c/u |
| Estado | `X`, `Y`, `DX`, `DY` | pelota | 4 + 3 + 1 + 1 bits |
| Estado | `P1`, `P2` | marcador | 4 bits c/u |
| Estado | `estado` | FSM general | 3 bits |
| Estado | `idx`, `sr`, `bits`, `estado_tx` | FSM del MAX7219 | ver ficha 8 |

## Requisitos y prueba asociada

| ID | Requisito | Prueba | Testbench |
|----|-----------|--------|-----------|
| R01 | Dos jugadores desplazan su paleta de forma independiente | T01 | `tb_paletas`, `tb_integracion` |
| R02 | Ninguna paleta sale del área vertical | T02 | `tb_paletas` (monitor en cada ciclo) |
| R03 | La pelota se mueve con un pulso temporal definido | T03 | `tb_pelota`, `tb_generador_ticks` |
| R04 | Rebotes superior, inferior y con paletas | T04 | `tb_colisiones` (exhaustivo), `tb_pelota` |
| R05 | Al fallar se suma un punto al rival una sola vez | T05 | `tb_pelota`, `tb_puntaje`, `tb_integracion` |
| R06 | El marcador se conserva y se reinicia según las reglas | T06 | `tb_puntaje`, `tb_control_juego`, `tb_integracion` |
| R07 | La imagen ocupa la matriz de 8 × 16 | T07 | `tb_imagen` |
| R08 | Dos MAX7219 reciben tramas seriales correctas | T08 | `tb_max7219`, `tb_integracion` |
| R09 | Los controles RF generan órdenes válidas y seguras | T09 | `tb_entradas`, `tb_control_juego`, `tb_integracion` |
| R10 | FPGA y periféricos sin infringir niveles eléctricos | T10 | revisión de [`hardware.md`](hardware.md) (no se simula) |
