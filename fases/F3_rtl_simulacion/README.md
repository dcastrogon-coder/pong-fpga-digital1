# F3 · Implementación RTL y verificación funcional

📄 [`F3_implementacion_rtl_y_verificacion.pdf`](F3_implementacion_rtl_y_verificacion.pdf) · 3 de noviembre de 2026 · **PC2–PC3**

* 15 archivos Verilog sintetizables integrados en `pong_top` (ahora en [`fpga/rtl/`](../../fpga/rtl/)).
* 19 testbenches: 14 modulares y 5 de integración (en [`fpga/tb/`](../../fpga/tb/)).
* Questa: **49/49** comprobaciones de integración.
* Quartus Prime 25.1 Lite, *Analysis & Synthesis*: 0 errores, 2 advertencias, 560 celdas lógicas ([`quartus_reportes/`](quartus_reportes/)).

| Testbench de integración | Qué prueba | Resultado |
|--------------------------|------------|:---------:|
| `tb_pong_integracion` | Arranque, RESET, START, pausa manual, refresco en pausa, timeout RF y rearme | 9/9 |
| `tb_pong_goles_victoria` | Diez goles, marcador 9:1, FIN, RESET a 0:0 | 13/13 |
| `tb_pong_colisiones_rebotes` | Rebotes en paletas y paredes sin goles | 8/8 |
| `tb_pong_recuperacion_fallos` | Estados y registros inválidos, alarma del transmisor | 11/11 |
| `tb_pong_max7219_integrado` | 14 instrucciones + 2 cuadros, 30 tramas de 32 bits, 960 flancos | 8/8 |

En [`evidencias/`](evidencias/) están las capturas de onda y las transcripciones de Questa de cada bloque (B1–B10) y de los cinco bancos de integración.

Las mismas pruebas se pueden repetir con Icarus Verilog: `bash fpga/sim/correr_pruebas.sh`.
