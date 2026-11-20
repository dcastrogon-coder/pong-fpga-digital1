# Fases del proyecto

Desarrollamos el Pong siguiendo la ruta de nuestra guía metodológica ([`documentos_base/guia_metodologica.pdf`](../documentos_base/guia_metodologica.pdf)):

```
Requisitos → Modelo lógico → RTL → Simulación → Síntesis → Hardware
```

Cada fase tiene su carpeta con el documento que entregamos y la evidencia que la respalda. Las fechas son las de los documentos y de los archivos de cada fase.

| Fase | Contenido | Fecha | Punto de control | Evidencia principal |
|------|-----------|-------|:----------------:|---------------------|
| [F0](F0_especificacion/) | Especificación funcional, rev. 1.2 (con pausa manual) | 2 nov 2026 | PC0 | Reglas, requisitos R01–R12, FSM de 6 estados |
| [F1](F1_arquitectura/) | Arquitectura por bloques, rev. 1.1 | 2 nov 2026 | PC1 | Contratos de entradas y salidas de 13 módulos |
| [F2](F2_diseno_logico/) | Diseño lógico formal, rev. 1.2 | 2 nov 2026 | PC1 | Tablas de verdad y de transición, ecuaciones, FSM del juego y del transmisor |
| [F3](F3_rtl_simulacion/) | RTL en Verilog y simulación modular | 3 nov 2026 | PC2–PC3 | 15 archivos RTL, 19 testbenches, 49/49 comprobaciones de integración, síntesis sin errores |
| [F4](F4_interfaz_visual/) | Interfaz visual con las dos matrices MAX7219 | 7 nov 2026 | PC4 | Compilación completa, programación por JTAG, foto de la matriz |
| [F5](F5_controles_cableados/) | Controles cableados y validación física del juego | 14 nov 2026 | PC5 | Juego completo en la tarjeta, pelota diagonal, 18 bancos de prueba vigentes (12/12, 14/14, 28/28) |
| [F6](F6_integracion_montaje/) | Integración del marcador de 7 segmentos, síntesis y montaje | 14 nov 2026 | PC5–PC6 | Partida real 9–6, victoria, RESET y nueva partida; *slack* positivo |
| [F7](F7_informe_protoboard/) | Informe técnico del funcionamiento en protoboard | 15 nov 2026 | PC6 | Explicación lógica y física del prototipo |
| [F8](F8_pcb_kicad/) | Placa principal en KiCad | nov 2026 | — | Esquema, trazado, placa fabricada y soldada; controles en protoboard; video de demostración |

Los informes que pidió el profesor los armamos a partir de estas fases y están en [`informes/`](../informes/).

## Cómo cambió el diseño entre fases

Dejamos escritos los cambios para que se vea por qué el prototipo final no es idéntico a la propuesta:

| Aspecto | Propuesta / F0–F2 | Prototipo final (F5–F6) | Fase del cambio |
|---------|-------------------|--------------------------|:---------------:|
| Controles de los jugadores | Inalámbricos (RF) | Cableados con señal DETECT de conexión | F5 |
| Movimiento de la pelota | X cada 200 ms, Y cada 400 ms (bit PHASE) | Diagonal: X e Y cada 200 ms | F5 |
| Orientación de las matrices | Bit 7 = columna izquierda, fila 0 = registro 1 | Bit 0 = columna izquierda, fila 0 = registro 8 | F4 |
| Adaptador de niveles | SN74AHCT125 | Dos SN74HCT245N habilitados con 2N3904 | F4–F6 |
| Marcador | 2 displays con decodificador por definir | 2 × CD4511BE + 2 × 5161AS de cátodo común | F6 |
| Configuración de la FPGA | — | Por JTAG (volátil) | F6 |
| Montaje | Protoboard (F4–F7) | Placa impresa para matrices, búferes y marcador; controles en protoboard | F8 |
