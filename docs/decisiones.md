# Registro de decisiones

Este es el registro que propusimos en la Sección XIII de la guía metodológica. Cada vez que cambiemos una regla del juego, una interfaz o un parámetro, lo anotamos aquí con su justificación y el requisito al que afecta. Si una decisión cambia, **no la borramos**: agregamos una nueva que la reemplace, para no perder la historia.

Responsable: cuando dice *Equipo* es porque lo acordamos entre los tres (Daniel Felipe Castro, Juan David Ortiz y David Chivata).

## Decisiones de la Fase 0 (reglas congeladas para PC0)

| ID | Fecha | Tema | Alternativas consideradas | Decisión | Justificación | Resp. | Req. |
|----|-------|------|---------------------------|----------|---------------|-------|------|
| D-01 | 2026-10-25 | Longitud de paleta | LP = 2, 3 o 4 | **LP = 3** | Con 8 filas, LP = 2 hacía casi imposible devolver la pelota y LP = 4 dejaba media pantalla tapada. Con 3 el juego queda parejo y la paleta tiene "centro", lo que habilita el efecto (D-05). | Equipo | R01, R02 |
| D-02 | 2026-10-25 | Posición inicial de paletas | Filas 2-4 o 3-5 | **YP = 2** (filas 2, 3 y 4) | No hay un centro exacto con LP = 3 en 8 filas; escogimos la de arriba y la dejamos igual para los dos jugadores. | Equipo | R06 |
| D-03 | 2026-10-25 | Pulsación sostenida | (a) un paso por tick fijo, (b) un paso por pulsación, (c) autorrepetición tipo teclado | **(c)**: paso inmediato, espera de 180 ms y luego un paso cada 90 ms | (a) perdía toques rápidos; (b) obligaba a presionar 5 veces para cruzar la pantalla. (c) se siente natural y no pierde toques. | Equipo | R01 |
| D-04 | 2026-10-25 | Subir y bajar al tiempo | Prioridad a subir, prioridad a bajar, mantener | **Mantener** (Tabla V de la guía) | No hay razón para favorecer un sentido; además es el caso seguro si el receptor entrega basura. | Equipo | R01, R09 |
| D-05 | 2026-10-25 | Rebote en paleta | Solo invertir DX, o invertir DX y cambiar DY según la zona | **Zona**: fila superior manda la pelota hacia arriba, inferior hacia abajo, central conserva DY | Le da algo de control al jugador sin agregar velocidades nuevas. | Equipo | R04 |
| D-06 | 2026-10-25 | Movimiento de la pelota | Horizontal pura o diagonal | **Siempre diagonal** (DX, DY = ±1) | En 8 × 16 una pelota horizontal se vuelve aburrida y predecible. | Equipo | R03 |
| D-07 | 2026-10-25 | Velocidad | Fija o creciente | **Creciente por rally**: 260 → 200 → 150 → 110 ms por paso, sube cada 3 rebotes en paleta y vuelve al nivel 0 con cada saque | Mantiene la partida interesante y la pausa entre niveles es fácil de verificar. | Equipo | R03 |
| D-08 | 2026-10-25 | Detección de gol | En X = 0/15 por posición o por intento de llegar a la columna de la paleta sin cobertura | **Por intento**: si la pelota está en X = 1 yendo a la izquierda y la paleta no cubre su fila, es gol de J2 (simétrico para J1 en X = 14) | Así el gol es un *evento* de un solo ciclo que el contador no puede contar dos veces (R05). | Equipo | R05 |
| D-09 | 2026-10-25 | Después del gol | Esperar START o reanudar solo | **Pausa de 1 s y saque automático** desde el centro, hacia el jugador que perdió el punto | Se ve dónde se escapó la pelota y no hace falta un tercer botón. | Equipo | R05, R06 |
| D-10 | 2026-10-25 | Fin de partida | Sin fin, a 9, a 5 | **Gana el primero en llegar a 9**; el marcador se satura | Un display de siete segmentos por jugador solo muestra 0-9. | Equipo | R06 |
| D-11 | 2026-10-25 | Pérdida de enlace RF | Ignorar, congelar paletas, pausar | **Las órdenes se anulan con VT = 0 y el juego pasa a PAUSA**; solo se reanuda con START y ambos enlaces activos | El HT12D deja los datos enclavados al perder señal; sin esto una paleta podría quedarse subiendo para siempre (T09). | Equipo | R09 |
| D-12 | 2026-10-25 | START y RESET | Botones de la tarjeta o en los controles | **Pulsadores de la tarjeta FPGA**. START: iniciar, pausar y reanudar. RESET: vuelve a ESPERA con 0-0 | Así los controles solo necesitan dos botones, y el inicio y el reinicio quedan en manos de quien está en la mesa. | Equipo | R06 |
| D-13 | 2026-10-25 | Estado de ESPERA | Pantalla vacía, pelota fija, pelota titilando | **Pelota titilando en el centro** (2 Hz); las paletas se pueden mover para probar los controles | Indica que el sistema está vivo y esperando START. | Equipo | R07 |
| D-14 | 2026-10-25 | Pantalla de FIN | Mensaje, mitad del ganador encendida | **La mitad del ganador titila** y su display también | Es claro de lejos y no requiere dibujar letras en 8 × 16. | Equipo | R07 |

## Decisiones de implementación

| ID | Fecha | Tema | Decisión | Justificación | Req. |
|----|-------|------|----------|---------------|------|
| D-15 | 2026-10-25 | Reloj | CLK_SYS = 50 MHz (a confirmar con el esquema de la tarjeta). Un solo dominio de reloj; las bases de tiempo son **pulsos de habilitación**, nunca relojes derivados | Evita problemas de sesgo y de temporización en la FPGA. Si el oscilador real es otro, solo se cambia `CLK_HZ`. | R03 |
| D-16 | 2026-10-25 | Frecuencia hacia los MAX7219 | CLK_LED = 1 MHz (`DIV_CLK = 25`) | El chip admite 10 MHz, pero los cables a la matriz van a ser largos y pasan por un adaptador de nivel; 1 MHz da margen y aun así refresca la pantalla ~3600 veces por segundo. | R08 |
| D-17 | 2026-10-25 | Reconfiguración de los MAX7219 | Repetir la secuencia de configuración cada 256 pantallas (~70 ms) | Si un chip se reinicia por ruido en los 5 V, se recupera solo. Lo probamos en `tb_max7219`. | R08 |
| D-18 | 2026-10-25 | Brillo | Registro de intensidad = 0x04 | Con fuente USB conviene no subirlo mucho; es un parámetro. | R10 |
| D-19 | 2026-10-25 | Orden de los módulos | El módulo conectado directo a DIN muestra la mitad izquierda (columnas 0-7). Parámetro `MODULO_CERCANO` | Se puede invertir sin recablear. | R07, R08 |
| D-20 | 2026-10-25 | Orientación de LEDs dentro del módulo | Por defecto dígito = fila, bit 7 = columna izquierda. Parámetros `TRANSPONER`, `INV_BITS`, `INV_DIGITOS` | Todavía no tenemos los módulos; con los parámetros corregimos cualquier orientación en Quartus sin tocar la lógica. | R07 |
| D-21 | 2026-10-25 | Antirrebote | 2 flip-flops de sincronización + 8 muestras iguales a 1 kHz | Ventana de 8 ms: suficiente para pulsadores y no se siente lento. | R09 |
| D-22 | 2026-10-25 | Displays de marcador | Manejo directo de 7 segmentos por jugador (14 salidas), polaridad por parámetro (`SEG_ACTIVO_BAJO`, por defecto ánodo común) | No sabemos aún qué displays vamos a conseguir. | R06, R10 |
| D-23 | 2026-10-25 | Estados no usados de la FSM | Los códigos 101, 110 y 111 vuelven a ESPERA | Comportamiento definido ante estados inválidos, como pide la guía (VI-C). Lo forzamos en `tb_control_juego`. | R06 |
| D-24 | 2026-10-25 | Modo de los transmisores | Parámetro `PAUSAR_SIN_ENLACE`. Con HT12E transmitiendo todo el tiempo (TE a tierra) va en 1; si el transmisor solo emite al presionar, va en 0 | Con transmisión por pulsación VT = 0 es el reposo normal y no se debe pausar. En ambos casos las órdenes se validan con VT. | R09 |

## Hallazgos de la simulación que cambiaron el diseño

Estos no son decisiones de diseño como tal, pero los anotamos porque la guía pide no perder la historia de los cambios.

| ID | Prueba que lo encontró | Problema | Corrección |
|----|------------------------|----------|------------|
| H-01 | `tb_max7219` | La palabra de brillo se armaba como `{12'h00A, INTENSIDAD}` = `0x00A4`, que cae en la dirección 0x0 (no-op). El brillo nunca llegaba. Además, nuestro chequeo dejaba pasar condiciones en X. | Palabra corregida a `0x0A0x`. El macro `VERIFICAR` ahora compara con `!== 1'b1` para que una X cuente como falla. |
| H-02 | `tb_integracion` | Con `DIV_CLK = 1`, DIN cambiaba en el mismo flanco en que subía CLK_LED: violación de setup detectada por el modelo del MAX7219. Con `DIV_CLK = 25` no se notaba. | DIN ahora cambia junto con la **bajada** de CLK_LED, así siempre tiene medio periodo completo de setup sin importar el divisor. |
| H-03 | `tb_generador_ticks` | El multiplexor de periodo, escrito con `always @(*)` + `case`, no se evaluaba en t = 0 en el simulador y el periodo quedaba en X. | Reescrito como `assign` con operador condicional (igual hardware, simulación correcta). Mismo cambio en el nivel de velocidad de `control_juego`. |
| H-04 | `tb_integracion` | Los jugadores robot "distraídos" casi nunca fallaban porque su paleta ya estaba cerca de la fila de regreso. La prueba no ejercitaba goles. | Ahora el robot distraído persigue una fila al azar. (Cambio del testbench, no del diseño.) |

## Pendientes antes de PC4 (dependen del hardware)

| Por definir | Qué necesitamos | Dónde se ajusta |
|-------------|-----------------|-----------------|
| Pines reales de la tarjeta | Esquema de nuestra tarjeta con la EP4CE10E22C8N | `quartus/pong.qsf` |
| Oscilador | Confirmar 50 MHz | `CLK_HZ` en `pong_top` |
| Orientación de las matrices | Probar un patrón fijo (prueba física #2) | `TRANSPONER`, `INV_BITS`, `INV_DIGITOS`, `MODULO_CERCANO` |
| Polaridad de displays | Referencia del display comprado | `SEG_ACTIVO_BAJO` |
| Módulos RF | Recomendamos un par de 315 MHz para J1 y uno de 433 MHz para J2 (ver `docs/hardware.md`) | `CTRL_ACTIVO_BAJO`, `USAR_VT`, `PAUSAR_SIN_ENLACE` |
| Fuente | Medir corriente real con la pantalla en "todo encendido" | `docs/hardware.md` |
