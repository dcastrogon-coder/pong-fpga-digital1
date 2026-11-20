# `supervisor_rf.v`: supervisión de los enlaces inalámbricos (F3)

[Volver al índice](README.md) · Código: [`rtl/supervisor_rf.v`](../rtl/supervisor_rf.v)

## Qué es

Es el supervisor que usábamos cuando los mandos iban a ser inalámbricos. Recibe, por cada jugador, un comando de 2 bits y un pulso que indica que llegó una trama válida, y decide si el enlace sigue vivo. En el diseño final lo reemplazó [`supervisor_cableado`](supervisor_cableado.md), que tiene las mismas salidas.

Lo dejamos en el repositorio porque lo usa [`pong_top`](pong_top.md) y lo siguen verificando sus bancos de prueba.

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `N_RF` | 25 000 000 | Tiempo máximo sin tramas antes de dar el enlace por perdido: 500 ms |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `CMD_RX1[1:0]`, `FRAME_1_VALID` | entrada | Comando y aviso de trama válida del jugador 1 |
| `CMD_RX2[1:0]`, `FRAME_2_VALID` | entrada | Lo mismo para el jugador 2 |
| `CMD_J1[1:0]`, `CMD_J2[1:0]` | salida | Último comando recibido de cada jugador |
| `RF1_OK_EFF`, `RF2_OK_EFF` | salida | Enlace de cada jugador vigente |
| `RF_OK_EFF` | salida | Los dos enlaces vigentes |

## Cómo funciona

Cada jugador tiene un contador de "edad" (`AGE1`, `AGE2`, de 25 bits) que mide cuánto tiempo pasó desde la última trama válida, y un bit de validez (`RF1`, `RF2`):

```verilog
if (INIT_GLOBAL)          { AGE1 = 0, RF1 = 0, CMD_J1 = 00 }      // arranca sin enlace
else if (FRAME_1_VALID)   { AGE1 = 0, RF1 = 1, CMD_J1 = CMD_RX1 } // llegó trama
else if (AGE1 == TC_RF)   { RF1 = 0 }                              // 500 ms sin tramas
else                      { AGE1 = AGE1 + 1 }                      // seguir contando
```

* Cada trama válida reinicia la edad, marca el enlace como vigente y guarda el comando.
* Si pasan 500 ms sin tramas, el enlace se marca como perdido y el contador se queda en su valor máximo (no da la vuelta).
* El último comando se conserva hasta que llegue otra trama.

### Detección anticipada

```verilog
assign EXPIRE1    = RF1 && (AGE1 == TC_RF) && !FRAME_1_VALID;
assign RF1_OK_EFF = RF1 && !EXPIRE1;
```

En el último ciclo antes de vencer, si no llega una trama, `RF1_OK_EFF` baja **en ese mismo ciclo**, sin esperar a que el registro `RF1` cambie en el siguiente flanco. Así la FSM detiene el juego un ciclo antes. Si justo en ese ciclo llega una trama, la trama tiene prioridad y el enlace sigue vigente. Esto corresponde a las ecuaciones 71 a 73 de F2.

## Por qué dejó de usarse

En F5 cambiamos a mandos cableados. Con cables no hay tramas ni tiempos de espera: la presencia del mando se detecta directamente con la línea DETECT. El nuevo supervisor mantiene las mismas salidas (`CMD_J1`, `CMD_J2`, `RF_OK_EFF`) para que el resto del diseño no cambiara.

## Cómo lo probamos

`tb_supervisor_rf` (F3) revisa: inicialización sin enlace, alta independiente de cada jugador, comandos y retención, vencimiento independiente y simultáneo, recuperación, detección anticipada, prioridad de la trama sobre el vencimiento, contadores saturados y prioridad de `INIT_GLOBAL`. Además, `tb_pong_integracion` prueba la pérdida y recuperación del enlace dentro del sistema completo.

## Historia

Escrito en F3. Reemplazado en F5 por `supervisor_cableado`.
