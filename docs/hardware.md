# Interfaz eléctrica y montaje (Fase 5 · R10 · T10)

> Esta parte **no se puede verificar en simulación**. Lo que sigue es el plan de conexión y la lista de revisión que tenemos que cumplir antes de conectar cualquier periférico a la FPGA. Los valores marcados con ⚠ dependen de hardware que todavía no tenemos en la mano.

## 1. Niveles lógicos

La Cyclone IV E trabaja sus E/S en el estándar que tenga cada banco; en las tarjetas de desarrollo comunes los bancos del conector de expansión van a **3,3 V LVTTL**. Los pines de la Cyclone IV **no toleran 5 V**, así que la regla de oro del proyecto es: *nada de 5 V entra a un pin de la FPGA*.

| Línea | Sentido | Lado FPGA | Lado periférico | Solución |
|-------|---------|-----------|-----------------|----------|
| DIN, CLK_LED, LOAD | FPGA → módulo x4 | 3,3 V | MAX7219 a 5 V: necesita V_IH ≥ 3,5 V | **SN74AHCT125** alimentado a 5 V (entradas TTL: V_IH = 2 V, salida de 5 V) |
| J1/J2 UP, DOWN, VT | receptor → FPGA | 3,3 V | HT12D a 5 V saca 5 V | **SN74LVC245A** alimentado a 3,3 V (entradas toleran 5 V) o divisor 1 kΩ / 2 kΩ por línea ⚠ |
| SEG_J1, SEG_J2 | FPGA → display | 3,3 V | LED rojo, V_F ≈ 1,8 V | resistencia de 330 Ω por segmento: (3,3 − 1,8) / 330 ≈ 4,5 mA |
| LED[3:0] | FPGA → LEDs tarjeta | 3,3 V | ya en la tarjeta | nada |

Por qué el SN74AHCT125 y no conectar directo: el MAX7219 pide V_IH mínimo de 3,5 V con 5 V de alimentación; un 3,3 V de la FPGA queda por debajo y funcionaría "a veces", que es lo peor que puede pasar en una demostración. El '125 tiene 4 compuertas: usamos 3 y la cuarta queda con su entrada a tierra y su /OE en alto.

## 2. Pantalla: módulo MAX7219 x4

La pantalla definitiva es el [módulo matriz LED MAX7219 x4 de Mactrónica](https://www.mactronica.com.co/modulo-matriz-led-max7219-x4) (SKU LD059): cuatro matrices 8×8 con su MAX7219 cada una, ya encadenadas en una sola placa de unos 13,2 × 3,2 cm, alimentada a 5 V. Para nosotros es como tener cuatro chips en cascada con **un solo conector de entrada**:

| Pin del módulo | Conectar a | Nota |
|----------------|-----------|------|
| VCC | 5 V de la fuente externa | no del regulador de la tarjeta FPGA |
| GND | tierra común | |
| DIN | salida 1Y del SN74AHCT125 | viene de `DIN` |
| CS | salida 3Y del SN74AHCT125 | es nuestra señal `LOAD` (en el MAX7219 se llama LOAD/CS) |
| CLK | salida 2Y del SN74AHCT125 | viene de `CLK_LED` |

```
FPGA (3,3 V)            SN74AHCT125 (Vcc = 5 V)          Módulo MAX7219 x4 (5 V)
  DIN ────────────────── 1A → 1Y ────────────────────── DIN ─► [chip 0]→[chip 1]→[chip 2]→[chip 3]
  CLK_LED ────────────── 2A → 2Y ────────────────────── CLK      (la cadena ya viene hecha en la placa)
  LOAD ───────────────── 3A → 3Y ────────────────────── CS
                         1OE, 2OE, 3OE a GND              VCC 5 V, GND común
```

* En la placa, el chip 0 es el que queda junto al conector de entrada. Según hacia dónde se ponga el módulo, ese chip quedará del lado de J1 o del lado de J2. Por defecto suponemos que queda a la izquierda (lado de J1); si queda a la derecha se pone `MODULO_CERCANO = 1` en `pong_top`, sin recablear.
* La página del producto no dice la orientación de las matrices ni de qué lado queda la entrada. Por eso agregamos el **patrón de calibración**: se sostiene RESET y cada matriz muestra una "Γ" con la esquina arriba a la izquierda y un brazo horizontal que crece de izquierda a derecha (2, 3, 4 y 5 LEDs). Si algo se ve girado o en espejo se ajusta `TRANSPONER`, `INV_BITS` o `INV_DIGITOS` (ver ficha 7 de `diseno_logico.md`).
* La página tampoco aclara si el módulo trae conector de salida. Si lo trae, no hace falta usarlo.
* **Tierra común** entre la tarjeta FPGA, la fuente de 5 V, el '125, el módulo y los receptores. Sin esto nada de lo anterior sirve.
* Un capacitor de 100 nF junto al '125 y uno de 10 µF + 100 nF en la entrada de 5 V del módulo, lo más cerca posible del conector.
* Si en algún momento se quisiera volver a dos matrices sueltas, basta `ANCHO = 16`: el diseño y las pruebas existen para las dos versiones.

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

Estimación a confirmar con multímetro (prueba física #2 con "todo encendido"). Con cuatro chips en vez de dos, el peor caso se duplica:

| Carga | Normal (juego) | Peor caso |
|-------|----------------|-----------|
| Módulo x4, brillo 0x04 | ~45 mA (7-10 LEDs + reposo de 4 chips) | ~400 mA (256 LEDs, brillo 9/32) |
| Módulo x4, brillo 0x0F | — | hasta ~1,3 A según hoja de datos y R_SET de la placa |
| 2 receptores ASK + HT12D | ~10 mA | ~10 mA |
| SN74AHCT125 | < 1 mA | < 1 mA |
| **Total** | **~55 mA** | **~1,3 A** |

Con una fuente de **5 V / 2 A** quedamos cubiertos incluso si alguien sube el brillo al máximo. Un puerto USB de computador (500 mA) alcanza para jugar con el brillo de fábrica (0x04), pero no para el patrón "todo encendido" con brillo alto. No alimentar el módulo desde el regulador de la tarjeta FPGA.

Los displays de marcador se alimentan desde 3,3 V: 14 segmentos × 4,5 mA ≈ 63 mA en el peor caso (dos "8"), repartidos entre pines de bancos distintos para no pasar el límite por banco ⚠.

## 5. Lista de revisión T10 (antes de PC4)

- [ ] Esquema de la tarjeta: reloj (pin y frecuencia), pulsadores, LEDs y conector de expansión.
- [ ] Tensión de cada banco usado (VCCIO) medida con multímetro.
- [ ] Pines elegidos en `quartus/pong.qsf` y reporte de pines de Quartus revisado.
- [ ] '125 alimentado a 5 V y verificado con la FPGA sin módulos conectados (salida en 5 V con osciloscopio).
- [ ] Ninguna línea de 5 V llega a la FPGA (medir cada entrada con el receptor encendido).
- [ ] Tierras comunes.
- [ ] Corriente total medida con todo encendido. El peor caso real es el modo *display test* del MAX7219 (256 LEDs a brillo máximo); para medirlo basta cambiar temporalmente la palabra `0x0F00` por `0x0F01` en `max7219_tx.v`.
- [ ] Resistencias de los displays y corriente por banco.

## 6. Secuencia física de pruebas (de la guía, Sección X-B)

1. Tarjeta sola: verificar alimentación, programar y ver los LEDs de estado.
2. Módulo x4 conectado y RESET sostenido: el patrón de calibración debe verse como en la ficha 7 de `diseno_logico.md`. Aquí se ajustan `TRANSPONER`, `INV_BITS`, `INV_DIGITOS` y `MODULO_CERCANO`. Al soltar RESET y presionar START, la escena de juego debe parecerse a `docs/img/pantalla_simulada.png`.
3. Un dígito correcto en cada display de marcador (ajustar `SEG_ACTIVO_BAJO`).
4. Los cuatro comandos con los pulsadores de la tarjeta (`USAR_VT = 0`).
5. Receptores inalámbricos, incluyendo apagar un transmisor para probar la pérdida de enlace.
6. Partidas completas, registrando fallos y comparando contra los requisitos.
