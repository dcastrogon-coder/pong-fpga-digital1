# `pong_f5_core.v`: núcleo del juego

[Volver al índice](README.md) · Código: [`rtl/pong_f5_core.v`](../rtl/pong_f5_core.v)

## Qué hace

Es el módulo que arma el juego completo: crea una instancia de cada bloque y los conecta entre sí con cables (`wire`). No tiene lógica propia más allá de unas pocas compuertas OR. Si se quiere entender cómo viaja una señal de un bloque a otro, este es el archivo para mirar.

Lo usan los dos tops de las últimas fases: [`pong_f6_integracion_top`](pong_f6_integracion_top.md) (el final) y [`pong_f5_controles_top`](pong_f5_controles_top.md).

## Parámetros

| Parámetro | Valor real | Qué controla | Se pasa a |
|-----------|-----------|--------------|-----------|
| `NDB_BUTTON` | 1 000 000 (20 ms) | Antirrebote de START, PAUSE y de las líneas de los mandos | `boton_evento`, `supervisor_cableado` |
| `NDB_RESET` | 1 000 000 (20 ms) | Tiempo de liberación del RESET | `reset_seguro` |
| `N_BALL` | 10 000 000 (200 ms) | Periodo de movimiento de la pelota | `temporizadores` |
| `N_PADDLE` | 12 500 000 (250 ms) | Periodo de movimiento de las paletas | `temporizadores` |
| `H_LED` | 25 | Medio periodo del reloj serial de las matrices (25 ciclos = 500 ns) | `transmisor_max7219` |
| `FAR_IS_B` | 1 | La matriz B (columnas 8–15) es la lejana en la cascada | `transmisor_max7219` |
| `N_RF` | 25 000 000 | Quedó de la versión inalámbrica; en este núcleo no se usa | — |

Los parámetros existen para que los bancos de prueba puedan instanciar el núcleo con tiempos cortos (por ejemplo, un antirrebote de 4 ciclos en vez de 1 000 000) sin cambiar nada del RTL.

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS` | entrada | Reloj de 50 MHz |
| `START_RAW`, `RESET_RAW`, `PAUSE_RAW` | entrada | Pulsadores, **activos en alto** (el top ya los negó) |
| `J1_UP_N`, `J1_DOWN_N`, `J1_DETECT_N` | entrada | Mando del jugador 1, activo en bajo |
| `J2_UP_N`, `J2_DOWN_N`, `J2_DETECT_N` | entrada | Mando del jugador 2, activo en bajo |
| `DIN`, `CLK_LED`, `LOAD` | salida | Interfaz serial de las dos matrices |
| `SCORE_J1_BCD[3:0]`, `SCORE_J2_BCD[3:0]` | salida | Puntajes en BCD |

## Cómo está organizado

El archivo está dividido en 11 secciones numeradas, en el mismo orden en que circula la información:

| Sección | Bloques | Señales importantes que salen |
|---------|---------|-------------------------------|
| 1. Reset y botones | [`reset_seguro`](reset_seguro.md), dos [`boton_evento`](boton_evento.md) | `POR_REQ`, `RESET_CLEAN`, `START_PULSE`, `PAUSE_PULSE` |
| 2. Mandos | [`supervisor_cableado`](supervisor_cableado.md) | `CMD_J1`, `CMD_J2`, `RF_OK_EFF` |
| 3. Máquina de estados | [`control_juego`](control_juego.md) | `STATE`, `GAME_EN`, `CAPTURE_GOAL`, `POINT_EN`, `CENTER_EN`, `REARM_TIMERS`, `SERVE_DIR` |
| 4. Temporizadores | [`temporizadores`](temporizadores.md) | `TICK_BALL`, `TICK_PADDLE` |
| 5. Paletas | [`paletas`](paletas.md) | `YP1`, `YP2`, `YP1_EFF`, `YP2_EFF` |
| 6. Pelota | [`pelota`](pelota.md) | `XB`, `YB`, `DX`, `DY`, `X_CAND`, `Y_CAND` |
| 7. Colisiones | [`colisiones`](colisiones.md) | `HIT_J1`, `HIT_J2`, `GOAL_J1`, `GOAL_J2` |
| 8. Puntaje | [`puntaje`](puntaje.md), [`marcador_bcd`](marcador_bcd.md) | `SCORE_J1`, `SCORE_J2`, `WIN_NEXT`, salidas BCD |
| 9. Imagen | [`captura_imagen`](captura_imagen.md), [`imagen`](imagen.md) | `SNAPSHOT`, `FRAME_READY`, `DATA_A`, `DATA_B` |
| 10. Transmisor | [`transmisor_max7219`](transmisor_max7219.md) | `DIN`, `CLK_LED`, `LOAD`, `CAPTURE_REQ`, `ROW_IDX`, `FAULT_TX` |
| 11. Supervisión | [`supervisor_fallos`](supervisor_fallos.md) | `FAULT_RECOVER` |

### La única lógica propia

```verilog
assign INIT_GLOBAL = POR_REQ | RESET_CLEAN | FAULT_RECOVER;

assign HIT  = HIT_J1  | HIT_J2;
assign GOAL = GOAL_J1 | GOAL_J2;
```

* **`INIT_GLOBAL`** es el reset de todo el sistema. Se activa por cualquiera de tres motivos: el arranque (`POR_REQ`), el pulsador RESET (`RESET_CLEAN`) o un fallo detectado (`FAULT_RECOVER`). Llega a todos los módulos con registros.
* **`HIT` y `GOAL`**: el módulo de colisiones dice *quién* tocó o *quién* anotó, pero a la pelota solo le importa *si* hubo rebote o gol, así que juntamos las señales con una OR.

### Lazos que hay que tener en cuenta

Hay dos caminos que van "hacia atrás" en el diagrama, y los dos están cortados por registros:

* **Fallos → reset.** `supervisor_fallos` mira valores registrados (estado, puntajes, posiciones) y genera `FAULT_RECOVER`, que entra a `INIT_GLOBAL`. El reset se aplica en el siguiente flanco de reloj, así que no hay un lazo combinacional.
* **Transmisor ↔ captura.** El transmisor pide una foto con `CAPTURE_REQ`; `captura_imagen` la guarda y responde con `FRAME_READY` un ciclo después.

## Por qué lo hicimos así

* **Separar núcleo y top.** En F5 cambiamos los pines y el top varias veces (con y sin `HCT_EN`, con y sin marcador), pero la lógica del juego no cambió. Al tenerla en un núcleo aparte, cada top nuevo es un archivo corto, y los bancos de prueba pueden probar el núcleo directamente con tiempos reducidos.
* **Salidas que no se usan.** Algunas salidas de los bloques se dejan sin conectar (`PRESSED_DB` de los botones, `SCORER` del puntaje, `DY_CAND` de la pelota). Sirven en los bancos de prueba de cada módulo, y Quartus las elimina en la síntesis.
* **Comentarios de F3.** El encabezado del archivo todavía describe la interfaz RF de F3, porque este núcleo nació como copia de [`pong_top`](pong_top.md). El cambio de fondo está en la sección 2, donde `supervisor_rf` se reemplazó por `supervisor_cableado`.

## Cómo lo probamos

Lo instancian directamente varios bancos de prueba de F5, con parámetros reducidos: `tb_hct_controles_cableados_f5`, `tb_hct_reset_pausa_f5`, `tb_inicio_reset_integrado_f5` y `tb_integracion_temporizada_f5`. Ahí se revisa el sistema completo: desde que se presiona un botón hasta los bits que salen por `DIN`. Ver [bancos de prueba](bancos_de_prueba.md).

## Historia

Lo creamos en F5 copiando [`pong_top`](pong_top.md) de F3 y cambiando la interfaz de los mandos. En F6 no lo tocamos: las salidas BCD ya estaban desde F3, solo faltaba sacarlas a pines en el top.
