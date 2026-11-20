module pong_f6_integracion_top #(
    parameter integer HCT_WAIT_CYCLES = 2500000,
    parameter [19:0] NDB_RESET_TOP = 20'd1000000
)(
    input wire CLK_SYS,

    // Botones generales activos en bajo
    input wire START_N,
    input wire RESET_N,
    input wire PAUSE_N,

    // Control cableado jugador 1
    input wire J1_UP_N,
    input wire J1_DOWN_N,
    input wire J1_DETECT_N,

    // Control cableado jugador 2
    input wire J2_UP_N,
    input wire J2_DOWN_N,
    input wire J2_DETECT_N,

    // Pantallas MAX7219
    output wire DIN,
	 output wire CLK_LED,
	 output wire LOAD,
	 output wire HCT_EN,

	 // Marcador de los dos jugadores
	 output wire [3:0] SCORE_J1_BCD,
	 output wire [3:0] SCORE_J2_BCD
	 
);

    // Nucleo del Pong para F5
	 pong_f5_core #(
		 .NDB_RESET(NDB_RESET_TOP)
	 ) u_pong_f5 (
        .CLK_SYS(CLK_SYS),

        // Conversion de activo-bajo a activo-alto
        .START_RAW(~START_N),
        // Mantener el nucleo en reset mientras HCT esta deshabilitado
		  .RESET_RAW(~RESET_N | ~HCT_EN),
        .PAUSE_RAW(~PAUSE_N),

        // Jugador 1
        .J1_UP_N(J1_UP_N),
        .J1_DOWN_N(J1_DOWN_N),
        .J1_DETECT_N(J1_DETECT_N),

        // Jugador 2
        .J2_UP_N(J2_UP_N),
        .J2_DOWN_N(J2_DOWN_N),
        .J2_DETECT_N(J2_DETECT_N),

        // Visualizacion MAX7219
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),

        // Marcadores BCD pendientes de F6
        .SCORE_J1_BCD(SCORE_J1_BCD),
		  .SCORE_J2_BCD(SCORE_J2_BCD)
    );
// Habilitacion del 74HCT245.
// Temporalmente desactivada.
// ================================================
// Habilitacion controlada del 74HCT245
// Reloj de 50 MHz
// Espera inicial: 50 ms
// ================================================

reg [21:0] HCT_DELAY = 22'd0;

always @(posedge CLK_SYS) begin
    if (HCT_DELAY < HCT_WAIT_CYCLES)
        HCT_DELAY <= HCT_DELAY + 22'd1;
end

assign HCT_EN = (HCT_DELAY == HCT_WAIT_CYCLES);

endmodule