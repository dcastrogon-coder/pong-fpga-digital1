module marcador_bcd (
    // Puntajes registrados en puntaje.v
    input wire [3:0] SCORE_J1,
    input wire [3:0] SCORE_J2,

    // Salidas a decodificadores BCD externos
    output wire [3:0] SCORE_J1_BCD,
    output wire [3:0] SCORE_J2_BCD
);

    // ------------------------------------
    // Ecuacion (68) de F2
    // ------------------------------------

    assign SCORE_J1_BCD = SCORE_J1;

    assign SCORE_J2_BCD = SCORE_J2;

endmodule