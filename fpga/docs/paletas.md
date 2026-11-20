# `paletas.v`: movimiento de las paletas

[Volver al índice](README.md) · Código: [`rtl/paletas.v`](../rtl/paletas.v)

## Qué hace

Guarda y actualiza la posición vertical de las dos paletas. Cada paleta mide 2 LED de alto y se mueve en su columna fija: la del jugador 1 en la columna 0 y la del jugador 2 en la columna 15.

Entrega dos versiones de la posición:

* **`YP1`, `YP2`**: la posición registrada, la que se ve en las matrices.
* **`YP1_EFF`, `YP2_EFF`**: la posición que la paleta va a tener después de este ciclo. La usa [`colisiones`](colisiones.md).

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `CENTER_EN` | entrada | Volver al centro después de un punto |
| `CAPTURE_GOAL` | entrada | Ciclo en que se registra un gol: congelar |
| `GAME_EN` | entrada | Permiso para avanzar |
| `TICK_PADDLE` | entrada | Pulso de 250 ms |
| `CMD_J1[1:0]`, `CMD_J2[1:0]` | entrada | `01` subir, `10` bajar, `00` quieta, desde [`supervisor_cableado`](supervisor_cableado.md) |
| `YP1[2:0]`, `YP2[2:0]` | salida | Fila superior de cada paleta (0 a 6) |
| `YP1_EFF[2:0]`, `YP2_EFF[2:0]` | salida | Posición siguiente, para las colisiones |

## Cómo se representa una paleta

`YP` es la fila del LED de **arriba** de la paleta; el de abajo está en `YP + 1`. El tablero tiene filas de 0 a 7, así que `YP` solo puede ir de 0 a 6: si valiera 7, el segundo LED quedaría fuera del tablero. Con 3 bits nos alcanza.

```
fila 0  .              YP = 0: paleta en filas 0 y 1
fila 1  .
fila 2  .
fila 3  #   <- YP = 3 (posición inicial)
fila 4  #
fila 5  .
fila 6  .              YP = 6: paleta en filas 6 y 7
fila 7  .
```

## Cómo funciona

### Posición siguiente (combinacional)

```verilog
assign EP = GAME_EN && TICK_PADDLE;

if (EP) case (CMD_J1)
    2'b01: if (YP1 > 0 && YP1 <= 6) next_yp1 = YP1 - 1;   // subir
    2'b10: if (YP1 < 6)             next_yp1 = YP1 + 1;   // bajar
    default:                        next_yp1 = YP1;       // quieta
endcase
```

* La paleta solo puede moverse en los ciclos en que hay pulso de paletas y el juego está activo (`EP`).
* "Subir" es restar 1 a la fila y "bajar" es sumar 1.
* En los bordes el movimiento se ignora: en la fila 0 no se puede subir más y en la fila 6 no se puede bajar más. Así la paleta nunca se sale del tablero.

El jugador 2 tiene exactamente la misma lógica con `CMD_J2` y `YP2`.

### Registro (secuencial)

```verilog
if (INIT_GLOBAL)       YP <= 3;          // inicio
else if (CENTER_EN)    YP <= 3;          // después de un punto
else if (CAPTURE_GOAL) YP <= YP;         // congelar en el gol
else                   YP <= next_yp;    // mover si toca
```

Las dos paletas arrancan en la fila 3, es decir, ocupan las filas 3 y 4: el centro del tablero.

## Por qué lo hicimos así

* **La posición "efectiva" para las colisiones.** Cada segundo coinciden el pulso de la pelota (200 ms) y el de las paletas (250 ms). Si en ese ciclo la colisión se calculara con la posición vieja de la paleta, el jugador podría ver su paleta delante de la pelota y aun así recibir un gol. Con `YP_EFF`, la colisión se evalúa contra el lugar donde la paleta va a quedar, que es lo que el jugador ve en el siguiente cuadro.
* **Congelar en el gol.** En el ciclo en que se detecta un gol, las paletas no se mueven. La jugada queda exactamente como se evaluó y la imagen final muestra por qué hubo gol.
* **Centrar después de cada punto.** Los dos jugadores empiezan cada saque en igualdad de condiciones.
* **Límites en la lógica de la paleta.** Preferimos que el bloque nunca produzca un valor inválido en vez de corregirlo después. De todos modos, si `YP` llegara a 7 por algún fallo, [`supervisor_fallos`](supervisor_fallos.md) lo detecta.

## Cómo lo probamos

* `tb_paletas` (F3): 14 pruebas. Inicialización, movimiento independiente, límites 0 y 6, pulsación sostenida, juego deshabilitado, bloqueo en el gol, posición efectiva y prioridad del reset.
* `tb_paletas_cableadas_f5`: 14 pruebas con los mandos reales pasando por el supervisor y la FSM.
* `tb_hct_controles_cableados_f5`: comprueba que los movimientos de las dos paletas aparecen en las tramas que salen hacia las matrices.

## Historia

Escrito en F3. No cambió en las fases siguientes.
