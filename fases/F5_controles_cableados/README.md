# F5 · Controles cableados y validación física del juego

Documento: [`F5_Cierre_Tecnico.pdf`](F5_Cierre_Tecnico.pdf) · 14 de noviembre de 2026 · **PC5**

En esta fase dejamos el juego completo funcionando en la tarjeta con las dos matrices:

* Cambiamos los controles RF por **mandos cableados** con UP, DOWN y DETECT (detección de que el mando está conectado). Las entradas pasan por dos flip-flops de sincronización y un antirrebote de 20 ms (`filtro_entrada_cableada.v`, `supervisor_cableado.v`).
* Reutilizamos la señal `RF_OK_EFF` del diseño original para la conexión del mando: si un mando se desconecta, el juego pasa a PAUSA_RF y no sigue hasta reconectarlo y presionar START.
* Pusimos la pelota a moverse en **diagonal**: en cada pulso de 200 ms avanza una columna y una fila a la vez (`pelota.v`). La señal PHASE quedó en la interfaz por compatibilidad, pero ya no frena el avance vertical.
* Agregamos el primer SN74HCT245N para las matrices y la habilitación `HCT_EN` (pin 49), que sube unos 50 ms después de arrancar.
* El top de esta fase es `pong_f5_controles_top.v`, con el núcleo `pong_f5_core.v`. El código está en [`fpga/rtl/`](../../fpga/rtl/).

## Simulación

Escribimos 20 bancos de prueba nuevos; 18 siguen vigentes con la pelota diagonal (los otros dos son de antes del cambio y están en `fpga/tb/anteriores_al_movimiento_diagonal/`). Los tres principales de la memoria:

| Banco de prueba | Qué comprueba | Resultado |
|-----------------|---------------|-----------|
| `tb_pelota_diagonal_f5` | Inicio, avance a 45°, rebote y centrado | 12/12 |
| `tb_pelota_goles_diagonal_f5` | Goles de J1 y J2, marcador, saques y diagonales | 14/14 |
| `tb_hct_reset_pausa_f5` | START, PAUSE, RESET, refresco y tramas de 32 bits | 28/28 instrucciones de inicio (14 + 14 tras RESET) |

Los demás (mandos, pausas, temporizadores, reset, colisiones y puntaje, refresco de filas, modelo de tiempos del GC7219C) también pasan; el resumen completo está en [`fpga/`](../../fpga/).

## Compilación (Quartus Prime 25.1 Lite)

| Magnitud | Valor |
|----------|-------|
| Top | `pong_f5_controles_top` |
| Errores / advertencias | 0 / 8 |
| Elementos lógicos | 664 de 10 320 (6 %) |
| Registros | 379 |
| Pines | 14 (10 entradas, 4 salidas) |
| Peor *slack* de setup (lento, 85 °C) | +8,546 ns |
| Peor *slack* de hold (rápido, 0 °C) | +0,186 ns |

Los resúmenes de Quartus están en [`quartus_reportes/`](quartus_reportes/).

## Pruebas en la tarjeta

Todas aprobadas: programación por JTAG y patrón inicial, START, PAUSE, RESET, paletas independientes de J1 y J2, bloqueo al desconectar DETECT, movimiento diagonal, rebotes en paletas y bordes, y gol en cada extremo con centrado y nuevo saque. Medimos unos 5,23 V en la alimentación de la primera matriz, 3,31 V en el riel de los controles y 5,22 V en /OE con la FPGA apagada (búfer deshabilitado).
