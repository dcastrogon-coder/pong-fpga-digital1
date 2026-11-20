# `supervisor_fallos.v`: recuperación ante valores inválidos

[Volver al índice](README.md) · Código: [`rtl/supervisor_fallos.v`](../rtl/supervisor_fallos.v)

## Qué hace

Vigila los registros más importantes del juego y, si alguno toma un valor que según el diseño no puede existir, activa `FAULT_RECOVER`. Esa señal entra a `INIT_GLOBAL` en [`pong_f5_core`](pong_f5_core.md) y reinicia todo el sistema, como si se hubiera presionado RESET.

Es un módulo **combinacional**: solo compara valores, no guarda nada.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `STATE[2:0]` | entrada | Estado de [`control_juego`](control_juego.md) |
| `SCORE_J1[3:0]`, `SCORE_J2[3:0]` | entrada | Puntajes, desde [`puntaje`](puntaje.md) |
| `YP1[2:0]`, `YP2[2:0]` | entrada | Paletas, desde [`paletas`](paletas.md) |
| `XB[3:0]` | entrada | Columna de la pelota, desde [`pelota`](pelota.md) |
| `FAULT_TX` | entrada | Alarma del [`transmisor_max7219`](transmisor_max7219.md) |
| `INVALID_FSM`, `INVALID_BCD_J1`, `INVALID_BCD_J2`, `INVALID_YP1`, `INVALID_YP2`, `INVALID_XB` | salida | Indicador de cada tipo de fallo |
| `FAULT_RECOVER` | salida | 1 si hay cualquier fallo |

## Qué se considera inválido

| Señal | Condición | Por qué es imposible | Ecuación de F2 |
|-------|-----------|----------------------|----------------|
| `INVALID_FSM` | `STATE` = 110 o 111 | Solo usamos 6 de los 8 códigos | (75) |
| `INVALID_BCD_J1/J2` | puntaje entre 10 y 15 | El marcador satura en 9 | (76) |
| `INVALID_YP1/YP2` | `YP` = 7 | La paleta ocuparía las filas 7 y 8, y la 8 no existe | (77) |
| `INVALID_XB` | `XB` = 0 o 15 | La pelota nunca entra a las columnas de las paletas | (78) |
| `FAULT_TX` | estado o contador inválido en el transmisor | Ver [`transmisor_max7219`](transmisor_max7219.md) | — |

Las ecuaciones están simplificadas a nivel de bits. Por ejemplo, un número de 4 bits está entre 10 y 15 si el bit 3 vale 1 y además el bit 2 o el bit 1 valen 1:

```verilog
assign INVALID_BCD_J1 = SCORE_J1[3] && (SCORE_J1[2] || SCORE_J1[1]);
assign INVALID_FSM    = STATE[2] && STATE[1];
```

Al final se juntan todas con una OR:

```verilog
assign FAULT_RECOVER = INVALID_FSM || INVALID_BCD_J1 || INVALID_BCD_J2 ||
                       INVALID_YP1 || INVALID_YP2 || INVALID_XB || FAULT_TX;
```

## ¿Cómo podría aparecer un valor así?

Con el diseño funcionando bien, nunca. Pero un registro puede cambiar por causas externas: ruido en la alimentación, una descarga electrostática al tocar los pulsadores o un pico al conectar o desconectar los cables. Un sistema que queda en un estado imposible puede bloquearse para siempre (por ejemplo, la FSM en un estado sin salidas). Con este supervisor, el peor caso es que la partida se reinicie.

## Por qué lo hicimos así

* **Reiniciar todo y no solo el registro dañado.** Si un registro tomó un valor imposible, no sabemos si los demás siguen siendo correctos. Volver al estado inicial es la única opción segura.
* **Mirar solo registros.** Todas las entradas salen de flip-flops, así que `FAULT_RECOVER` no tiene pulsos falsos por cambios intermedios de lógica combinacional. Y como el reset se aplica en el siguiente flanco de reloj, no se forma un lazo combinacional.
* **Indicadores separados.** En el núcleo solo usamos `FAULT_RECOVER`, pero las seis señales individuales nos sirvieron en simulación para saber exactamente qué fallo se detectó.

## Cómo lo probamos

* `tb_supervisor_fallos` (F3): recorre todos los valores posibles de cada entrada y comprueba cada indicador (363 comprobaciones).
* `tb_pong_recuperacion_fallos`: en el sistema completo, mete valores inválidos a la fuerza en los registros (con `force`/`release` del simulador) y comprueba que el sistema detecta el fallo, se reinicia y vuelve a funcionar (11 comprobaciones).

## Historia

Escrito en F3 a partir de las ecuaciones 75 a 78 de F2. No cambió en las fases siguientes.
