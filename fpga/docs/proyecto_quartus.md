# Proyecto de Quartus: `pong_f3.qpf`, `pong_top.qsf` y `pong_f3.sdc`

[Volver al índice](README.md) · Archivos: [`pong_f3.qpf`](../pong_f3.qpf), [`pong_top.qsf`](../pong_top.qsf), [`pong_f3.sdc`](../pong_f3.sdc)

Estos tres archivos forman el proyecto que abrimos en Quartus Prime 25.1 Lite para compilar el diseño y programar la tarjeta. Los nombres vienen de F3, cuando creamos el proyecto; lo seguimos usando en todas las fases y solo cambiamos el top y los pines.

## `pong_f3.qpf`: el proyecto

Es el archivo que se abre en Quartus (*File → Open Project*). Solo dice la versión de Quartus y cuál es la revisión activa:

```
PROJECT_REVISION = "pong_top"
```

Por eso la configuración está en `pong_top.qsf` y el archivo de programación sale como `output_files/pong_top.sof`.

## `pong_top.qsf`: configuración y pines

### Dispositivo y top

```
FAMILY              "Cyclone IV E"
DEVICE              EP4CE10E22C8
TOP_LEVEL_ENTITY    pong_f6_integracion_top
```

`TOP_LEVEL_ENTITY` dice qué módulo es el diseño que se carga en la FPGA. En F4 era `pong_f4_visual_top`, en F5 `pong_f5_controles_top` y desde F6 es [`pong_f6_integracion_top`](pong_f6_integracion_top.md). Los demás archivos `.v` del proyecto se compilan, pero Quartus solo sintetiza los módulos que cuelgan del top.

### Asignación de pines

| Señal | Pin | Señal | Pin |
|-------|-----|-------|-----|
| `CLK_SYS` | 23 | `DIN` | 28 |
| `J1_UP_N` | 30 | `CLK_LED` | 31 |
| `J1_DOWN_N` | 32 | `LOAD` | 33 |
| `J1_DETECT_N` | 34 | `HCT_EN` | 49 |
| `J2_DOWN_N` | 38 | `SCORE_J1_BCD[0..3]` | 101, 103, 104, 105 |
| `J2_UP_N` | 39 | `SCORE_J2_BCD[0..3]` | 106, 110, 111, 112 |
| `J2_DETECT_N` | 42 | | |
| `START_N` | 43 | | |
| `RESET_N` | 44 | | |
| `PAUSE_N` | 46 | | |

Los ocho bits del marcador salen por el conector LCD (J2) de la tarjeta, contactos 7 a 14, que tiene ocho líneas de datos seguidas. Mientras se use ese conector para el marcador, no se puede conectar una pantalla LCD ahí. El detalle de cada conexión está en [`hardware/`](../../hardware/).

### Estándar eléctrico

* Todos los pines usan **3,3-V LVTTL**, que es el nivel de los bancos de E/S de la tarjeta.
* Las salidas (`DIN`, `CLK_LED`, `LOAD`, `HCT_EN` y los ocho bits BCD) tienen una corriente de salida de **8 mA**, suficiente para manejar las entradas de los SN74HCT245N y la base de los 2N3904 a través de su resistencia.

### El pin 101 (nCEO)

```
CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
```

El pin 101 normalmente está reservado para la configuración en cadena de varias FPGA (nCEO). Como nosotros configuramos una sola FPGA por JTAG, le dijimos a Quartus que lo liberara como pin normal, porque lo necesitábamos para el bit 0 del marcador del jugador 1. Sin esta opción, Quartus no deja usar ese pin como salida.

### Archivos del proyecto

Al final del `.qsf` está la lista de archivos: los 21 módulos de `rtl/` y el `.sdc`. Los bancos de prueba **no** están en la lista, porque no son sintetizables: solo se usan en simulación.

## `pong_f3.sdc`: restricciones de tiempo

Le dice a TimeQuest (el analizador de tiempos de Quartus) cómo es el reloj y qué caminos debe revisar.

### Reloj

```tcl
create_clock -name CLK_SYS -period 20.000 [get_ports {CLK_SYS}]
derive_clock_uncertainty
```

El reloj de la tarjeta es de 50 MHz, es decir, 20 ns por ciclo. Con esto Quartus comprueba que ninguna operación entre dos registros tarde más de 20 ns.

### Entradas asíncronas

```tcl
set_false_path -from [get_ports {RESET_N}] -to [all_registers]
set_false_path -from [get_ports {J1_UP_N ... START_N PAUSE_N}] -to [get_registers {*|SYNC_1}]
```

Los pulsadores y los mandos cambian en cualquier momento, sin relación con el reloj. No tiene sentido que TimeQuest analice esos caminos como si fueran síncronos. Por eso los marcamos como *false path*, pero solo hasta el primer flip-flop del sincronizador (`SYNC_1`). Desde ahí en adelante todo sí se analiza normalmente. El RESET es un caso especial porque entra de forma asíncrona a [`reset_seguro`](reset_seguro.md).

### Salidas

```tcl
set_max_delay 40.000 -to [get_ports {DIN CLK_LED LOAD}]
set_max_delay 40.000 -to [get_ports {SCORE_J1_BCD* SCORE_J2_BCD*}]
set_false_path -to [get_ports {HCT_EN}]
```

* Para las líneas de las matrices y del marcador pusimos un retardo máximo de 40 ns desde el registro hasta el pin. Es un límite holgado: las matrices leen los datos con márgenes de 500 ns (ver [`transmisor_max7219`](transmisor_max7219.md)) y el marcador cambia solo cuando hay un punto.
* `HCT_EN` sube una sola vez, 50 ms después del arranque, así que no hay ningún tiempo que verificar.

## Resultado de la compilación final

| Medida | Valor |
|--------|-------|
| Elementos lógicos | 660 en síntesis, 665 después del *fitter* (de 10 320 disponibles) |
| Registros | 379 |
| Pines | 22 (10 entradas, 12 salidas) |
| *Slack* de setup | +6,686 ns (modelo lento a 85 °C), +7,570 ns (lento a 0 °C), +14,237 ns (rápido) |
| *Slack* de hold | +0,452 ns, +0,400 ns y +0,186 ns |
| Errores / advertencias | 0 / 8 |

Un *slack* positivo quiere decir que todas las señales llegan a tiempo, incluso en el peor caso de temperatura. Los reportes completos están en `fases/F6_integracion_montaje/quartus_reportes/`.

## Cómo compilar y programar

1. Abrir `fpga/pong_f3.qpf` en Quartus Prime.
2. *Processing → Start Compilation*.
3. Encender primero la fuente de 5 V y después la tarjeta.
4. *Tools → Programmer*, USB-Blaster en modo JTAG, cargar `output_files/pong_top.sof` y *Start*.

La configuración por JTAG se borra al apagar la tarjeta, así que hay que programarla en cada encendido.
