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
set_false_path -from [get_ports {RESET_PIN START_PIN J1_UP J1_DOWN J2_UP J2_DOWN J1_VT J2_VT SW_SONIDO SW_PRUEBA}]

# Salidas lentas: el MAX7219 se maneja a 1 MHz, el display de la tarjeta
# cambia de dígito cada 0,5 ms y el buzzer y los LEDs son todavía más
# lentos. Los tiempos hacia el MAX7219 los garantiza la máquina de estados
# de max7219_tx.v (medio periodo de 500 ns de setup), no el análisis de E/S.
set_false_path -to [get_ports {DIN CLK_LED LOAD SEG[*] DIG[*] BUZZER LED[*]}]
