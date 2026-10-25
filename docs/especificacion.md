# Especificación funcional (Fase 0 · PC0)

Estas son las reglas del juego tal como quedaron congeladas antes de escribir una sola línea de Verilog.

> **Actualización (D-25):** la pantalla definitiva es el módulo MAX7219 x4, así que la cancha es de **8 × 32**. Todo el diseño está parametrizado con `ANCHO`; con `ANCHO = 16` se obtiene exactamente la versión de dos matrices de la propuesta original. Abajo escribimos `U = ANCHO − 1` para la última columna. Cada regla apunta a la decisión que la justifica en [`decisiones.md`](decisiones.md).

## Reglas del juego

1. **Encendido.** El sistema arranca en ESPERA con el marcador en 0-0, las dos paletas en las filas 2-4 y la pelota titilando en el centro (D-02, D-13). Los MAX7219 se configuran solos al encender.
2. **Inicio.** START inicia la partida, siempre que los dos controles tengan enlace (D-11, D-12).
3. **Paletas.** Cada jugador mueve su paleta de 3 LEDs con *subir* y *bajar*. Un toque mueve una fila; si se mantiene presionado, después de 180 ms la paleta sigue moviéndose una fila cada 90 ms. Nunca sale de las filas 0-7 (D-01, D-03).
4. **Conflicto.** Subir y bajar al mismo tiempo no mueve la paleta (D-04).
5. **Pelota.** Se mueve siempre en diagonal, una casilla por paso. Con 32 columnas el paso dura 170 ms al empezar cada jugada y se acorta a 130, 100 y 75 ms cada 3 rebotes en paleta; con 16 columnas los pasos son 260, 200, 150 y 110 ms (D-06, D-07, D-26).
6. **Paredes.** En la fila 0 y en la 7 la pelota rebota invirtiendo su dirección vertical.
7. **Paletas y efecto.** Si la pelota llega a la columna vecina a una paleta y la paleta cubre su fila, rebota. Si golpea la fila de arriba de la paleta sale hacia arriba, si golpea la de abajo sale hacia abajo, y si golpea el centro conserva su dirección vertical (D-05).
8. **Gol.** Si la paleta no cubre la fila de la pelota, la pelota pasa a la columna de la paleta y se suma **un** punto al rival (D-08).
9. **Después del gol.** El juego se congela 1 s y la pelota sale del centro hacia el jugador que perdió el punto (D-09).
10. **Victoria.** Gana el primero en llegar a 9. La mitad de la pantalla del ganador y su display titilan; START prepara una partida nueva en 0-0 (D-10, D-14).
11. **Pausa.** START durante el juego pausa; START de nuevo reanuda. Si se pierde la señal de algún control, el juego entra en pausa y las órdenes de ese control se ignoran hasta que vuelva el enlace (D-11).
12. **Marcador.** El display de 8 dígitos de la tarjeta muestra a la izquierda el puntaje de J1, a la derecha el de J2 y en el centro un mensaje: `HOLA` en espera, `-n1-` a `-n4-` durante el juego (nivel de velocidad), `-GOL` tras un punto, `PAUS` en pausa y `GAnA` al final, con el puntaje del ganador titilando (D-28).
13. **Sonido.** Con el DIP 1 en ON, el buzzer pita en cada rebote, suena grave en cada gol y toca una melodía corta al final (D-29).
14. **Reinicio.** RESET en cualquier momento devuelve todo al estado de encendido (salvo la pantalla, que no necesita reconfigurarse). Mientras RESET está presionado la pantalla muestra el patrón de calibración (D-27).

## Inventario de entradas, salidas y estados

| Tipo | Señal | Origen / destino | Notas |
|------|-------|------------------|-------|
| Entrada | `CLK_SYS` | oscilador CLK_50M de la tarjeta (P23) | 50 MHz |
| Entrada | `J1_UP`, `J1_DOWN`, `J2_UP`, `J2_DOWN` | receptores RF (en simulación, el testbench) | polaridad por parámetro |
| Entrada | `J1_VT`, `J2_VT` | pin VT del HT12D | 1 = transmisión válida |
| Entrada | `START_PIN`, `RESET_PIN` | pulsadores K2 (P90) y K3 (P91) | activos en bajo |
| Entrada | `SW_SONIDO`, `SW_PRUEBA` | DIP SW1 (P58) y SW2 (P59) | 0 = ON |
| Salida | `DIN`, `CLK_LED`, `LOAD` | módulo MAX7219 x4 (4 chips en cascada) | a 5 V a través del SN74AHCT125 |
| Salida | `SEG[7:0]`, `DIG[7:0]` | display de 8 dígitos de la tarjeta | multiplexado; `{H..A}` y BIT7..BIT0 |
| Salida | `BUZZER` | buzzer de la tarjeta (P141) | pitidos del juego |
| Salida | `LED[3:0]` | LEDs D3-D6 de la tarjeta | jugando, pausa, enlace J1, enlace J2 |
| Estado | `YP1`, `YP2` | paletas | 3 bits c/u |
| Estado | `X`, `Y`, `DX`, `DY` | pelota | 5 + 3 + 1 + 1 bits (4 + 3 + 1 + 1 con 16 columnas) |
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
| R07 | La imagen ocupa la matriz de 8 × ANCHO (8 × 32 con el módulo x4) | T07 | `tb_imagen` |
| R08 | Los MAX7219 en cascada (4 en el módulo x4) reciben tramas seriales correctas | T08 | `tb_max7219`, `tb_integracion` |
| R09 | Los controles RF generan órdenes válidas y seguras | T09 | `tb_entradas`, `tb_control_juego`, `tb_integracion` |
| R10 | FPGA y periféricos sin infringir niveles eléctricos | T10 | revisión de [`hardware.md`](hardware.md) (no se simula) |
