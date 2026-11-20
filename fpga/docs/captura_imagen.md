# `captura_imagen.v`: instantánea de 13 bits

[Volver al índice](README.md) · Código: [`rtl/captura_imagen.v`](../rtl/captura_imagen.v)

## Qué hace

Cuando el transmisor va a empezar a dibujar un cuadro nuevo, este módulo toma una "foto" de las posiciones de las paletas y de la pelota y la guarda en un registro de 13 bits (`SNAPSHOT`). Las 8 filas de ese cuadro se dibujan a partir de esa foto, aunque el juego siga avanzando mientras tanto.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `CAPTURE_REQ` | entrada | Pedido de foto, desde [`transmisor_max7219`](transmisor_max7219.md) |
| `YP1[2:0]`, `YP2[2:0]` | entrada | Posición de las paletas |
| `XB[3:0]`, `YB[2:0]` | entrada | Posición de la pelota |
| `SNAPSHOT[12:0]` | salida | Foto guardada |
| `FRAME_READY` | salida | Pulso de un ciclo: la foto ya está lista |

## Formato de la foto

| Bits | Contenido | Ancho |
|------|-----------|-------|
| `[12:10]` | `YP1`: fila superior de la paleta del jugador 1 | 3 |
| `[9:7]` | `YP2`: fila superior de la paleta del jugador 2 | 3 |
| `[6:3]` | `XB`: columna de la pelota | 4 |
| `[2:0]` | `YB`: fila de la pelota | 3 |

Con 13 bits alcanza para describir todo lo que se ve en el tablero. Las columnas de las paletas no se guardan porque siempre son la 0 y la 15.

## Cómo funciona

```verilog
if (INIT_GLOBAL) begin
    SNAPSHOT    <= {3'd3, 3'd3, 4'd7, 3'd3};   // posiciones iniciales
    FRAME_READY <= 0;
end
else if (CAPTURE_REQ) begin
    SNAPSHOT    <= {YP1, YP2, XB, YB};          // tomar la foto
    FRAME_READY <= 1;
end
else
    FRAME_READY <= 0;                           // la foto se conserva
```

1. El transmisor activa `CAPTURE_REQ` durante un ciclo, justo antes de empezar un cuadro.
2. En el siguiente flanco se guardan las cuatro posiciones y `FRAME_READY` sube.
3. El transmisor ve `FRAME_READY` y empieza a mandar las filas.
4. Mientras tanto, `SNAPSHOT` no cambia hasta el próximo pedido.

Después del reset, la foto arranca con las mismas posiciones iniciales del juego (paletas en la fila 3, pelota en (7, 3)), así la primera imagen es correcta aunque todavía no se haya tomado ninguna.

## Por qué lo hicimos así

* **Evitar imágenes "rotas".** Mandar un cuadro completo a las matrices toma unos 0,27 ms (8 filas de 32 bits cada una). Si el transmisor leyera las posiciones en vivo y justo en medio del cuadro la pelota avanzara, las filas de arriba mostrarían la pelota en un lugar y las de abajo en otro: podría verse en dos casillas a la vez o desaparecer. Con la foto, todas las filas de un cuadro muestran el mismo instante.
* **El transmisor manda.** La foto se toma cuando el transmisor la pide, no cuando el juego cambia. Así el juego y la imagen trabajan cada uno a su ritmo sin interferirse.
* **Solo 13 flip-flops.** Guardar las posiciones es mucho más barato que guardar la imagen completa (128 LED).

## Cómo lo probamos

* `tb_captura_imagen` (F3): 13 pruebas. Valor inicial, captura con el pedido, que la foto se conserve sin pedido, `FRAME_READY` de un solo ciclo y prioridad del reset.
* `tb_transmisor_max7219` y `tb_pong_max7219_integrado` revisan que el cuadro enviado corresponde a la foto tomada al inicio, aunque las posiciones cambien durante el envío.

## Historia

Escrito en F3. No cambió en las fases siguientes.
