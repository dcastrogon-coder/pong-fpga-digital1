# `imagen.v`: qué LED se prenden en cada fila

[Volver al índice](README.md) · Código: [`rtl/imagen.v`](../rtl/imagen.v)

## Qué hace

Convierte la foto de 13 bits de [`captura_imagen`](captura_imagen.md) en los LED que hay que prender. El transmisor le pregunta por una fila (`ROW_IDX`, de 0 a 7) y el módulo responde con dos bytes:

* **`DATA_A`**: los 8 LED de esa fila en la matriz A (columnas 0 a 7, lado del jugador 1).
* **`DATA_B`**: los 8 LED de esa fila en la matriz B (columnas 8 a 15, lado del jugador 2).

Un bit en 1 es un LED prendido. Es un módulo **combinacional**: no guarda nada, solo calcula.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `SNAPSHOT[12:0]` | entrada | Foto de las posiciones |
| `ROW_IDX[2:0]` | entrada | Fila que se está dibujando, desde [`transmisor_max7219`](transmisor_max7219.md) |
| `DATA_A[7:0]` | salida | LED de la fila en la matriz A |
| `DATA_B[7:0]` | salida | LED de la fila en la matriz B |

## Cómo funciona

### 1. Separar la foto

```verilog
assign YP1_S = SNAPSHOT[12:10];
assign YP2_S = SNAPSHOT[9:7];
assign XB_S  = SNAPSHOT[6:3];
assign YB_S  = SNAPSHOT[2:0];
```

### 2. ¿Hay algo en esta fila?

```verilog
assign P1_ROW   = (ROW_IDX == YP1_S) || ({1'b0, ROW_IDX} == {1'b0, YP1_S} + 4'd1);
assign P2_ROW   = (ROW_IDX == YP2_S) || ({1'b0, ROW_IDX} == {1'b0, YP2_S} + 4'd1);
assign BALL_ROW = (ROW_IDX == YB_S);
```

Una paleta aparece en la fila si la fila es `YP` o `YP + 1`. La suma `YP + 1` la hacemos con 4 bits: con 3 bits, si `YP` fuera 7, la suma daría 0 y la paleta aparecería también en la fila de arriba del todo. En el juego normal `YP` nunca llega a 7, pero así el módulo es correcto para cualquier entrada.

### 3. Armar los bytes

```verilog
DATA_A = 0;  DATA_B = 0;
if (P1_ROW)   DATA_A[0] = 1;                 // paleta J1, columna 0
if (P2_ROW)   DATA_B[7] = 1;                 // paleta J2, columna 15
if (BALL_ROW)
    if (XB_S <= 7) DATA_A[XB_S]     = 1;     // pelota en columnas 0-7
    else           DATA_B[XB_S - 8] = 1;     // pelota en columnas 8-15
```

| Columna del tablero | Matriz | Bit del byte |
|---------------------|--------|--------------|
| 0 (paleta J1) | A | `DATA_A[0]` |
| 1 a 7 | A | `DATA_A[1]` a `DATA_A[7]` |
| 8 a 14 | B | `DATA_B[0]` a `DATA_B[6]` |
| 15 (paleta J2) | B | `DATA_B[7]` |

### Ejemplo: estado inicial, fila 3

Paletas en la fila 3 (`YP1 = YP2 = 3`), pelota en (7, 3):

```
DATA_A = 1000_0001   bit 7: pelota (columna 7) · bit 0: paleta J1 (columna 0)
DATA_B = 1000_0000   bit 7: paleta J2 (columna 15)
```

En la fila 4 solo están las paletas: `DATA_A = 0000_0001`, `DATA_B = 1000_0000`. En las demás filas los dos bytes valen 0.

## Por qué lo hicimos así

* **Calcular fila por fila en vez de guardar la imagen.** El transmisor manda una fila a la vez, así que solo necesitamos dos bytes en cada momento. Guardar los 128 LED ocuparía muchos más registros.
* **Orientación corregida en F4.** En F3 habíamos supuesto que la columna izquierda de cada matriz era el bit 7. Al conectar las matrices en F4, la imagen salía al revés en horizontal, así que cambiamos la asignación para que la columna 0 sea el bit 0. Esa corrección está marcada en el código con el comentario "Correccion de orientacion horizontal". La corrección vertical está en [`transmisor_max7219`](transmisor_max7219.md).

## Cómo lo probamos

`tb_imagen` (F3, actualizado en F4 con la nueva orientación) recorre combinaciones de paletas, pelota y filas contra un modelo de referencia: 65 546 comprobaciones. La foto de F4 (`fases/F4_interfaz_visual/F4_Prueba_Visual_MAX7219.png`) muestra el estado inicial dibujado correctamente en las dos matrices.

## Historia

Escrito en F3. En F4 corregimos la orientación horizontal.
