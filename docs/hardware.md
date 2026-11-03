# Interfaz eléctrica y montaje (Fase 5 · R10 · T10)

> Esta parte **no se puede verificar en simulación**. Lo que sigue es el plan de conexión y la lista de revisión que tenemos que cumplir antes de conectar cualquier periférico a la FPGA. Los valores marcados con ⚠ dependen de hardware que todavía no hemos medido.

## 0. La tarjeta: A-C4E6E10

Es una tarjeta de desarrollo con la **EP4CE10E22C8N** (la serigrafía dice "E6/E10" porque sirve para las dos variantes). Lo que trae y cómo lo usamos:

| Recurso de la tarjeta | Pines (serigrafía) | Uso en el proyecto |
|-----------------------|--------------------|--------------------|
| Oscilador 50 MHz (CLK_50M) | P23 | `CLK_SYS` |
| Reloj de usuario (CLK_USER) | P24 | sin usar |
| Pulsador K1 | nCONFIG | reprograma la FPGA: **no tocar durante la partida** |
| Pulsador K2 | P90 | `START_PIN` |
| Pulsador K3 | P91 | `RESET_PIN` (sostenido = patrón de calibración) |
| Pulsadores K4 / K5 | P87 (DEV-CLR) / P86 (DEV-OE) | sin usar; dejamos apagadas esas funciones en el `.qsf` |
| Display de 8 dígitos ("Nixie Tube"), segmentos | A P127, B P126, C P125, D P124, E P121, F P120, G P119, H P115 | `SEG[0..7]`: marcador y mensajes |
| Display de 8 dígitos, habilitación | BIT0 P128, BIT1 P129, BIT2 P132, BIT3 P133, BIT4 P135, BIT5 P136, BIT6 P137, BIT7 P138 | `DIG[0..7]` (BIT0 = derecha) |
| Buzzer (BELL) | P141 | `BUZZER` |
| DIP SW (8 interruptores) | P58, P59, P60, P64, P65, P66, P67, P68 | SW1 (P58) = sonido, SW2 (P59) = patrón de calibración |
| LEDs D3-D14 | D3 P72, D4 P73, D5 P74, D6 P80, D7 P83, D8 P84, D9 P77, D10 P76, D11 P75, D12 P71, D13 P70, D14 P69 | D3 jugando, D4 pausa, D5 enlace J1, D6 enlace J2 |
| Conector de expansión (3,3 V) | arriba: P28 P31 P33 P38 P43 P46 P50 P51 P53 P55 P88; abajo: P30 P32 P34 P39 P42 P44 P49 P52 P54 P89 | MAX7219 y receptores RF (ver abajo) |
| VGA, PS/2, LCD1602/12864, EEPROM 24C04, CH340 (USB-serial) | ver serigrafía | sin usar |

Pines que usamos del conector de expansión:

| Señal | Pin | Fila | Va a |
|-------|-----|------|------|
| `DIN` | P28 | arriba | SN74AHCT125 1A |
| `CLK_LED` | P31 | arriba | SN74AHCT125 2A |
| `LOAD` | P33 | arriba | SN74AHCT125 3A |
| `J1_UP` | P30 | abajo | receptor J1, D8 |
| `J1_DOWN` | P32 | abajo | receptor J1, D9 |
| `J1_VT` | P34 | abajo | receptor J1, VT |
| `J2_UP` | P42 | abajo | receptor J2, D8 |
| `J2_DOWN` | P44 | abajo | receptor J2, D9 |
| `J2_VT` | P49 | abajo | receptor J2, VT |

Los escogimos juntos para que el cableado quede ordenado: el MAX7219 en los tres primeros pines de arriba y cada jugador en un bloque de tres pines abajo, con un GND cerca.

Cosas a tener en cuenta de esta tarjeta:

* **Verificado contra el esquemático de la tarjeta** (A-C4E6 SCH, 2 nov 2026). Todo lo de la tabla de arriba coincide con la serigrafía:
  * Oscilador de 50 MHz en el pin 23 (CLK_50M) y uno de usuario en el 24.
  * **Todos los VCC_IO de la FPGA van a 3,3 V**, así que todos los bancos son de 3,3 V y el adaptador SN74AHCT125 hacia el MAX7219 sigue siendo obligatorio.
  * Display de 8 dígitos: ánodo común; cada dígito se habilita con un PNP (Q50-Q57) cuya base va al pin por 4,7 kΩ, así que **dígitos activos en bajo**. Los segmentos van al pin por 240 Ω, así que **segmentos activos en bajo**. BIT0 es el dígito de la derecha.
  * LEDs D3-D14: ánodo a 3,3 V por 680 Ω y cátodo al pin, así que **activos en bajo**.
  * DIP: pull-up de 4,7 kΩ y el interruptor a GND, así que **ON = 0**.
  * Pulsadores K1-K5: pull-up de 4,7 kΩ y a GND al presionar, así que **activos en bajo**. K1 es nCONFIG (reprograma la FPGA); K2 = P90, K3 = P91, K4 = P87, K5 = P86.
  * Buzzer: va de 5 V a un PNP (Q70) con la base al pin 141 por 4,7 kΩ. Se activa con 0. ⚠ Como el buzzer está a 5 V y el pin solo llega a 3,3 V, puede que no se apague del todo con 1: revisar que quede en silencio en reposo.
* **Ojo con dos pines del conector:**
  * **P88 y P89** (los del lado de "CLK-IN") son pines de reloj dedicados de la Cyclone IV y, según el manual, **solo sirven como entradas**. No se pueden usar para DIN, CLK_LED, LOAD ni segmentos. Confirmarlo en el Pin Planner de Quartus.
  * El pin **I/O58** del conector es el mismo del **DIP SW1**. Si se usa en el conector, el SW1 debe quedar en OFF.
* El conector solo tiene **3,3 V y GND**; no hay 5 V. El módulo MAX7219 x4 se alimenta con fuente aparte y se unen las tierras.
* La tarjeta advierte *"If you use mini USB, don't use DC5V input"*: alimentarla por una sola de las dos entradas.
* El cristal de 12 MHz que se ve en la placa es del CH340 (USB-serial), no de la FPGA.
* Con el display de la tarjeta ya no hacen falta displays externos: eso nos ahorra 14 pines, 14 resistencias y una compra (D-28).
* Las polaridades de `pong_top` (segmentos, dígitos, LEDs, DIP, buzzer: activos en bajo) son las que confirma el esquemático. Igual hay que mirarlas en la prueba física #3.


## 1. Niveles lógicos

La Cyclone IV E trabaja sus E/S en el estándar que tenga cada banco; en la A-C4E6E10 el conector de expansión es de **3,3 V LVTTL** (así lo marca la serigrafía). Los pines de la Cyclone IV **no toleran 5 V**, así que la regla de oro del proyecto es: *nada de 5 V entra a un pin de la FPGA*.

| Línea | Sentido | Lado FPGA | Lado periférico | Solución |
|-------|---------|-----------|-----------------|----------|
| DIN, CLK_LED, LOAD | FPGA → módulo x4 | 3,3 V | MAX7219 a 5 V: necesita V_IH ≥ 3,5 V | **SN74AHCT125** alimentado a 5 V (entradas TTL: V_IH = 2 V, salida de 5 V) |
| J1/J2 UP, DOWN, VT | receptor → FPGA | 3,3 V | HT12D a 5 V saca 5 V | **SN74LVC245A** alimentado a 3,3 V (entradas toleran 5 V) o divisor 1 kΩ / 2 kΩ por línea ⚠ |
| SEG, DIG, BUZZER, LED | FPGA → periféricos de la tarjeta | 3,3 V | ya en la tarjeta, con sus resistencias y transistores | nada |

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
* **Sin RF todavía:** para la prueba física #4 se conectan cuatro pulsadores entre los pines de los jugadores y GND, con `USAR_VT = 0`, `CTRL_ACTIVO_BAJO = 1` y los pull-up internos que están comentados en `quartus/pong.qsf`. Los pulsadores K2 y K3 de la tarjeta ya están ocupados con START y RESET.

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

El display de 8 dígitos, el buzzer y los LEDs van por la alimentación de la propia tarjeta; como el display está multiplexado, solo hay un dígito encendido a la vez.

## 5. Lista de revisión T10 (antes de PC4)

- [x] Tarjeta identificada (A-C4E6E10) y pines tomados de la serigrafía.
- [x] Pines del conector confirmados contra el esquemático (P28, P30-P34, P42, P44, P49).
- [ ] Continuidad de los nueve pines del conector de expansión que usamos (opcional, el esquemático ya coincide).
- [ ] Tensión de cada banco usado (VCCIO) medida con multímetro.
- [ ] Pines elegidos en `quartus/pong.qsf` y reporte de pines de Quartus revisado.
- [ ] '125 alimentado a 5 V y verificado con la FPGA sin módulos conectados (salida en 5 V con osciloscopio).
- [ ] Ninguna línea de 5 V llega a la FPGA (medir cada entrada con el receptor encendido).
- [ ] Tierras comunes.
- [ ] Corriente total medida con todo encendido. El peor caso real es el modo *display test* del MAX7219 (256 LEDs a brillo máximo); para medirlo basta cambiar temporalmente la palabra `0x0F00` por `0x0F01` en `max7219_tx.v`.
- [x] Polaridad del display de 8 dígitos, LEDs, DIP y pulsadores confirmada en el esquemático (activos en bajo).
- [ ] Verlo funcionar en la prueba física #3 y revisar que el buzzer quede en silencio en reposo.

## 6. Secuencia física de pruebas (de la guía, Sección X-B)

1. Tarjeta sola: verificar alimentación, programar y ver los LEDs de estado. El display debe decir `0 HOLA 0`.
2. Módulo x4 conectado y RESET sostenido: el patrón de calibración debe verse como en la ficha 7 de `diseno_logico.md`. Aquí se ajustan `TRANSPONER`, `INV_BITS`, `INV_DIGITOS` y `MODULO_CERCANO`. Al soltar RESET y presionar START, la escena de juego debe parecerse a `docs/img/pantalla_simulada.png`.
3. Display de la tarjeta: con el DIP 2 en ON deben verse los ocho `8.` encendidos; con el DIP 1 en ON y una partida, el buzzer debe pitar en cada rebote. Si el display se ve "al revés" (todo encendido menos lo que debería), cambiar `SEG_ACTIVO_BAJO` o `DIG_ACTIVO_BAJO`.
4. Los cuatro comandos con pulsadores conectados al conector de expansión (`USAR_VT = 0`, `CTRL_ACTIVO_BAJO = 1`, ver comentario en `quartus/pong.qsf`).
5. Receptores inalámbricos, incluyendo apagar un transmisor para probar la pérdida de enlace.
6. Partidas completas, registrando fallos y comparando contra los requisitos.
