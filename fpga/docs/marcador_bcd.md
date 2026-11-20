# `marcador_bcd.v`: salida BCD hacia el marcador

[Volver al índice](README.md) · Código: [`rtl/marcador_bcd.v`](../rtl/marcador_bcd.v)

## Qué hace

Lleva los puntajes que guarda [`puntaje`](puntaje.md) a los buses de salida que van a los decodificadores CD4511BE. Por dentro es solo una conexión directa:

```verilog
assign SCORE_J1_BCD = SCORE_J1;
assign SCORE_J2_BCD = SCORE_J2;
```

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `SCORE_J1[3:0]`, `SCORE_J2[3:0]` | entrada | Puntajes registrados (0 a 9) |
| `SCORE_J1_BCD[3:0]` | salida | Hacia los pines 101 (bit 0), 103, 104 y 105 (bit 3) |
| `SCORE_J2_BCD[3:0]` | salida | Hacia los pines 106 (bit 0), 110, 111 y 112 (bit 3) |

## El camino completo hasta el display

```
puntaje.v ──> marcador_bcd.v ──> pines FPGA (3,3 V)
          ──> SN74HCT245N #2 (3,3 V → 5 V)
          ──> CD4511BE (BCD → 7 segmentos)
          ──> 7 resistencias de 470 Ω
          ──> display 5161AS de cátodo común
```

El CD4511BE recibe el número en BCD y prende los segmentos que forman ese dígito. Por eso en la FPGA no necesitamos ninguna tabla de 7 segmentos: basta con sacar el número.

## Por qué existe un módulo que no hace nada

* **Sigue la arquitectura de F1 y F2.** En F1 definimos un bloque "marcador" con su propia salida, y en F2 su ecuación (la 68) dice exactamente esto: la salida BCD es igual al puntaje registrado. Mantener el módulo hace que el código se corresponda uno a uno con los documentos.
* **Punto único de cambio.** Si algún día usáramos displays sin decodificador externo, la tabla de 7 segmentos iría aquí y el resto del diseño no cambiaría.
* **Las salidas vienen de registros.** Como `SCORE_J1` y `SCORE_J2` salen directo de flip-flops, los pines del marcador nunca muestran valores intermedios ni pulsos falsos mientras cambia el puntaje.

## Cómo lo probamos

`tb_marcador_bcd` (F3) recorre las combinaciones de puntajes de los dos jugadores y comprueba que cada salida es igual a su entrada (356 comprobaciones). En la tarjeta, con el montaje de F6 y luego con la placa de F8, vimos el marcador avanzar durante partidas completas.

## Historia

Escrito en F3. Sus salidas estuvieron sin conectar en los tops de F4 y F5; en F6 las llevamos a pines con [`pong_f6_integracion_top`](pong_f6_integracion_top.md).
