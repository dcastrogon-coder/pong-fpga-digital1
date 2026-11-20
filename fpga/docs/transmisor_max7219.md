# `transmisor_max7219.v`: comunicación serial con las matrices

[Volver al índice](README.md) · Código: [`rtl/transmisor_max7219.v`](../rtl/transmisor_max7219.v)

## Qué hace

Es el módulo que habla con las dos matrices LED. Cada matriz FC-16 tiene un controlador GC7219C, compatible con el MAX7219, y los dos están en cascada. El transmisor:

1. Al arrancar, manda **14 comandos de configuración** a los dos controladores.
2. Después entra en un ciclo que no termina: pide una foto a [`captura_imagen`](captura_imagen.md), le pide a [`imagen`](imagen.md) los bytes de cada fila y manda las 8 filas, una tras otra.

Todo se envía por tres líneas: `DIN` (dato), `CLK_LED` (reloj serial) y `LOAD` (carga).

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `H` | 25 | Ciclos que dura cada medio periodo de `CLK_LED` y cada fase de `LOAD`: 25 × 20 ns = 500 ns |
| `FAR_IS_B` | 1 | La matriz B es la lejana en la cascada (la que recibe los datos a través de la A) |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `FRAME_READY` | entrada | La foto está lista |
| `CAPTURE_REQ` | salida | Pedido de foto (un ciclo) |
| `FRAME_BUSY` | salida | 1 mientras el transmisor está ocupado |
| `ROW_IDX[2:0]` | salida | Fila que se está enviando |
| `DATA_A[7:0]`, `DATA_B[7:0]` | entrada | Bytes de la fila para cada matriz |
| `DIN`, `CLK_LED`, `LOAD` | salida | Líneas seriales hacia las matrices |
| `FAULT_TX` | salida | El transmisor entró en un estado imposible |

## Cómo le hablamos a un MAX7219

Cada controlador recibe palabras de 16 bits:

```
bits 15-12: no importan (0000)
bits 11-8:  dirección del registro (1-8 = filas, 9-15 = configuración)
bits 7-0:   dato
```

Los bits entran por `DIN`, del más significativo al menos significativo, y cada flanco de subida de `CLK_LED` empuja uno. Cuando se termina de mandar, un pulso en `LOAD` hace que el controlador ejecute la palabra.

Con **dos controladores en cascada**, la salida de datos del primero va a la entrada del segundo. Por eso mandamos **32 bits** seguidos: los primeros 16 atraviesan el primer controlador y terminan en el segundo (el lejano), y los últimos 16 se quedan en el primero (el cercano). Un solo pulso de `LOAD` carga los dos a la vez.

```verilog
assign FRAME32_ROW = FAR_IS_B ? {WORD_B, WORD_A} : {WORD_A, WORD_B};
```

Con `FAR_IS_B = 1`, la palabra de la matriz B sale primero.

## Comandos de configuración

Durante el arranque (`INIT_MODE = 1`) se mandan estos 14 comandos, y cada uno va a los dos controladores al mismo tiempo (`{INIT_WORD, INIT_WORD}`):

| `INIT_IDX` | Palabra | Efecto |
|------------|---------|--------|
| 0 | `0x0F00` | Apaga el modo de prueba (todos los LED prendidos) |
| 1 | `0x0C00` | Entra en *shutdown* mientras se configura |
| 2 | `0x0900` | Sin decodificación: cada bit es un LED |
| 3 | `0x0B07` | Barrer las 8 filas |
| 4 | `0x0A08` | Brillo medio (8 de 15) |
| 5 a 12 | `0x0100` a `0x0800` | Borra las filas 1 a 8 |
| 13 | `0x0C01` | Sale de *shutdown*: operación normal |

## La máquina de estados

| Estado | Nombre | Qué hace | Duración |
|--------|--------|----------|----------|
| T0 | INIT_SELECT | Elige el siguiente comando de configuración | 1 ciclo |
| T1 | IDLE | Reposo entre cuadros | 1 ciclo |
| T2 | REQUEST | Activa `CAPTURE_REQ` | 1 ciclo |
| T3 | WAIT_READY | Espera `FRAME_READY` y pone `ROW_IDX = 0` | 1 ciclo |
| T4 | ROW_SELECT | Da tiempo a que `imagen` calcule los bytes de la fila | 1 ciclo |
| T5 | LOAD_SHIFT | Carga los 32 bits en `SHIFT_REG` | 1 ciclo |
| T6 | BIT_LOW | `CLK_LED` en bajo, `DIN` con el bit actual | 25 ciclos |
| T7 | BIT_HIGH | `CLK_LED` en alto: el controlador lee el bit | 25 ciclos |
| T8 | BIT_STEP | Desplaza el registro o, si fue el bit 31, sigue a T9 | 1 ciclo |
| T9 | LATCH_GUARD | Margen antes de `LOAD` | 25 ciclos |
| T10 | LATCH_HIGH | `LOAD` en alto | 25 ciclos |
| T11 | LATCH_POST | Margen después de `LOAD` | 25 ciclos |
| T12 | NEXT | Decide: siguiente comando, siguiente fila o fin del cuadro | 1 ciclo |

Recorridos:

```
Arranque:  T0 → T5 → (T6 → T7 → T8) ×32 → T9 → T10 → T11 → T12 → T0 ...   (14 veces)
Cuadro:    T1 → T2 → T3 → [T4 → T5 → (T6 → T7 → T8) ×32 → T9 → T10 → T11 → T12] ×8 → T1
```

Las salidas se generan según el estado:

```verilog
assign CLK_LED     = (STATE_TX == T7)  && !INIT_GLOBAL;
assign LOAD        = (STATE_TX == T10) && !INIT_GLOBAL;
assign DIN         = !INIT_GLOBAL && (STATE_TX es T6, T7 o T8) ? SHIFT_REG[31] : 0;
assign CAPTURE_REQ = (STATE_TX == T2)  && !INIT_GLOBAL;
```

El bit que sale por `DIN` siempre es el más alto del registro de desplazamiento. En T8 el registro se corre una posición a la izquierda, así que en el siguiente T6 ya está el bit que sigue.

### Orientación vertical

```verilog
assign ROW_ADDR = 4'd8 - {1'b0, ROW_IDX};
```

La fila 0 del juego va al registro 8 del controlador, la fila 1 al 7, y así hasta la fila 7, que va al registro 1. Esta es la corrección vertical que hicimos en F4, cuando vimos cómo quedaban montadas las matrices.

## Tiempos

| Medida | Cálculo | Valor |
|--------|---------|-------|
| Periodo de `CLK_LED` | 25 + 25 + 1 ciclos | 1,02 µs (unos 980 kHz) |
| `CLK_LED` en alto | 25 ciclos | 500 ns |
| Dato estable antes del flanco | 25 ciclos de T6 | 500 ns |
| Pulso de `LOAD` | 25 ciclos | 500 ns |
| Una fila (32 bits + `LOAD`) | 32 × 51 + 75 + 3 ciclos | 1 710 ciclos, unos 34 µs |
| Un cuadro completo (8 filas) | 3 + 8 × 1 710 ciclos | unos 0,27 ms (más de 3 600 cuadros por segundo) |
| Configuración inicial (14 comandos) | 14 × 1 710 ciclos | unos 0,48 ms |

La hoja de datos del GC7219C pide, por ejemplo, un periodo de reloj de al menos 100 ns, 50 ns en alto y en bajo y 25 ns de dato estable antes del flanco. Nosotros usamos tiempos unas 10 veces más largos, porque las señales pasan por el SN74HCT245N, que agrega hasta 38 ns de retardo, y por cables. Con este margen no hubo problemas de comunicación en ningún montaje, ni en protoboard ni en la placa.

## Detector de fallos

```verilog
assign INVALID_STATE = códigos 13, 14 o 15;
assign INVALID_INIT  = INIT_MODE && (INIT_IDX > 13);
assign INVALID_DIV   = (estado temporizado) && (DIV_COUNT >= 25);
assign FAULT_TX      = INVALID_STATE || INVALID_INIT || INVALID_DIV;
```

Si el transmisor llega a un valor que no debería existir, `FAULT_TX` avisa a [`supervisor_fallos`](supervisor_fallos.md), que reinicia todo el sistema. Al reiniciar, el transmisor vuelve a mandar la configuración desde cero, así que las matrices también se recuperan.

## Por qué lo hicimos así

* **Una FSM en vez de un módulo SPI genérico.** El protocolo del MAX7219 es parecido a SPI, pero necesitábamos manejar con detalle los márgenes alrededor de `LOAD`, la cascada de dos chips y la secuencia de configuración. Con una FSM propia cada tiempo queda a la vista en una tabla.
* **Reloj serial generado por estados.** `CLK_LED` no es un reloj de la FPGA: es una salida que vale 1 en el estado T7. Así todo el diseño sigue funcionando con un solo reloj de 50 MHz.
* **Refresco continuo.** Mandamos la imagen completa una y otra vez, cambie o no. Es más simple que detectar cambios y además corrige cualquier error de comunicación en menos de un milisegundo.
* **Configurar los dos chips con la misma palabra.** Las dos matrices necesitan la misma configuración, así que basta con repetir la palabra en los 32 bits.

## Cómo lo probamos

* `tb_transmisor_max7219` (F3, actualizado en F4): decodifica cada trama de 32 bits y revisa la configuración, el orden de las palabras en la cascada, el contenido de cada fila y la captura coherente de la imagen.
* `tb_pong_max7219_integrado`: lo mismo con el sistema completo (14 comandos y dos cuadros de 8 filas).
* `tb_hct_init_max7219_f5`, `tb_hct_filas_f5` y `tb_hct_refresco_f5`: configuración, primer cuadro y refresco continuo con el top de F5.
* `tb_gc7219_temporizacion_f5`: mide los tiempos de cada trama contra los mínimos del GC7219C, incluso con retardos simulados del SN74HCT245N (88 tramas).

## Historia

Escrito en F3 a partir de la FSM del transmisor de F2. En F4 corregimos la orientación vertical (`ROW_ADDR = 8 − ROW_IDX`). Los comentarios del código que dicen "provisional" o que la orientación "se revisará en F4" son de F3; los valores actuales son los definitivos.
