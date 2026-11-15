# PF Electronica Digital 1 - Pong FPGA
# Restriccion inicial de reloj para Quartus Prime Standard / TimeQuest
# Reloj nominal externo: 50 MHz (20.000 ns por ciclo)
# Confirmar frecuencia real de la tarjeta antes de validar el hardware.

create_clock -name CLK_SYS -period 20.000 [get_ports {CLK_SYS}]
derive_clock_uncertainty

# Pendiente: comprobar asignacion del pin fisico del reloj,
# VCCIO y restricciones de I/O cuando se conozcan las interfaces reales.
