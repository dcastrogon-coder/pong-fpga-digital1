# Un solo reloj de 50 MHz; entradas asíncronas y salidas lentas.
create_clock -name CLK_SYS -period 20.000 [get_ports {CLK_SYS}]
derive_clock_uncertainty
set_false_path -from [get_ports {RESET_PIN SW_PRUEBA}]
set_false_path -to [get_ports {DIN CLK_LED LOAD LED_LATIDO}]
