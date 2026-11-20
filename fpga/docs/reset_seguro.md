# `reset_seguro.v`: arranque y RESET

[Volver al índice](README.md) · Código: [`rtl/reset_seguro.v`](../rtl/reset_seguro.v)

## Qué hace

Genera las dos fuentes "normales" del reset del sistema:

* **`POR_REQ`** (*power-on reset*): un pulso durante los primeros 4 ciclos de reloj después de configurar la FPGA, para que todo arranque en un estado conocido.
* **`RESET_CLEAN`**: la versión limpia del pulsador RESET. Se activa **en el instante** en que se presiona y se libera **20 ms después** de soltarlo, una vez que la señal dejó de rebotar.

Las dos salidas se combinan en [`pong_f5_core`](pong_f5_core.md) para formar `INIT_GLOBAL`.

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `NDB` | 1 000 000 | Ciclos que el RESET debe estar suelto sin interrupción para liberarse: 20 ms a 50 MHz |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS` | entrada | Reloj de 50 MHz |
| `RESET_RAW_ACTIVE` | entrada | 1 = RESET presionado, 0 = suelto. Viene directo del pin (negado en el top) |
| `POR_REQ` | salida | 1 durante los primeros 4 ciclos |
| `RESET_CLEAN` | salida | 1 mientras el sistema debe estar en reset |

## Cómo funciona

### 1. Arranque (`BOOT`)

```verilog
reg [3:0] BOOT = 4'b0000;

always @(posedge CLK_SYS)
    BOOT <= {BOOT[2:0], 1'b1};

assign POR_REQ = ~BOOT[3];
```

`BOOT` es un registro de desplazamiento que arranca en `0000` (el valor inicial se lo da la configuración de la FPGA) y en cada ciclo le entra un 1 por la derecha: `0001`, `0011`, `0111`, `1111`. Mientras el bit de más a la izquierda sea 0, `POR_REQ` vale 1. A partir del cuarto ciclo queda en 0 para siempre.

### 2. Afirmación inmediata del RESET

El registro principal es `R_HOLD`, que es directamente la salida `RESET_CLEAN`. Arranca en 1 (el sistema empieza en reset) y su `always` es sensible al flanco de reloj **y** al flanco de subida de `RESET_RAW_ACTIVE`:

```verilog
always @(posedge CLK_SYS or posedge RESET_RAW_ACTIVE) begin
    if (RESET_RAW_ACTIVE) begin
        R_HOLD <= 1'b1;
        ...
```

Eso quiere decir que apenas se presiona el botón, `R_HOLD` se pone en 1 sin esperar al reloj. Es lo que llamamos **afirmación asíncrona**.

### 3. Liberación sincronizada y filtrada

Soltar el reset es más delicado: si todos los registros salen del reset en ciclos distintos, el sistema puede arrancar en un estado incoherente. Por eso la liberación pasa por:

1. **Dos flip-flops de sincronización** (`RELEASE_SYNC1`, `RELEASE_SYNC2`). Mientras el botón está presionado se mantienen en 0; cuando se suelta, el 1 tarda dos ciclos en atravesarlos.
2. **Un contador de estabilidad** (`RELEASE_COUNT`, 20 bits). Cuenta ciclos seguidos con el botón suelto. Si el botón rebota y vuelve a 1 aunque sea un instante, la afirmación asíncrona pone el contador en 0 y hay que empezar de nuevo.
3. **Liberación.** Cuando el contador llega a `NDB − 1` (1 000 000 ciclos seguidos, 20 ms), `R_HOLD` pasa a 0 en un flanco de reloj.

## Por qué lo hicimos así

* **Asíncrono al entrar, síncrono al salir.** Es el esquema clásico de reset seguro: entrar al reset es urgente y no importa en qué ciclo pase, porque todo va a quedar en su valor inicial. Salir sí tiene que pasar en un flanco limpio, igual para todos los registros.
* **El antirrebote solo al soltar.** Un pulsador mecánico rebota unos milisegundos. Al presionar, el primer contacto basta para entrar en reset; los rebotes siguientes solo vuelven a poner el contador en cero. Al soltar, esperamos 20 ms seguidos sin rebote antes de liberar.
* **`R_HOLD` arranca en 1.** Junto con `POR_REQ`, asegura que el sistema empiece en reset aunque el pulsador no se haya tocado.
* **Uso dentro del top.** En [`pong_f6_integracion_top`](pong_f6_integracion_top.md), la entrada de este módulo también se activa mientras `HCT_EN = 0`. Así el juego se mantiene en reset hasta que los búferes estén habilitados.
* **Restricción de tiempos.** En [`pong_f3.sdc`](proyecto_quartus.md) marcamos el camino desde el pin `RESET_N` como *false path*, porque es asíncrono y no tiene sentido que TimeQuest lo analice como una señal síncrona.

## Cómo lo probamos

* `tb_reset_seguro` (F3): 47 comprobaciones. Arranque, afirmación inmediata, rebotes al soltar, liberación justo en el ciclo esperado y presiones durante la cuenta.
* `tb_reset_seguro_f5`: 10 pruebas con el antirrebote reducido, en las condiciones del montaje de F5.
* `tb_puntaje_reset_f5` y `tb_inicio_reset_integrado_f5` revisan que, al presionar RESET a mitad de una partida, el marcador y las posiciones vuelvan a su valor inicial.

## Historia

Escrito en F3 a partir de las ecuaciones de reset de F2. No cambió en las fases siguientes.
