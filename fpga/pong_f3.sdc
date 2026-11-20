# PF Electronica Digital 1 - Pong FPGA
# Restriccion inicial de reloj para Quartus Prime Standard / TimeQuest
# Reloj nominal externo: 50 MHz (20.000 ns por ciclo)
# Confirmar frecuencia real de la tarjeta antes de validar el hardware.

create_clock -name CLK_SYS -period 20.000 [get_ports {CLK_SYS}]
derive_clock_uncertainty

# Entradas asincronas de controles cableados
# Excluir solo el camino hasta la primera etapa SYNC_1

# RESET fisico asincrono (PIN_44)
# Afirmacion asincrona y liberacion sincronizada en reset_seguro
set_false_path \
    -from [get_ports {RESET_N}] \
    -to [all_registers]

set_false_path \
    -from [get_ports {J1_UP_N J1_DOWN_N J1_DETECT_N J2_UP_N J2_DOWN_N J2_DETECT_N START_N PAUSE_N}] \
    -to [get_registers {*|SYNC_1}]
# Pendiente: comprobar asignacion del pin fisico del reloj,
# VCCIO y restricciones de I/O cuando se conozcan las interfaces reales.

# Interfaz serial FPGA -> SN74HCT245N
# Limites de retardo desde la logica interna hasta los pines
# Presupuesto provisional: maximo 40 ns, minimo 0 ns

set_max_delay 40.000 -to [get_ports {DIN CLK_LED LOAD}]
set_min_delay  0.000 -to [get_ports {DIN CLK_LED LOAD}]

# HCT_EN: habilitacion asincrona del SN74HCT245N
# No es una interfaz de datos capturada por reloj externo.
set_false_path -to [get_ports {HCT_EN}]


# F6 - Salidas BCD hacia dos CD4511BE
# Presupuesto provisional de retardo

set_max_delay 40.000 -to [get_ports {SCORE_J1_BCD* SCORE_J2_BCD*}]
set_min_delay 0.000 -to [get_ports {SCORE_J1_BCD* SCORE_J2_BCD*}]
