module pong_f4_visual_top (
    input  wire CLK_SYS,

    output wire DIN,
    output wire CLK_LED,
    output wire LOAD
);

    // Prueba de F4:
    // Los controles fisicos y RF aun no estan conectados.
    // Se fijan sus entradas a valores conocidos.

    pong_top u_pong (
        .CLK_SYS(CLK_SYS),

        // Pulsadores inactivos
        .START_RAW(1'b0),
        .RESET_RAW(1'b0),
        .PAUSE_RAW(1'b0),

        // Enlaces RF ausentes durante F4
        .CMD_RX1(2'b00),
        .FRAME_1_VALID(1'b0),

        .CMD_RX2(2'b00),
        .FRAME_2_VALID(1'b0),

        // Salidas de la interfaz visual
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),

        // Marcadores no utilizados en F4
        .SCORE_J1_BCD(),
        .SCORE_J2_BCD()
    );

endmodule