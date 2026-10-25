# ============================================================================
#  pong.sdc - Restricciones de tiempo para TimeQuest
#  Pong en FPGA - Electrónica Digital 1 - UNAL
# ----------------------------------------------------------------------------
#  Todo el diseño corre en un solo dominio de reloj (CLK_SYS = 50 MHz). Las
#  bases de tiempo internas son pulsos de habilitación, no relojes, así que no
#  hay que declarar relojes generados.
# ============================================================================

create_clock -name CLK_SYS -period 20.000 [get_ports {CLK_SYS}]
derive_clock_uncertainty

# Entradas asíncronas: pulsadores y receptores RF. Pasan por el sincronizador
# de dos flip-flops de antirrebote.v, por eso no tiene sentido analizar su
# camino desde el pin.
set_false_path -from [get_ports {RESET_PIN START_PIN J1_UP J1_DOWN J2_UP J2_DOWN J1_VT J2_VT}]

# Salidas lentas: el MAX7219 se maneja a 1 MHz y los displays/LEDs son
# estáticos. Sus tiempos los garantiza la máquina de estados de max7219_tx.v
# (medio periodo de 500 ns de setup), no el análisis de E/S.
set_false_path -to [get_ports {DIN CLK_LED LOAD SEG_J1[*] SEG_J2[*] LED[*]}]
