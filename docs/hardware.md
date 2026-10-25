# Interfaz eléctrica y montaje (Fase 5 · R10 · T10)

> Esta parte **no se puede verificar en simulación**. Lo que sigue es el plan de conexión y la lista de revisión que tenemos que cumplir antes de conectar cualquier periférico a la FPGA. Los valores marcados con ⚠ dependen de hardware que todavía no tenemos en la mano.

## 1. Niveles lógicos

La Cyclone IV E trabaja sus E/S en el estándar que tenga cada banco; en las tarjetas de desarrollo comunes los bancos del conector de expansión van a **3,3 V LVTTL**. Los pines de la Cyclone IV **no toleran 5 V**, así que la regla de oro del proyecto es: *nada de 5 V entra a un pin de la FPGA*.

| Línea | Sentido | Lado FPGA | Lado periférico | Solución |
|-------|---------|-----------|-----------------|----------|
| DIN, CLK_LED, LOAD | FPGA → MAX7219 | 3,3 V | MAX7219 a 5 V: necesita V_IH ≥ 3,5 V | **SN74AHCT125** alimentado a 5 V (entradas TTL: V_IH = 2 V, salida de 5 V) |
| J1/J2 UP, DOWN, VT | receptor → FPGA | 3,3 V | HT12D a 5 V saca 5 V | **SN74LVC245A** alimentado a 3,3 V (entradas toleran 5 V) o divisor 1 kΩ / 2 kΩ por línea ⚠ |
| SEG_J1, SEG_J2 | FPGA → display | 3,3 V | LED rojo, V_F ≈ 1,8 V | resistencia de 330 Ω por segmento: (3,3 − 1,8) / 330 ≈ 4,5 mA |
| LED[3:0] | FPGA → LEDs tarjeta | 3,3 V | ya en la tarjeta | nada |

Por qué el SN74AHCT125 y no conectar directo: el MAX7219 pide V_IH mínimo de 3,5 V con 5 V de alimentación; un 3,3 V de la FPGA queda por debajo y funcionaría "a veces", que es lo peor que puede pasar en una demostración. El '125 tiene 4 compuertas: usamos 3 y la cuarta queda con su entrada a tierra y su /OE en alto.

## 2. Conexiones

```
FPGA (3,3 V)                 SN74AHCT125 (Vcc = 5 V)          Módulo 1 (izq.)       Módulo 2 (der.)
  DIN ─────────────────────── 1A → 1Y ─────────────────────── DIN ─ DOUT ─────────── DIN
  CLK_LED ─────────────────── 2A → 2Y ─────────────────────── CLK ─────┬──────────── CLK
  LOAD ────────────────────── 3A → 3Y ─────────────────────── CS  ─────┴──────────── CS
                              1OE, 2OE, 3OE a GND                VCC 5 V, GND común
```

* Los módulos genéricos ya traen su conector de salida (DOUT, CLK, CS) para encadenarlos: el módulo que recibe DIN de la FPGA es el **cercano** y por defecto muestra la mitad izquierda (columnas 0-7, lado de J1). Si queda al revés, se cambia `MODULO_CERCANO` en `pong_top` sin recablear.
* **Tierra común** entre la tarjeta FPGA, la fuente de 5 V, el '125, los módulos y los receptores. Sin esto nada de lo anterior sirve.
* Un capacitor de 100 nF junto al '125 y uno de 10 µF + 100 nF en la entrada de 5 V de cada módulo (los módulos suelen traerlos; revisar).

## 3. Controles inalámbricos ⚠

Nuestra propuesta, pendiente de comprar y probar:

* **Transmisor:** HT12E + módulo ASK. Datos D8 = subir, D9 = bajar (D10 y D11 libres). Pulsadores a GND con la entrada del HT12E (pull-up interno según hoja de datos ⚠).
* **Receptor:** módulo ASK + HT12D. Salidas D8, D9 y VT hacia la FPGA (a través del adaptador de nivel).
* **Direcciones:** cada pareja con su propia dirección en A0-A7 (por ejemplo J1 = 0x55, J2 = 0xAA).
* **Frecuencias distintas:** con modulación ASK dos transmisores en la misma frecuencia **se interfieren** cuando emiten al tiempo, aunque tengan direcciones distintas. Por eso recomendamos **315 MHz para J1 y 433 MHz para J2**.
* **Modo de transmisión:** si el TE del HT12E va a tierra (transmite todo el tiempo), VT = 1 significa enlace y dejamos `PAUSAR_SIN_ENLACE = 1`. Si el transmisor solo emite mientras se presiona, VT vuelve a 0 en reposo, y hay que poner `PAUSAR_SIN_ENLACE = 0` (D-24).
* **Polaridad:** si las salidas del HT12D quedan en 0 al presionar (depende de cómo cableemos el HT12E), cambiar `CTRL_ACTIVO_BAJO = 1`.
* **Sin RF todavía:** para la prueba física #4 se pueden usar los pulsadores de la tarjeta con `USAR_VT = 0` y `CTRL_ACTIVO_BAJO = 1` (ver comentario en `quartus/pong.qsf`).

## 4. Presupuesto de corriente (5 V) ⚠

Estimación a confirmar con multímetro (prueba física #2 con "todo encendido"):

| Carga | Normal (juego) | Peor caso |
|-------|----------------|-----------|
| 2 módulos MAX7219, brillo 0x04 | ~30 mA (7-10 LEDs) | ~200 mA (128 LEDs, brillo 4/16) |
| 2 módulos, brillo 0x0F | — | hasta ~650 mA según hoja de datos y R_SET del módulo |
| 2 receptores ASK + HT12D | ~10 mA | ~10 mA |
| SN74AHCT125 | < 1 mA | < 1 mA |
| **Total** | **~40 mA** | **~650 mA** |

Con una fuente de **5 V / 1 A** quedamos cubiertos incluso si alguien sube el brillo al máximo. No alimentar las matrices desde el regulador de la tarjeta FPGA.

Los displays de marcador se alimentan desde 3,3 V: 14 segmentos × 4,5 mA ≈ 63 mA en el peor caso (dos "8"), repartidos entre pines de bancos distintos para no pasar el límite por banco ⚠.

## 5. Lista de revisión T10 (antes de PC4)

- [ ] Esquema de la tarjeta: reloj (pin y frecuencia), pulsadores, LEDs y conector de expansión.
- [ ] Tensión de cada banco usado (VCCIO) medida con multímetro.
- [ ] Pines elegidos en `quartus/pong.qsf` y reporte de pines de Quartus revisado.
- [ ] '125 alimentado a 5 V y verificado con la FPGA sin módulos conectados (salida en 5 V con osciloscopio).
- [ ] Ninguna línea de 5 V llega a la FPGA (medir cada entrada con el receptor encendido).
- [ ] Tierras comunes.
- [ ] Corriente total medida con "todo encendido".
- [ ] Resistencias de los displays y corriente por banco.

## 6. Secuencia física de pruebas (de la guía, Sección X-B)

1. Tarjeta sola: verificar alimentación, programar y ver los LEDs de estado.
2. Un módulo LED con un patrón fijo, después los dos en cascada. Aquí se ajustan `TRANSPONER`, `INV_BITS`, `INV_DIGITOS` y `MODULO_CERCANO` hasta que la escena de prueba se vea igual que en `docs/img/pantalla_simulada.png`.
3. Un dígito correcto en cada display de marcador (ajustar `SEG_ACTIVO_BAJO`).
4. Los cuatro comandos con los pulsadores de la tarjeta (`USAR_VT = 0`).
5. Receptores inalámbricos, incluyendo apagar un transmisor para probar la pérdida de enlace.
6. Partidas completas, registrando fallos y comparando contra los requisitos.
