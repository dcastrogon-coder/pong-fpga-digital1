# `boton_evento.v`: START y PAUSE

[Volver al índice](README.md) · Código: [`rtl/boton_evento.v`](../rtl/boton_evento.v)

## Qué hace

Convierte una pulsación de un botón mecánico en **un solo pulso de un ciclo de reloj** (`PRESS_EVENT`), sin importar cuánto rebote el contacto ni cuánto tiempo se mantenga presionado. Lo usamos dos veces en [`pong_f5_core`](pong_f5_core.md): una instancia para START y otra para PAUSE.

Necesitamos un pulso y no un nivel porque la máquina de estados reacciona a eventos. Si PAUSE entrara como nivel, mantenerlo presionado haría que el juego entrara y saliera de pausa en cada ciclo, 50 millones de veces por segundo.

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `NDB` | 1 000 000 | Ciclos que la entrada debe estar estable para aceptar un cambio: 20 ms |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS` | entrada | Reloj de 50 MHz |
| `INIT_GLOBAL` | entrada | Reset del sistema |
| `PRESSED_RAW` | entrada | 1 = presionado, 0 = suelto (sin filtrar, viene del pin) |
| `PRESSED_DB` | salida | Nivel ya filtrado del botón |
| `PRESS_EVENT` | salida | Pulso de un ciclo cuando se confirma una pulsación |

## Cómo funciona

### 1. Sincronizador de dos flip-flops

```verilog
SYNC_1 <= PRESSED_RAW;
SYNC_2 <= SYNC_1;
```

El botón cambia en cualquier momento, sin respetar el reloj. Si un flip-flop captura la señal justo cuando cambia, puede quedar un instante en un valor intermedio (metaestabilidad). Con dos flip-flops en fila le damos un ciclo completo para estabilizarse antes de que el resto del circuito la use.

### 2. Contador de estabilidad

```verilog
assign DIFF        = SYNC_2 ^ PRESSED_DB;
assign TERMINAL_DB = (CDB == (NDB - 20'd1));
```

* `DIFF` vale 1 cuando la entrada sincronizada es distinta del último valor confirmado, es decir, cuando hay un cambio pendiente.
* Mientras `DIFF = 1`, el contador `CDB` sube un paso por ciclo.
* Si la entrada vuelve al valor confirmado antes de tiempo (un rebote), `DIFF = 0` y el contador vuelve a 0.
* Si `DIFF` se mantiene en 1 durante `NDB` ciclos seguidos, el cambio es real: se actualiza `PRESSED_DB`.

### 3. Generación del evento

```verilog
else if (TERMINAL_DB) begin
    PRESSED_DB <= SYNC_2;
    CDB <= 20'd0;
    if (SYNC_2)
        PRESS_EVENT <= 1'b1;
end
```

Cuando se confirma un cambio, si el nuevo valor es "presionado" se genera el pulso. Al soltar el botón también se confirma el cambio (después de otros 20 ms), pero sin pulso. En todos los demás ciclos `PRESS_EVENT` vuelve a 0.

En resumen: el pulso sale unos 20 ms después de presionar, una sola vez, y no vuelve a salir hasta que el botón se suelte y se presione otra vez.

## Por qué lo hicimos así

* **Filtro por contador y no por muestreo lento.** Contar ciclos seguidos de estabilidad rechaza cualquier rebote más corto que 20 ms, y la respuesta sigue siendo rápida para una persona.
* **`INIT_GLOBAL` cancela todo.** Si alguien está presionando START justo cuando hay un reset, la pulsación pendiente se descarta. Así el juego no arranca solo después de un reset.
* **`PRESSED_DB` aunque no se use.** En el núcleo no lo conectamos, pero sirve para verificar el filtro en el banco de prueba.

## Cómo lo probamos

`tb_boton_evento` (F3) compara el módulo contra un modelo de referencia y revisa: inicialización, primera pulsación con un solo evento, rebotes rechazados, rebote sin falsa liberación, que soltar no genere evento, que mantenerlo presionado no repita el evento, una segunda pulsación con su segundo evento, y la prioridad de `INIT_GLOBAL`, incluida la cancelación de una pulsación pendiente.

## Historia

Escrito en F3. No cambió en las fases siguientes.
