# Pong en FPGA con matriz LED 8 × 16 y controles inalámbricos

**Proyecto final · Electrónica Digital 1**
Universidad Nacional de Colombia, Sede Bogotá · Departamento de Ingeniería Eléctrica y Electrónica

| Integrante | Correo |
|------------|--------|
| Daniel Felipe Castro González | dcastrogon@unal.edu.co |
| Juan David Ortiz Muñoz | juaortizmu@unal.edu.co |
| David Eduardo Chivata Arias | dchivata@unal.edu.co |

![Partida simulada](docs/img/partida_simulada.gif)

*Partida simulada: lo que se ve es el contenido de los registros de dos modelos de MAX7219 después de recibir las tramas seriales de nuestro diseño, es decir, lo que mostrarían los LEDs.*

---

## ¿Qué es esto?

Un Pong para dos jugadores hecho **solo con lógica digital** (sin Arduino ni ESP32) sobre una FPGA **Intel/Altera Cyclone IV E EP4CE10E22C8N**, descrito en Verilog HDL para Quartus II.

* La cancha es una matriz LED de **8 × 16** armada con dos módulos 8 × 8, cada uno con su **MAX7219**, conectados en cascada.
* Cada jugador tiene un **control inalámbrico** con dos botones: subir y bajar.
* El marcador va en **dos displays de siete segmentos**, uno por jugador.
* START y RESET están en los pulsadores de la tarjeta.

Seguimos al pie de la letra la ruta que propusimos en nuestra guía metodológica:

```
Requisitos → Modelo lógico → RTL → Simulación → Síntesis → Hardware
```

Por eso este repositorio tiene primero la especificación y las fichas de diseño (tablas de verdad, tablas de transición, ecuaciones y máquinas de estados), y solo después el Verilog con sus bancos de prueba.

## Estado del proyecto

| Punto de control | Descripción | Estado |
|------------------|-------------|--------|
| PC0 | Reglas, parámetros y señales documentados | ✅ [`docs/especificacion.md`](docs/especificacion.md), [`docs/decisiones.md`](docs/decisiones.md) |
| PC1 | Tablas, expresiones y diagramas por bloque | ✅ [`docs/diseno_logico.md`](docs/diseno_logico.md) |
| PC2 | Testbenches de cada módulo, incluidos límites y casos anómalos | ✅ 10 testbenches, todos pasan |
| PC3 | Juego y modelo del MAX7219 coherentes durante una partida | ✅ `tb_integracion`: partida completa, 0 diferencias |
| PC4 | Síntesis en Quartus, pines, temporización y voltajes | 🟡 Proyecto listo y revisado con Yosys; faltan los pines reales de la tarjeta |
| PC5 | Montaje progresivo | ⏳ Plan y lista de revisión en [`docs/hardware.md`](docs/hardware.md) |
| PC6 | Validación final | ⏳ |

## Cómo está organizado

```
pong-fpga-digital1/
├── rtl/                      Descripción del hardware (lo que va a la FPGA)
│   ├── pong_top.v            Módulo superior: solo interconexión
│   ├── entradas.v            Sincronización, antirrebote y validación RF
│   ├── antirrebote.v
│   ├── generador_ticks.v     1 ms, paso de la pelota y parpadeo
│   ├── paletas.v             Posición de una paleta (se instancia 2 veces)
│   ├── colisiones.v          Lógica combinacional de rebotes y goles
│   ├── pelota.v              Registro de la pelota
│   ├── puntaje.v             Marcador 0-9 con saturación
│   ├── control_juego.v       FSM general (ESPERA, JUEGO, PUNTO, PAUSA, FIN)
│   ├── imagen.v              Imagen 8 x 16 y mapeo a registros del MAX7219
│   ├── max7219_tx.v          FSM y transmisor serial para 2 MAX7219
│   └── siete_segmentos.v     Decodificador del marcador
├── tb/                       Bancos de prueba autoverificados
│   ├── modelo_max7219.v      Modelo del chip escrito desde la hoja de datos
│   ├── modelo_referencia.vh  Modelo independiente del movimiento de la pelota
│   └── tb_*.v                Un testbench por bloque + integración
├── sim/
│   ├── correr_todo.sh        Corre todas las pruebas
│   └── logs/                 Evidencia: resultado de cada simulación
├── quartus/                  Proyecto de Quartus II (.qpf, .qsf, .sdc)
├── scripts/                  Animación, cronograma y revisión con Yosys
└── docs/                     Especificación, diseño lógico, verificación, hardware
```

## Cómo correr las simulaciones

Necesitamos [Icarus Verilog](https://steveicarus.github.io/iverilog/) (versión 11 o más reciente). En Ubuntu o en WSL:

```bash
sudo apt install iverilog gtkwave
bash sim/correr_todo.sh             # todas las pruebas (~1 minuto)
bash sim/correr_todo.sh max7219     # solo una
gtkwave sim/tb_max7219.vcd          # para ver las ondas
```

Salida esperada:

```
================ RESUMEN ================
  RESULTADO tb_colisiones: PASA (92160 verificaciones)
  RESULTADO tb_paletas: PASA (15 verificaciones)
  RESULTADO tb_pelota: PASA (12107 verificaciones)
  RESULTADO tb_puntaje: PASA (11 verificaciones)
  RESULTADO tb_control_juego: PASA (22 verificaciones)
  RESULTADO tb_entradas: PASA (18 verificaciones)
  RESULTADO tb_generador_ticks: PASA (8 verificaciones)
  RESULTADO tb_imagen: PASA (8649 verificaciones)
  RESULTADO tb_siete_segmentos: PASA (48 verificaciones)
  RESULTADO tb_max7219: PASA (20 verificaciones)
  RESULTADO tb_integracion: PASA (26 verificaciones)
Pasan: 11   Fallan: 0
```

Para regenerar las imágenes de la documentación (necesita Python con Pillow y Matplotlib):

```bash
python3 scripts/animar_partida.py          # GIF de la partida (usa sim/partida.txt)
python3 scripts/cronograma_max7219.py      # diagrama DIN / CLK_LED / LOAD
```

GitHub corre las mismas pruebas cada vez que subimos cambios (pestaña *Actions*).

## Cómo compilar en Quartus II

1. Abrir `quartus/pong.qpf`.
2. **Antes de programar**, revisar `quartus/pong.qsf`: los pines de reloj, pulsadores y LEDs son tentativos y los de los periféricos están comentados hasta verificar el esquema de la tarjeta y la tensión de cada banco (ver [`docs/hardware.md`](docs/hardware.md)).
3. Ajustar en `rtl/pong_top.v` los parámetros de hardware si hace falta (polaridades, orientación de la matriz, modo RF).
4. *Processing → Start Compilation* y programar con el USB-Blaster.

### Parámetros que se ajustan sin tocar la lógica

| Parámetro | Por defecto | Para qué |
|-----------|-------------|----------|
| `CLK_HZ` | 50 000 000 | frecuencia real del oscilador |
| `TRANSPONER`, `INV_BITS`, `INV_DIGITOS` | 0, 0, 0 | orientación de los LEDs dentro de cada módulo |
| `MODULO_CERCANO` | 0 | qué mitad muestra el módulo conectado a DIN |
| `SEG_ACTIVO_BAJO` | 1 | displays de ánodo común (1) o cátodo común (0) |
| `CTRL_ACTIVO_BAJO` | 0 | polaridad de las salidas del receptor |
| `USAR_VT` | 1 | 0 para probar con botones cableados |
| `PAUSAR_SIN_ENLACE` | 1 | 0 si los transmisores solo emiten al presionar |
| `PUNTOS_VICTORIA` | 9 | puntos para ganar (máximo 9) |

## Reglas del juego (resumen)

* La pelota se mueve en diagonal; cada 3 rebotes en paleta acelera (260 → 200 → 150 → 110 ms por casilla).
* Si la pelota golpea la fila de arriba de la paleta sale hacia arriba; la de abajo, hacia abajo; el centro conserva la dirección.
* Si la paleta no cubre la fila de la pelota es punto para el rival. Pausa de 1 s y saque hacia quien perdió.
* Gana el primero en llegar a 9: su mitad de pantalla y su display titilan.
* START inicia, pausa y reanuda. Si se cae la señal de un control, el juego se pausa solo.

Las reglas completas están en [`docs/especificacion.md`](docs/especificacion.md).

## Documentación

* [`docs/especificacion.md`](docs/especificacion.md): reglas, entradas/salidas y requisitos R01-R10.
* [`docs/decisiones.md`](docs/decisiones.md): registro de decisiones y de los errores que nos encontró la simulación.
* [`docs/diseno_logico.md`](docs/diseno_logico.md): fichas de cada bloque con tablas de verdad, tablas de transición, ecuaciones y diagramas de estados.
* [`docs/verificacion.md`](docs/verificacion.md): matriz requisito–prueba y resultados.
* [`docs/hardware.md`](docs/hardware.md): niveles lógicos, conexiones, presupuesto de corriente y secuencia de pruebas físicas.

## Referencias

1. M. M. Mano y M. D. Ciletti, *Digital Design*, 5.ª ed. Pearson, 2013.
2. R. J. Tocci, N. S. Widmer y G. L. Moss, *Digital Systems: Principles and Applications*, 11.ª ed. Pearson, 2011.
3. S. Brown y Z. Vranesic, *Fundamentals of Digital Logic with Verilog Design*, 3.ª ed. McGraw-Hill, 2014.
4. Intel/Altera, *Cyclone IV Device Handbook*.
5. Analog Devices/Maxim Integrated, *MAX7219/MAX7221: Serially Interfaced, 8-Digit LED Display Drivers*, hoja de datos.
6. Texas Instruments, *SN74AHCT125: Quadruple Bus Buffer Gates With 3-State Outputs*, hoja de datos.
