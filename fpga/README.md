# Código Verilog y proyecto de Quartus

Esta carpeta tiene el núcleo del Pong tal como quedó después de **F4**: los 15 módulos de F3 con las dos correcciones de orientación de F4, más el top de la prueba visual.

> ⚠️ El top final del prototipo (`pong_f6_integracion_top.v`) y el núcleo de F5 (`pong_f5_core.v`, con los mandos cableados y el movimiento diagonal) todavía no están en el repositorio. Ver [`fases/F5_controles_cableados/`](../fases/F5_controles_cableados/).

![Jerarquía de módulos](../informes/figuras/fig_rtl.png)

La máquina de estados del juego está en [`fig_fsm`](../informes/figuras/fig_fsm.png).

## Archivos

| Archivo | Bloque | Qué hace |
|---------|--------|----------|
| `rtl/pong_top.v` | Integración | Conecta todos los módulos; parámetros de tiempo para 50 MHz |
| `rtl/boton_evento.v` | Entradas | Sincroniza, filtra (20 ms) y da un pulso por pulsación; se usa para START y PAUSE |
| `rtl/reset_seguro.v` | Seguridad | Reset de arranque (`POR_REQ`) y RESET físico con liberación filtrada |
| `rtl/supervisor_rf.v` | Entradas | Comandos y vigencia de los dos enlaces (timeout de 500 ms) |
| `rtl/control_juego.v` | Control | FSM de seis estados y pulsos de captura de gol, punto, centrado y rearme |
| `rtl/temporizadores.v` | Temporización | Pulsos de pelota (200 ms) y paletas (250 ms) |
| `rtl/paletas.v` | Motor | Posición de las paletas y posición efectiva para las colisiones |
| `rtl/pelota.v` | Motor | Posición, dirección y fase de la pelota |
| `rtl/colisiones.v` | Motor | Impactos y goles de cada jugador |
| `rtl/puntaje.v` | Marcador | Contadores 0–9, anotador y predicción de victoria |
| `rtl/marcador_bcd.v` | Marcador | Buses BCD hacia los decodificadores externos |
| `rtl/captura_imagen.v` | Video | Instantánea de 13 bits de las posiciones |
| `rtl/imagen.v` | Video | Byte de cada matriz para cada fila |
| `rtl/transmisor_max7219.v` | Video | Inicialización y envío serial a los dos MAX7219 en cascada (FSM de 13 estados) |
| `rtl/supervisor_fallos.v` | Seguridad | Detecta estados y registros inválidos y fuerza la reinicialización |
| `rtl/pong_f4_visual_top.v` | Prueba F4 | Top de la prueba visual: deja entradas en reposo y solo saca DIN, CLK_LED y LOAD |
| `tb/tb_*.v` | Pruebas | 14 testbenches modulares y 5 de integración |
| `pong_f3.qpf`, `pong_top.qsf`, `pong_f3.sdc` | Quartus | Proyecto (revisión `pong_top`, top `pong_f4_visual_top`), pines y reloj de 20 ns |

## Correr las pruebas

Las simulaciones originales se hicieron en Questa. Para repetirlas sin instalar nada pesado usamos Icarus Verilog:

```bash
sudo apt install iverilog        # en Ubuntu o WSL
cd fpga
bash sim/correr_pruebas.sh
```

Resultado actual (también lo corre GitHub en cada cambio, pestaña *Actions*):

```
=========================== RESUMEN ===========================
  PASA       tb_boton_evento   OK: INIT cancela pulsacion pendiente
  PASA       tb_captura_imagen   PRUEBAS SUPERADAS: 13
  PASA       tb_colisiones   PRUEBAS SUPERADAS: 87823
  PASA       tb_control_juego   COMBINACIONES FSM OK: 512
  PASA       tb_imagen   TOTAL VERIFICADO: 65546
  PASA       tb_marcador_bcd   TOTAL DE COMPROBACIONES: 356
  PASA       tb_paletas   PRUEBAS SUPERADAS: 14
  PASA       tb_pelota   PRUEBAS SUPERADAS: 39
  PASA       tb_pong_colisiones_rebotes   COMPROBACIONES: 8 / 8
  PASA       tb_pong_goles_victoria   COMPROBACIONES: 13 / 13
  PASA       tb_pong_integracion   COMPROBACIONES DE INTEGRACION: 9 / 9
  PASA       tb_pong_max7219_integrado   COMPROBACIONES: 8 / 8
  PASA       tb_pong_recuperacion_fallos   COMPROBACIONES: 11 / 11
  PASA       tb_puntaje   PRUEBAS SUPERADAS: 37
  PASA       tb_reset_seguro   COMPROBACIONES SUPERADAS: 47
  PASA       tb_supervisor_fallos   TOTAL VERIFICADO: 363
  PASA       tb_supervisor_rf   OK: Expiracion independiente J1
  PASA       tb_temporizadores   OK: Retencion final | CB=0 CP=0
  PASA       tb_transmisor_max7219   OK: Cuadro 2 Fila 8/8 WORD=01810100
Pasan: 19   Fallan: 0
```

Los registros quedan en [`sim/resultados/`](sim/resultados/).

## Compilar y programar en Quartus

1. Abrir `pong_f3.qpf` con Quartus Prime (usamos la 25.1 Lite).
2. *Processing → Start Compilation*.
3. *Tools → Programmer*, USB-Blaster en modo JTAG, cargar `output_files/pong_top.sof` y *Start*.

Con este top solo se ven las paletas y la pelota en su posición inicial (prueba de F4). Para el juego completo con mandos y marcador hace falta el top de F6. La secuencia de encendido y las conexiones están en [`hardware/`](../hardware/).
