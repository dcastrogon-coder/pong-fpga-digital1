# Pong para dos jugadores en FPGA

**Proyecto final · Electrónica Digital 1**
Universidad Nacional de Colombia, sede Bogotá · Departamento de Ingeniería Eléctrica y Electrónica

| Integrante | Correo |
|------------|--------|
| Juan David Ortiz Muñoz | juaortizmu@unal.edu.co |
| David Eduardo Chivata Arias | dchivata@unal.edu.co |
| Daniel Felipe Castro González | dcastrogon@unal.edu.co |

![Sistema completo en funcionamiento: tarjeta, placa principal con el marcador en 1–0, matrices y controles](fases/F8_pcb_kicad/foto_sistema_funcionando.jpg)

## De qué se trata

El proyecto está **completo y funcional**: hicimos un Pong para dos jugadores **solo con lógica digital** (sin Arduino ni ESP32) sobre una FPGA **Cyclone IV E EP4CE10E22C8N** en la tarjeta **A-C4E6E10**. Todo lo escribimos en Verilog y lo compilamos en Quartus Prime 25.1 Lite.

* El tablero es de **8 × 16 LED**: dos módulos FC-16 de 8 × 8 en cascada, con controlador GC7219C (compatible con MAX7219).
* Cada jugador mueve su paleta con un **mando cableado** (UP, DOWN y DETECT). Si un mando se desconecta, el juego se pausa.
* START, PAUSE y RESET van en pulsadores.
* El puntaje sale en BCD hacia **dos CD4511BE** y **dos displays 5161AS**. Gana el primero que llega a 9.
* Todas las salidas pasan de 3,3 V a 5 V por **dos SN74HCT245N**, que se habilitan con dos 2N3904 cuando la FPGA ya está configurada.
* Los búferes, el marcador y los conectores de las matrices van en una **placa impresa** que diseñamos en KiCad; los controles quedaron en protoboard.

![Arquitectura del sistema](informes/figuras/fig_sistema.png)

## Informes para el profesor

| Informe | Archivo |
|---------|---------|
| Informe de avance | [`informes/avance/informe_avance.pdf`](informes/avance/informe_avance.pdf) |
| Informe del Desafío | [`informes/desafio/informe_desafio.pdf`](informes/desafio/informe_desafio.pdf) |
| **Informe final completo** (F0–F8) | [`informes/final/informe_final.pdf`](informes/final/informe_final.pdf) |

Siguen la estructura que pidió el profesor. Las figuras y cómo volver a compilarlos están en [`informes/`](informes/).

## Estado por fase

Desarrollamos el proyecto con la ruta de nuestra [guía metodológica](documentos_base/guia_metodologica.pdf): *Requisitos → Modelo lógico → RTL → Simulación → Síntesis → Hardware*.

| Fase | Contenido | Estado |
|------|-----------|--------|
| [F0](fases/F0_especificacion/) | Especificación funcional, requisitos R01–R12 | Terminada |
| [F1](fases/F1_arquitectura/) | Arquitectura por bloques | Terminada |
| [F2](fases/F2_diseno_logico/) | Diseño lógico formal: tablas, ecuaciones y FSM | Terminada |
| [F3](fases/F3_rtl_simulacion/) | Verilog y simulación: 19 bancos de prueba, 49/49 comprobaciones de integración | Terminada |
| [F4](fases/F4_interfaz_visual/) | Las dos matrices funcionando en la tarjeta | Terminada |
| [F5](fases/F5_controles_cableados/) | Mandos cableados, movimiento diagonal, juego completo en la tarjeta | Terminada |
| [F6](fases/F6_integracion_montaje/) | Marcador de 7 segmentos, montaje completo; partida real hasta 9–6 | Terminada |
| [F7](fases/F7_informe_protoboard/) | Informe del funcionamiento en protoboard | Terminada |
| [F8](fases/F8_pcb_kicad/) | Placa principal en KiCad, fabricada y soldada | Terminada |

En el camino cambiamos algunas cosas de la propuesta (controles cableados en lugar de RF, pelota en diagonal, orientación de las matrices y adaptador de niveles). Las explicamos en [`fases/README.md`](fases/README.md).

## Cómo está organizado

```
pong-fpga-digital1/
├── documentos_base/   Propuesta corregida y guía metodológica
├── fases/             F0 a F8: documento de cada fase y su evidencia
├── fpga/
│   ├── docs/          Explicación de cada archivo de código
│   ├── rtl/           Módulos Verilog (diseño final de F6)
│   ├── tb/            35 bancos de prueba autoverificados
│   ├── sim/           Script para correr todas las pruebas y sus registros
│   └── *.qpf/.qsf/.sdc  Proyecto de Quartus
├── hardware/          Lista de componentes, conexiones pin a pin, encendido y apagado
└── informes/          Informe de avance, del Desafío y final, con sus figuras (LaTeX + PDF)
```

## Documentación del código

Cada archivo de código tiene su explicación en [`fpga/docs/`](fpga/docs/README.md): qué hace, sus puertos, cómo funciona por dentro, por qué lo hicimos así y cómo lo probamos. Ahí también explicamos el proyecto de Quartus, los bancos de prueba y la simulación automática, y seguimos una partida completa a través de los módulos.

## Cómo simular

```bash
sudo apt install iverilog      # Ubuntu o WSL
bash fpga/sim/correr_pruebas.sh
```

Deben pasar los 35 bancos de prueba. GitHub corre lo mismo cada vez que subimos algo (pestaña *Actions*). Más detalle en [`fpga/`](fpga/).

## Cómo compilar y programar

1. Abrir `fpga/pong_f3.qpf` en Quartus Prime.
2. *Processing → Start Compilation*. Debe terminar con 0 errores (665 elementos lógicos, 22 pines).
3. Encender **primero** la fuente de 5 V y **después** la tarjeta.
4. *Tools → Programmer*, USB-Blaster en JTAG, cargar `output_files/pong_top.sof` y *Start*.

Ojo: la configuración por JTAG se borra al apagar la tarjeta, así que toca programarla en cada encendido. Las conexiones y la secuencia completa de encendido y apagado las dejamos en [`hardware/`](hardware/).

El proyecto ya tiene como top `pong_f6_integracion_top`, es decir, el juego completo con mandos y marcador.

## Cómo trabajamos en el repositorio

Los tres somos colaboradores, así que cualquiera puede modificarlo.

* **Cambios pequeños:** en GitHub, abrir el archivo, tocar el lápiz (*Edit this file*) y escribir en *Commit changes* qué se cambió y por qué.
* **Cambios de código:**

  ```bash
  git clone https://github.com/dcastrogon-coder/pong-fpga-digital1.git
  cd pong-fpga-digital1
  git pull                          # siempre antes de empezar
  # ... editar ...
  bash fpga/sim/correr_pruebas.sh   # que todo siga pasando
  git add -A
  git commit -m "Qué cambiamos y por qué"
  git push
  ```

* Los comentarios del código van en primera persona del plural ("aquí calculamos...", "lo dejamos así porque...").
* Si cambiamos una regla, un pin o un componente, lo anotamos en [`fases/README.md`](fases/README.md).

## Referencias

1. M. M. Mano y M. D. Ciletti, *Digital Design*, 5.ª ed. Pearson, 2013.
2. R. J. Tocci, N. S. Widmer y G. L. Moss, *Digital Systems: Principles and Applications*, 11.ª ed. Pearson, 2011.
3. S. Brown y Z. Vranesic, *Fundamentals of Digital Logic with Verilog Design*, 3.ª ed. McGraw-Hill, 2014.
4. Intel/Altera, *Cyclone IV Device Handbook*.
5. Analog Devices/Maxim Integrated, *MAX7219/MAX7221*, hoja de datos.
6. Texas Instruments, *SN74HCT245* y *CD4511B*, hojas de datos.
