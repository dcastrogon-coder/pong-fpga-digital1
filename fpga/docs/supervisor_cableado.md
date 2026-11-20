# `supervisor_cableado.v`: comandos y detección de los mandos

[Volver al índice](README.md) · Código: [`rtl/supervisor_cableado.v`](../rtl/supervisor_cableado.v)

## Qué hace

Recibe las seis líneas de los dos mandos (UP, DOWN y DETECT de cada jugador) y entrega:

* Un **comando de 2 bits por jugador** (`CMD_J1`, `CMD_J2`) para [`paletas`](paletas.md): subir, bajar o quedarse quieta.
* Una señal por jugador que dice si su mando está conectado (`RF1_OK_EFF`, `RF2_OK_EFF`) y una conjunta (`RF_OK_EFF`) para [`control_juego`](control_juego.md).

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `NDB` | 1 000 000 | Antirrebote de cada línea (20 ms). Se pasa a los seis filtros |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `J1_UP_N`, `J1_DOWN_N`, `J1_DETECT_N` | entrada | Mando del jugador 1 (activo en bajo) |
| `J2_UP_N`, `J2_DOWN_N`, `J2_DETECT_N` | entrada | Mando del jugador 2 (activo en bajo) |
| `CMD_J1[1:0]`, `CMD_J2[1:0]` | salida | Comando para cada paleta |
| `RF1_OK_EFF`, `RF2_OK_EFF` | salida | 1 = el mando de ese jugador está conectado |
| `RF_OK_EFF` | salida | 1 = los dos mandos están conectados |

## Cómo funciona

### 1. Filtrado

Cada una de las seis líneas pasa por su propio [`filtro_entrada_cableada`](filtro_entrada_cableada.md). A partir de ahí trabajamos con las versiones limpias (`J1_UP_CLEAN_N`, etc.).

### 2. Detección del mando

En cada mando, la línea DETECT va directo a la tierra del mando. Mientras el mando está enchufado, el pin lee 0; si se desconecta el cable, el pull-up de 10 kΩ lo sube a 1.

```verilog
assign RF1_OK_EFF = !J1_DETECT_CLEAN_N;
assign RF2_OK_EFF = !J2_DETECT_CLEAN_N;
assign RF_OK_EFF  = RF1_OK_EFF && RF2_OK_EFF;
```

Si falta cualquiera de los dos mandos, `RF_OK_EFF = 0` y la máquina de estados pone el juego en PAUSA_RF.

### 3. Comando de cada jugador

```verilog
assign CMD_J1 =
    !RF1_OK_EFF                        ? 2'b00 :   // mando desconectado
    (!J1_UP_CLEAN_N &&  J1_DOWN_CLEAN_N) ? 2'b01 :   // solo UP
    ( J1_UP_CLEAN_N && !J1_DOWN_CLEAN_N) ? 2'b10 :   // solo DOWN
                                           2'b00;    // ninguno o los dos
```

| UP | DOWN | Mando conectado | `CMD` | Significado |
|----|------|-----------------|-------|-------------|
| suelto | suelto | sí | `00` | Quieta |
| presionado | suelto | sí | `01` | Subir |
| suelto | presionado | sí | `10` | Bajar |
| presionado | presionado | sí | `00` | Quieta |
| cualquiera | cualquiera | no | `00` | Quieta |

El jugador 2 usa exactamente la misma tabla con sus propias líneas.

## Por qué lo hicimos así

* **Mismo contrato que la versión inalámbrica.** En F3 este lugar lo ocupaba [`supervisor_rf`](supervisor_rf.md), que entregaba `CMD_J1`, `CMD_J2` y `RF_OK_EFF` con este mismo formato. Al cambiar a mandos cableados en F5 escribimos un supervisor nuevo con las mismas salidas, y así no tuvimos que tocar ni la máquina de estados ni las paletas, que ya estaban probadas. Por eso las señales conservan el nombre "RF".
* **Los dos botones a la vez = quieta.** Si el jugador aprieta UP y DOWN al mismo tiempo no hay una respuesta "correcta", así que elegimos la más segura: no moverse.
* **Mando desconectado = quieta.** Si se suelta el cable a mitad de un movimiento, las líneas pueden quedar en cualquier valor. Forzar `00` evita que la paleta se mueva sola.
* **DETECT con un cable a tierra.** Es la forma más sencilla de saber si el mando está puesto: no necesita ningún componente extra, solo un hilo más en el cable.

## Cómo lo probamos

* `tb_supervisor_cableado_f5`: 10 pruebas con el antirrebote reducido a 4 ciclos. Detección de cada mando, comandos de subir y bajar, los dos botones a la vez, mando desconectado.
* `tb_paletas_cableadas_f5` (14 pruebas) y `tb_pausas_cableadas_f5` (18 pruebas) lo conectan con la máquina de estados y las paletas para probar el movimiento y las pausas por desconexión.
* `tb_hct_controles_cableados_f5` revisa el camino completo, desde el pin hasta la imagen que sale hacia las matrices.

## Historia

Lo creamos en F5 para reemplazar a `supervisor_rf`.
