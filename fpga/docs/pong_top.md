# `pong_top.v`: núcleo original de F3 (con interfaz inalámbrica)

[Volver al índice](README.md) · Código: [`rtl/pong_top.v`](../rtl/pong_top.v)

## Qué es

Es el primer diseño completo del Pong, el que escribimos en F3. Conecta los mismos bloques que el núcleo final [`pong_f5_core`](pong_f5_core.md), con una diferencia: los mandos iban a ser **inalámbricos**, así que en lugar de `supervisor_cableado` usa [`supervisor_rf`](supervisor_rf.md).

Ya no es parte del diseño que se carga en la tarjeta, pero lo dejamos en el repositorio porque:

* Lo usan cuatro bancos de prueba de integración de F3 que siguen corriendo en la regresión.
* Lo usa [`pong_f4_visual_top`](pong_f4_visual_top.md), el top de la prueba de las matrices.
* Muestra cómo era el diseño antes del cambio a mandos cableados.

## Diferencias con el núcleo final

| | `pong_top` (F3) | `pong_f5_core` (F5–F6) |
|-|-----------------|------------------------|
| Entradas de los mandos | `CMD_RX1[1:0]`, `FRAME_1_VALID`, `CMD_RX2[1:0]`, `FRAME_2_VALID` | `J1_UP_N`, `J1_DOWN_N`, `J1_DETECT_N`, y lo mismo para J2 |
| Supervisor | [`supervisor_rf`](supervisor_rf.md) | [`supervisor_cableado`](supervisor_cableado.md) |
| ¿Cuándo un mando está "OK"? | Llegó una trama válida en los últimos 500 ms | La línea DETECT está en 0 |
| Resto de bloques | Los mismos | Los mismos |

Los parámetros (`NDB_BUTTON`, `NDB_RESET`, `N_RF`, `N_BALL`, `N_PADDLE`, `H_LED`, `FAR_IS_B`) son los mismos. Aquí `N_RF` sí se usa: es el tiempo máximo sin tramas antes de declarar perdido un enlace (25 000 000 ciclos = 500 ms).

La interfaz suponía que un receptor externo entregaría el comando de 2 bits (`CMD_RXi`) y un pulso (`FRAME_i_VALID`) cada vez que llegara una trama válida, ya sincronizados con el reloj de 50 MHz.

## Por qué cambiamos

En F5 decidimos usar mandos cableados en lugar de RF. La versión cableada no depende de módulos de radio, no tiene retardos de recepción y la desconexión se detecta con un solo cable (DETECT). Como el resto del diseño solo veía `CMD_J1`, `CMD_J2` y `RF_OK_EFF`, bastó con copiar este archivo como `pong_f5_core`, cambiar las entradas y reemplazar el supervisor. Todo lo demás quedó igual y ya estaba probado.

## Cómo lo probamos

Estos bancos de F3 lo instancian directamente y siguen pasando con el RTL final:

* `tb_pong_integracion`: arranque, START, pausa manual, pérdida y recuperación del enlace (9 comprobaciones).
* `tb_pong_goles_victoria`: goles, saque alternado y victoria (13 comprobaciones).
* `tb_pong_max7219_integrado`: tramas seriales de configuración y de dos cuadros (8 comprobaciones).
* `tb_pong_recuperacion_fallos`: recuperación ante valores inválidos (11 comprobaciones).

Como los bloques internos son los mismos del diseño final, estas pruebas también verifican el núcleo actual.

## Historia

Escrito en F3. En F4 lo usamos dentro de `pong_f4_visual_top` para la primera prueba de las matrices. Desde F5 lo reemplaza `pong_f5_core`.
