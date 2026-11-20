# Bancos de prueba (`tb/`)

[Volver al índice](README.md) · Carpeta: [`tb/`](../tb/)

## Qué son

Un banco de prueba (*testbench*) es un archivo Verilog que no se carga en la FPGA. Crea una instancia del módulo que se quiere probar, le aplica entradas, mira las salidas y dice si son las esperadas. Todos los nuestros son **autoverificados**: comparan los resultados solos y al final imprimen `PASS`, `OK` o un conteo de comprobaciones. Si algo no coincide, imprimen `ERROR` y detienen la simulación. Así no hay que revisar formas de onda a mano para saber si el diseño funciona.

Los escribimos y los corrimos en Questa durante F3 y F5. Para que cualquiera pueda repetirlos, también los corremos con Icarus Verilog con el script [`correr_pruebas.sh`](simulacion_automatica.md).

**Estado actual:** los 35 bancos de `tb/` pasan con el RTL final.

## Técnicas que usamos

* **Parámetros reducidos.** Con los tiempos reales, simular 20 ms de antirrebote son un millón de ciclos. En los bancos cambiamos los parámetros (por ejemplo, `NDB = 4`, `N_BALL = 4`, `N_PADDLE = 5` o `H = 2`) para que todo pase en pocos ciclos. El RTL es exactamente el mismo; solo cambia el valor del parámetro al instanciarlo.
* **Modelos de referencia.** En los bancos de módulos sueltos escribimos, dentro del banco, una versión simple del comportamiento esperado y comparamos el módulo contra ella ciclo a ciclo.
* **Pruebas exhaustivas.** Cuando las entradas son pocas, probamos todas las combinaciones (por ejemplo, las 512 de la máquina de estados).
* **Monitores seriales.** Para las matrices, el banco "escucha" `DIN`, `CLK_LED` y `LOAD` como lo haría un MAX7219, reconstruye cada trama de 32 bits y la compara con la esperada.
* **`force`/`release` solo donde hace falta.** En algunos bancos de integración ubicamos la pelota en una posición concreta para provocar un gol o un fallo sin esperar a que el juego llegue ahí solo. Nunca forzamos las señales que se están verificando (goles, puntos, estado).

## Bancos de módulos (F3)

| Banco | Módulo | Qué revisa | Resultado |
|-------|--------|------------|-----------|
| `tb_boton_evento.v` | [`boton_evento`](boton_evento.md) | Rebotes, un solo evento por pulsación, sin repetición al mantener, prioridad del reset | Todas las pruebas OK |
| `tb_reset_seguro.v` | [`reset_seguro`](reset_seguro.md) | Arranque, afirmación inmediata, liberación tras 20 ms, rebotes al soltar | 47 comprobaciones |
| `tb_supervisor_rf.v` | [`supervisor_rf`](supervisor_rf.md) | Alta, vencimiento y recuperación de cada enlace, detección anticipada | Todas las pruebas OK |
| `tb_control_juego.v` | [`control_juego`](control_juego.md) | Las 512 combinaciones de estado y entradas, más transiciones dirigidas | 512 combinaciones |
| `tb_temporizadores.v` | [`temporizadores`](temporizadores.md) | Inicialización, periodicidad 4:5, ticks coincidentes, contadores detenidos sin `GAME_EN` | Todas las pruebas OK |
| `tb_paletas.v` | [`paletas`](paletas.md) | Movimiento independiente, límites 0 y 6, bloqueo en el gol, posición efectiva | 14 pruebas |
| `tb_colisiones.v` | [`colisiones`](colisiones.md) | Barrido de posiciones contra un modelo de referencia | 87 823 comprobaciones |
| `tb_puntaje.v` | [`puntaje`](puntaje.md) | Sumas, saturación en 9, aviso de victoria | 37 pruebas |
| `tb_marcador_bcd.v` | [`marcador_bcd`](marcador_bcd.md) | Salida igual al puntaje en todas las combinaciones | 356 comprobaciones |
| `tb_captura_imagen.v` | [`captura_imagen`](captura_imagen.md) | Valor inicial, captura, retención, `FRAME_READY` de un ciclo | 13 pruebas |
| `tb_imagen.v` | [`imagen`](imagen.md) | Bytes de cada fila para todas las posiciones (orientación de F4) | 65 546 comprobaciones |
| `tb_transmisor_max7219.v` | [`transmisor_max7219`](transmisor_max7219.md) | Configuración, tramas de 32 bits, orden en la cascada, contenido de las filas | Todas las tramas OK |
| `tb_supervisor_fallos.v` | [`supervisor_fallos`](supervisor_fallos.md) | Cada indicador para todos los valores de entrada | 363 comprobaciones |

## Bancos de integración de F3

Instancian el núcleo original [`pong_top`](pong_top.md). Como los bloques internos son los mismos del diseño final, siguen siendo válidos.

| Banco | Qué revisa | Resultado |
|-------|------------|-----------|
| `tb_pong_integracion.v` | Arranque, START, pausa manual (congela el juego pero no el refresco), pérdida y recuperación del enlace, rearme de temporizadores | 9 / 9 |
| `tb_pong_goles_victoria.v` | Diez goles seguidos: cada uno suma un solo punto, el saque alterna, se llega a FIN con 9–1, FIN ignora START y RESET vuelve a 0–0 | 13 / 13 |
| `tb_pong_max7219_integrado.v` | 14 comandos de configuración y dos cuadros de 8 filas con la orientación final | 8 / 8 |
| `tb_pong_recuperacion_fallos.v` | Valores inválidos en estado, puntajes, paletas, pelota y transmisor: cada uno provoca la reinicialización y el juego vuelve a funcionar | 11 / 11 |

Tres de estos bancos (`tb_imagen`, `tb_transmisor_max7219` y `tb_pong_max7219_integrado`) los actualizamos en F4 con la nueva orientación de las matrices. Los cambios están marcados en el código con el comentario *Ajuste F4*.

## Bancos de F5

Prueban los mandos cableados, el movimiento diagonal y el top con `HCT_EN`.

| Banco | Instancia | Qué revisa | Resultado |
|-------|-----------|------------|-----------|
| `tb_supervisor_cableado_f5.v` | [`supervisor_cableado`](supervisor_cableado.md) | Detección de cada mando, comandos, los dos botones a la vez, mando desconectado | 10 / 10 |
| `tb_paletas_cableadas_f5.v` | supervisor + FSM + paletas | Movimiento de las paletas con los mandos reales, límites, desconexión | 14 / 14 |
| `tb_pausas_cableadas_f5.v` | supervisor + FSM | Pausa manual y pausa por desconexión, con su forma de salir | 18 / 18 |
| `tb_reset_seguro_f5.v` | [`reset_seguro`](reset_seguro.md) | Arranque de 4 ciclos, liberación tras 20 ms (reducidos), liberación demasiado breve y rebotes | 10 / 10 |
| `tb_temporizadores_f5.v` | [`temporizadores`](temporizadores.md) | Primeros ticks, contadores congelados en pausa, continuación, rearme | 13 / 13 |
| `tb_puntaje_reset_f5.v` | reset + [`puntaje`](puntaje.md) | Puntos de cada jugador, goles simultáneos rechazados, RESET con el marcador a mitad de partida | 10 / 10 |
| `tb_colisiones_puntaje_f5.v` | colisiones + FSM + puntaje | Rebote en la paleta, gol de cada jugador, paso por PUNTO y suma en el marcador | 12 / 12 |
| `tb_pelota_diagonal_f5.v` | [`pelota`](pelota.md) | Recorrido diagonal, rebotes en los bordes, centrado | 12 / 12 |
| `tb_pelota_goles_diagonal_f5.v` | pelota + colisiones + FSM + puntaje | Rebotes en las paletas y goles con el movimiento diagonal | 14 / 14 |
| `tb_inicio_reset_integrado_f5.v` | [`pong_f5_core`](pong_f5_core.md) | Arranque, START, RESET durante el juego y vuelta al estado inicial | 11 / 11 |
| `tb_integracion_temporizada_f5.v` | `pong_f5_core` | Partida con los tiempos reales de los pulsos: movimiento, desconexión, reconexión sin START, reanudación con START, RESET | 10 / 10 |
| `tb_hct_controles_cableados_f5.v` | `pong_f5_core` | Del pin a la matriz: antirrebote, movimiento de las paletas y su reflejo en las tramas seriales | Todas las tramas OK |
| `tb_hct_reset_pausa_f5.v` | `pong_f5_core` | PAUSE congela el juego pero no el refresco; RESET repite los 14 comandos (28/28 en total) | Todas las pruebas OK |
| `tb_hct_arranque_f5.v` | [`pong_f5_controles_top`](pong_f5_controles_top.md) | `HCT_EN` empieza en 0, sube a tiempo y el núcleo queda en reset hasta entonces | OK |
| `tb_hct_init_max7219_f5.v` | `pong_f5_controles_top` | Los 14 comandos de configuración y el fin del modo de inicialización | 14 / 14 |
| `tb_hct_filas_f5.v` | `pong_f5_controles_top` | Configuración y primer cuadro con la imagen inicial | 22 / 22 tramas |
| `tb_hct_refresco_f5.v` | `pong_f5_controles_top` | Configuración y tres cuadros seguidos sin cambios | 38 / 38 tramas |
| `tb_gc7219_temporizacion_f5.v` | `pong_f5_controles_top` | Tiempos de cada trama contra los mínimos del GC7219C, con retardos ideales del SN74HCT245N | 88 / 88 tramas |

## Bancos archivados (`tb/anteriores_al_movimiento_diagonal/`)

| Banco | Por qué está archivado |
|-------|------------------------|
| `tb_pelota.v` | Espera el movimiento de F3 (Y cada dos pasos) |
| `tb_pelota_goles_f5.v` | Versión de F5 anterior al cambio a diagonal |
| `tb_pong_colisiones_rebotes.v` | Rebotes con las posiciones del movimiento de F3 |
| `tb_hct_imagen_dinamica_f5.v` | Cuadros esperados calculados con el movimiento anterior |

Estos cuatro bancos estaban bien para el diseño de su momento, pero esperan posiciones de la pelota que ya no ocurren con el movimiento diagonal. Los movimos a esa carpeta para conservarlos como registro, y el script no los corre. Sus casos están cubiertos por `tb_pelota_diagonal_f5` y `tb_pelota_goles_diagonal_f5`.

## Cómo correr un banco

Todos juntos:

```bash
bash fpga/sim/correr_pruebas.sh
```

Solo los que contengan una palabra en el nombre (por ejemplo, los de F5):

```bash
bash fpga/sim/correr_pruebas.sh f5
```

Uno solo, a mano, con Icarus:

```bash
cd fpga
iverilog -g2012 -s tb_paletas -o sim/build/tb_paletas.vvp tb/tb_paletas.v rtl/*.v
vvp sim/build/tb_paletas.vvp
```

En Questa: crear un proyecto con los archivos de `rtl/` y el banco, compilar y simular el banco como módulo superior (`run -all`).
