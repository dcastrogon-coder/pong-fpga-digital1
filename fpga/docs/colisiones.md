# `colisiones.v`: rebotes en las paletas y goles

[Volver al índice](README.md) · Código: [`rtl/colisiones.v`](../rtl/colisiones.v)

## Qué hace

En cada pulso de la pelota, mira hacia dónde quiere moverse y decide si ese paso es:

* un **rebote** en la paleta del jugador 1 o del jugador 2 (`HIT_J1`, `HIT_J2`),
* un **gol** de alguno de los dos (`GOAL_J1`, `GOAL_J2`),
* o un movimiento normal (todas las salidas en 0).

Es un módulo **totalmente combinacional**: no tiene reloj ni registros. Recibe posiciones y responde en el mismo ciclo.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `GAME_EN`, `TICK_BALL` | entrada | Solo se evalúa cuando el juego está activo y hay pulso de pelota |
| `XB[3:0]` | entrada | Columna actual de la pelota |
| `X_CAND[3:0]`, `Y_CAND[2:0]` | entrada | Casilla a la que la pelota quiere ir, desde [`pelota`](pelota.md) |
| `DX` | entrada | Dirección horizontal de la pelota |
| `YP1_EFF[2:0]`, `YP2_EFF[2:0]` | entrada | Posición de las paletas después de este ciclo, desde [`paletas`](paletas.md) |
| `HIT_J1`, `HIT_J2` | salida | La pelota rebota en la paleta del jugador 1 o 2 |
| `GOAL_J1`, `GOAL_J2` | salida | Anota el jugador 1 o el jugador 2 |

## Cómo funciona

### 1. Permiso

```verilog
assign AB = GAME_EN && TICK_BALL;
```

Fuera de los ciclos de pulso de pelota todas las salidas valen 0.

### 2. ¿La pelota llega a una columna de paleta?

```verilog
assign EL = !DX && (XB == 1)  && (X_CAND == 0);    // borde izquierdo
assign ER =  DX && (XB == 14) && (X_CAND == 15);   // borde derecho
```

`EL` vale 1 cuando la pelota va hacia la izquierda, está en la columna 1 y el siguiente paso sería la columna 0, la de la paleta del jugador 1. `ER` es lo mismo del lado derecho: de la columna 14 a la 15, la de la paleta del jugador 2. Revisamos a la vez la dirección, la columna actual y la columna candidata, tal como quedó en la ecuación de F2.

### 3. ¿La paleta está ahí?

```verilog
assign P1 = (Y_CAND == YP1_EFF) || (Y_CAND == YP1_EFF + 1);
assign P2 = (Y_CAND == YP2_EFF) || (Y_CAND == YP2_EFF + 1);
```

Cada paleta ocupa dos filas, `YP` y `YP + 1`. Comparamos la **fila a la que va** la pelota (`Y_CAND`) con esas dos filas.

### 4. Resultado

```verilog
assign HIT_J1  = AB && EL &&  P1;   // llega a la izquierda y la paleta 1 está
assign HIT_J2  = AB && ER &&  P2;   // llega a la derecha y la paleta 2 está
assign GOAL_J1 = AB && ER && !P2;   // llega a la derecha y la paleta 2 NO está
assign GOAL_J2 = AB && EL && !P1;   // llega a la izquierda y la paleta 1 NO está
```

Hay que fijarse en el cruce: si la pelota se le escapa al jugador 2 (borde derecho), el gol es del **jugador 1**, y al revés.

| Borde | ¿Paleta en la fila? | Resultado |
|-------|---------------------|-----------|
| Izquierdo (columna 0) | sí | `HIT_J1` |
| Izquierdo (columna 0) | no | `GOAL_J2` |
| Derecho (columna 15) | sí | `HIT_J2` |
| Derecho (columna 15) | no | `GOAL_J1` |
| Ninguno | — | nada |

## Por qué lo hicimos así

* **Comparar con la casilla candidata, no con la actual.** La decisión se toma antes de mover la pelota. Así nunca existe un ciclo en el que la pelota "esté dentro" de la paleta, y la pelota nunca se dibuja en las columnas 0 y 15.
* **Usar la fila candidata `Y_CAND`.** Como la pelota se mueve en diagonal, la fila cambia en el mismo paso. Lo que importa es si la paleta estará en la fila a la que llega la pelota, no en la fila de donde sale. `Y_CAND` ya incluye el rebote en el borde de arriba o de abajo.
* **Usar la posición efectiva de la paleta.** Si la paleta se mueve en el mismo ciclo, la colisión se evalúa contra su nueva posición. Lo explicamos en [`paletas`](paletas.md).
* **Combinacional.** El resultado tiene que estar listo en el mismo ciclo del pulso, para que [`pelota`](pelota.md) decida si avanza o rebota y [`control_juego`](control_juego.md) si pasa a PUNTO, todo en el mismo flanco.
* **Señales separadas por jugador.** El puntaje necesita saber quién anotó, y la pelota solo si hubo rebote o gol. El núcleo las junta con una OR para la pelota.

## Cómo lo probamos

* `tb_colisiones` (F3): barrido de combinaciones de posiciones, direcciones y paletas contra un modelo de referencia (87 823 comprobaciones).
* `tb_colisiones_puntaje_f5`: 12 pruebas de colisiones conectadas con la FSM y el puntaje.
* `tb_pelota_goles_diagonal_f5`: 14 pruebas de rebotes y goles con el movimiento diagonal.

## Historia

Escrito en F3. No hizo falta cambiarlo en F5 con el movimiento diagonal, porque ya usaba `Y_CAND` para comparar la fila.
