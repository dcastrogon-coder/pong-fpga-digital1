# `pong_f6_integracion_top.v`: top final

[Volver al índice](README.md) · Código: [`rtl/pong_f6_integracion_top.v`](../rtl/pong_f6_integracion_top.v)

## Qué hace

Es el módulo de más arriba del diseño, el que Quartus compila y cargamos en la FPGA. Sus puertos son los pines reales de la tarjeta A-C4E6E10. Hace tres cosas:

1. Recibe los pulsadores (START, PAUSE, RESET) y los mandos, que son activos en bajo, y se los pasa al núcleo del juego.
2. Saca hacia afuera las tres líneas de las matrices (`DIN`, `CLK_LED`, `LOAD`) y los dos puntajes en BCD.
3. Genera `HCT_EN`, la señal que habilita los dos búferes SN74HCT245N 50 ms después de que la FPGA arranca.

Toda la lógica del juego está en [`pong_f5_core`](pong_f5_core.md). Este archivo solo es la "cáscara" que lo conecta con el mundo físico.

## Parámetros

| Parámetro | Valor | Para qué sirve |
|-----------|-------|----------------|
| `HCT_WAIT_CYCLES` | 2 500 000 | Ciclos de espera antes de habilitar los búferes: 2 500 000 × 20 ns = 50 ms |
| `NDB_RESET_TOP` | 1 000 000 | Tiempo que el RESET debe estar suelto para liberarse (20 ms). Se lo pasamos al núcleo |

En la tarjeta se usan los valores por defecto. En las simulaciones los bajamos para no esperar millones de ciclos.

## Puertos

| Puerto | Dirección | Pin | Descripción |
|--------|-----------|-----|-------------|
| `CLK_SYS` | entrada | 23 | Reloj de 50 MHz de la tarjeta |
| `START_N` | entrada | 43 | Pulsador START, activo en bajo |
| `RESET_N` | entrada | 44 | Pulsador RESET, activo en bajo |
| `PAUSE_N` | entrada | 46 | Pulsador PAUSE, activo en bajo |
| `J1_UP_N`, `J1_DOWN_N`, `J1_DETECT_N` | entrada | 30, 32, 34 | Mando del jugador 1 |
| `J2_UP_N`, `J2_DOWN_N`, `J2_DETECT_N` | entrada | 39, 38, 42 | Mando del jugador 2 |
| `DIN` | salida | 28 | Dato serial hacia las matrices |
| `CLK_LED` | salida | 31 | Reloj serial de las matrices |
| `LOAD` | salida | 33 | Pulso que carga cada fila en los controladores |
| `HCT_EN` | salida | 49 | Habilitación de los búferes (a través de los 2N3904) |
| `SCORE_J1_BCD[3:0]` | salida | 101, 103, 104, 105 | Puntaje del jugador 1 en BCD (bit 0 a bit 3) |
| `SCORE_J2_BCD[3:0]` | salida | 106, 110, 111, 112 | Puntaje del jugador 2 en BCD (bit 0 a bit 3) |

En total son 22 pines: 10 entradas y 12 salidas.

## Cómo funciona

### Conversión de activo en bajo a activo en alto

Los pulsadores van a tierra con un pull-up a 3,3 V, así que en reposo leemos 1 y al presionar leemos 0. El núcleo trabaja con botones activos en alto, por eso los negamos al conectarlos:

```verilog
.START_RAW(~START_N),
.RESET_RAW(~RESET_N | ~HCT_EN),
.PAUSE_RAW(~PAUSE_N),
```

Las líneas de los mandos sí entran tal cual (`J1_UP_N`, etc.), porque [`supervisor_cableado`](supervisor_cableado.md) ya está hecho para recibirlas activas en bajo.

### El reset mientras los búferes están apagados

En `RESET_RAW` metimos también `~HCT_EN`. Eso quiere decir que mientras los búferes no estén habilitados, el núcleo ve un RESET presionado. Así el juego no arranca ni empieza a mandar datos a las matrices antes de que exista un camino eléctrico hacia ellas. Cuando `HCT_EN` sube, el RESET se "suelta" y [`reset_seguro`](reset_seguro.md) espera sus 20 ms de estabilidad. El sistema queda funcionando unos 70 ms después de programar la tarjeta.

### Habilitación de los búferes

```verilog
reg [21:0] HCT_DELAY = 22'd0;

always @(posedge CLK_SYS) begin
    if (HCT_DELAY < HCT_WAIT_CYCLES)
        HCT_DELAY <= HCT_DELAY + 22'd1;
end

assign HCT_EN = (HCT_DELAY == HCT_WAIT_CYCLES);
```

Es un contador de 22 bits que arranca en 0 cuando la FPGA termina de configurarse, cuenta hasta 2 500 000 y se queda ahí. Mientras cuenta, `HCT_EN = 0`; al llegar, `HCT_EN = 1` y no vuelve a bajar. Con 22 bits alcanza hasta 4 194 303, así que el valor de 50 ms cabe con margen.

Afuera, `HCT_EN` maneja la base de dos transistores 2N3904. Cuando conducen, llevan a tierra el `/OE` de cada SN74HCT245N y los búferes empiezan a pasar las señales de 3,3 V a 5 V. Mientras `HCT_EN = 0`, una resistencia de 10 kΩ mantiene `/OE` en alto y las salidas de los búferes quedan en alta impedancia. Las resistencias de la placa dejan entonces las matrices en reposo y el marcador en 0–0.

## Por qué lo hicimos así

* **Los 50 ms de espera.** Durante la configuración de la FPGA los pines quedan en un estado que no controlamos. Si los búferes estuvieran habilitados desde el principio, las matrices podrían recibir basura y quedar en un modo raro. Esperamos a que la FPGA esté estable antes de conectar nada.
* **Un solo contador y nada más.** Quisimos que el top fuera lo más simple posible: toda la lógica está en el núcleo, que ya estaba probado en F5. En F6 solo agregamos las salidas BCD.

## Cómo lo probamos

* `tb_hct_arranque_f5` revisa que `HCT_EN` suba en el momento correcto y que el núcleo se mantenga en reset hasta entonces (lo prueba sobre [`pong_f5_controles_top`](pong_f5_controles_top.md), que tiene exactamente el mismo contador).
* En la tarjeta jugamos partidas completas, con victoria, RESET y nueva partida, usando este top.

Más detalle en [bancos de prueba](bancos_de_prueba.md).

## Historia

Lo creamos en F6 a partir de `pong_f5_controles_top`, agregando los puertos `SCORE_J1_BCD` y `SCORE_J2_BCD`. Es el top configurado en [`pong_top.qsf`](proyecto_quartus.md).
