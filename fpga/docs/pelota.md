# `pelota.v`: movimiento diagonal de la pelota

[Volver al índice](README.md) · Código: [`rtl/pelota.v`](../rtl/pelota.v)

## Qué hace

Guarda la posición y la dirección de la pelota y la mueve una casilla en diagonal en cada pulso de 200 ms. También calcula hacia dónde **intentaría** moverse (`X_CAND`, `Y_CAND`) para que [`colisiones`](colisiones.md) decida si ese paso es un rebote en una paleta, un gol o un movimiento normal.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `CENTER_EN` | entrada | Llevar la pelota al centro para un nuevo saque |
| `GAME_EN`, `TICK_BALL` | entrada | Permiso y pulso de 200 ms |
| `SERVE_DIR` | entrada | Dirección horizontal del próximo saque |
| `HIT` | entrada | La pelota toca una paleta en este paso |
| `GOAL` | entrada | La pelota pasa a una paleta en este paso |
| `XB[3:0]` | salida | Columna (0 a 15) |
| `YB[2:0]` | salida | Fila (0 a 7) |
| `DX` | salida | 1 = hacia la derecha, 0 = hacia la izquierda |
| `DY` | salida | 1 = hacia abajo (fila mayor), 0 = hacia arriba |
| `PHASE` | salida | Bit que alterna en cada paso; ya no se usa (ver más abajo) |
| `X_CAND[3:0]`, `Y_CAND[2:0]` | salida | Siguiente casilla candidata |
| `DY_CAND` | salida | Dirección vertical después de rebotar en un borde |

## Cómo funciona

### 1. Siguiente columna candidata

```verilog
assign X_CAND = DX ? (XB + 1) : (XB - 1);
```

### 2. Rebote en el borde de arriba y de abajo

```verilog
assign REFLECT_Y = ((YB == 0) && !DY) || ((YB == 7) && DY);
assign DY_CAND   = DY ^ REFLECT_Y;
assign Y_CAND    = DY_CAND ? (YB + 1) : (YB - 1);
```

Si la pelota está en la fila 0 y va hacia arriba, o en la fila 7 y va hacia abajo, se invierte la dirección vertical **antes** de calcular el paso. Así la pelota rebota en el borde sin quedarse pegada a él: desde la fila 0 pasa directamente a la fila 1.

### 3. Registros

```verilog
if (INIT_GLOBAL)       { XB=7, YB=3, DX=1, DY=1 }
else if (CENTER_EN)    { XB=7, YB=3, DX=SERVE_DIR, DY=1 }
else if (GAME_EN && TICK_BALL) begin
    if (GOAL)          nada cambia
    else begin
        if (HIT)       { XB se queda, DX se invierte }   // rebote en paleta
        else           { XB = X_CAND }                    // paso normal
        YB = Y_CAND; DY = DY_CAND;                       // siempre avanza en Y
    end
end
```

| Situación | Columna | Dirección horizontal | Fila |
|-----------|---------|----------------------|------|
| Paso normal | avanza | igual | avanza |
| Rebote en paleta (`HIT`) | se queda | se invierte | avanza |
| Gol (`GOAL`) | se queda | igual | se queda |
| Sin pulso | se queda | igual | se queda |

### Ejemplo de recorrido

Desde el saque inicial, la pelota en (7, 3) baja en diagonal hacia la derecha: (8, 4), (9, 5), (10, 6), (11, 7). Ahí toca el borde de abajo y en el siguiente paso sube: (12, 6), (13, 5)... Al llegar a la columna 14 intenta entrar a la 15, que es la columna de la paleta del jugador 2. Si la paleta está en la fila candidata, hay rebote; si no, es gol del jugador 1.

## Por qué lo hicimos así

* **Movimiento diagonal desde F5.** En F3 la pelota avanzaba en X cada 200 ms y en Y cada 400 ms, controlada por el bit `PHASE`, lo que daba una trayectoria más plana. En F5 lo cambiamos a una diagonal de 45°: X e Y avanzan juntas en cada pulso. La trayectoria queda más regular y fácil de anticipar, y la lógica vertical se simplifica porque ya no depende de `PHASE`.
* **`PHASE` se conserva.** Lo dejamos como salida para no cambiar la interfaz del módulo, que otros bloques y bancos de prueba ya usaban. Hoy solo alterna y no afecta al movimiento.
* **La pelota nunca entra a las columnas 0 y 15.** Esas columnas son de las paletas. El rebote o el gol se deciden justo cuando la pelota intenta entrar (desde la 1 o la 14). Por eso, durante el juego, `XB` siempre está entre 1 y 14, y [`supervisor_fallos`](supervisor_fallos.md) usa eso para detectar errores.
* **En el gol no se mueve.** La pelota queda en la última casilla antes de la paleta, mostrando por dónde pasó, hasta que la FSM la centra.
* **Saque desde el centro.** La columna 7 y la fila 3 son el punto de partida. La dirección horizontal la da `SERVE_DIR`, que alterna en cada gol, y la vertical siempre empieza hacia abajo.

## Cómo lo probamos

* `tb_pelota_diagonal_f5`: 12 verificaciones del recorrido diagonal, incluidos los rebotes en los bordes.
* `tb_pelota_goles_diagonal_f5`: 14 pruebas con pelota, colisiones, FSM y puntaje juntos: rebotes en las paletas y goles con el movimiento diagonal.
* `tb_pong_goles_victoria`: goles y victoria en el sistema completo.
* Los bancos que esperaban el movimiento viejo (`tb_pelota`, `tb_pelota_goles_f5`...) los guardamos en `tb/anteriores_al_movimiento_diagonal/`. Ver [bancos de prueba](bancos_de_prueba.md).

## Historia

Escrito en F3 con el movimiento de 200/400 ms. En F5 lo cambiamos a movimiento diagonal: X e Y avanzan en cada pulso.
