# `puntaje.v`: contadores de 0 a 9 y victoria

[Volver al índice](README.md) · Código: [`rtl/puntaje.v`](../rtl/puntaje.v)

## Qué hace

Lleva el marcador de los dos jugadores. Cada puntaje es un número de 0 a 9 guardado en 4 bits, que es directamente su código BCD. Además, le avisa a la máquina de estados si el punto que se está sumando es el de la victoria (`WIN_NEXT`).

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `GOAL_J1`, `GOAL_J2` | entrada | Gol de cada jugador, desde [`colisiones`](colisiones.md) |
| `CAPTURE_GOAL` | entrada | Ciclo en que la FSM registra el gol |
| `POINT_EN` | entrada | Ciclo en que la FSM suma el punto (estado PUNTO) |
| `SCORE_J1[3:0]`, `SCORE_J2[3:0]` | salida | Puntaje de cada jugador (0 a 9) |
| `SCORER` | salida | Quién anotó el último gol: 0 = jugador 1, 1 = jugador 2 |
| `WIN_NEXT` | salida | El punto que se suma en este ciclo es el noveno |

## Cómo funciona

El punto se suma en dos pasos, en dos ciclos seguidos:

### Paso 1: recordar quién anotó (ciclo del gol, estado JUEGO)

```verilog
assign VALID_GOAL = GOAL_J1 ^ GOAL_J2;
assign CG = CAPTURE_GOAL && VALID_GOAL;

if (INIT_GLOBAL) SCORER <= 0;
else if (CG)     SCORER <= GOAL_J2;
```

Cuando hay un gol válido (de un solo jugador), guardamos en `SCORER` quién fue. Las señales `GOAL_J1` y `GOAL_J2` duran un solo ciclo, por eso hay que registrarlas antes de que desaparezcan.

### Paso 2: sumar (ciclo siguiente, estado PUNTO)

```verilog
assign INC_J1 = POINT_EN && !SCORER && (SCORE_J1 < 9);
assign INC_J2 = POINT_EN &&  SCORER && (SCORE_J2 < 9);

if (INC_J1) SCORE_J1 <= SCORE_J1 + 1;
if (INC_J2) SCORE_J2 <= SCORE_J2 + 1;
```

Durante el único ciclo de PUNTO se suma 1 al jugador que anotó. La condición `< 9` impide pasar de 9: el contador se queda ahí aunque llegara otro `POINT_EN`.

### Aviso de victoria

```verilog
assign WIN_J1   = !SCORER && (SCORE_J1 >= 8);
assign WIN_J2   =  SCORER && (SCORE_J2 >= 8);
assign WIN_NEXT = POINT_EN && (WIN_J1 || WIN_J2);
```

Si el que anotó ya tiene 8 puntos, este punto lo lleva a 9 y gana. `WIN_NEXT` sale en el mismo ciclo de PUNTO, así [`control_juego`](control_juego.md) decide ahí mismo si va a FIN o a ESPERA, sin esperar a que el marcador muestre el 9.

## Ejemplo: el jugador 2 anota con el marcador 3–8

| Ciclo | Estado | Qué pasa |
|-------|--------|----------|
| n | JUEGO | `GOAL_J2 = 1`, `CAPTURE_GOAL = 1`. Se guarda `SCORER = 1` |
| n+1 | PUNTO | `POINT_EN = 1`. Como `SCORE_J2 = 8`, `WIN_NEXT = 1`. Se suma: `SCORE_J2` pasa a 9 |
| n+2 | FIN | El marcador muestra 3–9 y el juego se queda quieto hasta RESET |

## Por qué lo hicimos así

* **Guardar el puntaje directamente en BCD.** Como solo se llega hasta 9, un contador binario de 4 bits ya es BCD. No hace falta ninguna conversión antes de mandarlo a los CD4511BE (ver [`marcador_bcd`](marcador_bcd.md)).
* **Separar la captura y la suma.** El gol se detecta en JUEGO y el punto se suma en PUNTO. Así la suma ocurre en un estado propio, siempre una sola vez por gol, y la decisión de victoria queda en el mismo ciclo que la suma.
* **Calcular la victoria por adelantado.** Si esperáramos a ver un 9 en el registro, la FSM tendría que pasar por ESPERA y volver a revisar. Con `WIN_NEXT` la transición a FIN es directa.
* **Saturar en 9.** Es una protección extra: aunque por algún error llegara un punto de más, el marcador nunca muestra un valor que no sea BCD. Si de todos modos apareciera un valor de 10 a 15, [`supervisor_fallos`](supervisor_fallos.md) reinicia el sistema.

## Cómo lo probamos

* `tb_puntaje` (F3): 37 pruebas contra un modelo de referencia: sumas, saturación, aviso de victoria y reset.
* `tb_puntaje_reset_f5`: 10 pruebas, incluidos los goles simultáneos (que no cuentan) y el RESET con el marcador a mitad de partida.
* `tb_colisiones_puntaje_f5`: gol de cada jugador y suma en el marcador.
* `tb_pong_goles_victoria`: partida completa hasta la victoria 9–1.
* En la tarjeta jugamos una partida completa que terminó 9–6.

## Historia

Escrito en F3. No cambió en las fases siguientes. En F6 solo sacamos sus salidas a los pines.
