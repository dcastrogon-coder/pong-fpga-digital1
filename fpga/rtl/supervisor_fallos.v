module supervisor_fallos (

    // Estado registrado de la FSM
    input wire [2:0] STATE,

    // Puntajes BCD registrados
    input wire [3:0] SCORE_J1,
    input wire [3:0] SCORE_J2,

    // Posiciones registradas
    input wire [2:0] YP1,
    input wire [2:0] YP2,
    input wire [3:0] XB,

    // Detector interno del MAX7219
    input wire FAULT_TX,

    // Indicadores individuales
    output wire INVALID_FSM,
    output wire INVALID_BCD_J1,
    output wire INVALID_BCD_J2,
    output wire INVALID_YP1,
    output wire INVALID_YP2,
    output wire INVALID_XB,

    // Solicitud global de recuperacion
    output wire FAULT_RECOVER
);

    // ------------------------------------
    // 1. Estado invalido de la FSM
    // Ecuacion (75) de F2
    // ------------------------------------

    // Estados 110 y 111 invalidos
    assign INVALID_FSM =
        STATE[2] && STATE[1];

    // ------------------------------------
    // 2. Puntajes BCD invalidos
    // Ecuacion (76) de F2
    // ------------------------------------

    // Valores 10 a 15
    assign INVALID_BCD_J1 =
        SCORE_J1[3] &&
        (SCORE_J1[2] || SCORE_J1[1]);

    assign INVALID_BCD_J2 =
        SCORE_J2[3] &&
        (SCORE_J2[2] || SCORE_J2[1]);

    // ------------------------------------
    // 3. Posiciones invalidas de paletas
    // Ecuacion (77) de F2
    // ------------------------------------

    // La fila superior solo puede ser 0..6
    assign INVALID_YP1 =
        (YP1 == 3'd7);

    assign INVALID_YP2 =
        (YP2 == 3'd7);

    // ------------------------------------
    // 4. Posicion horizontal invalida
    // de la pelota
    // Ecuacion (78) de F2
    // ------------------------------------

    // Durante la operacion del juego
    // XB registrado debe estar entre 1 y 14
    assign INVALID_XB =
        (XB == 4'd0) ||
        (XB == 4'd15);

    // ------------------------------------
    // 5. Recuperacion global
    // ------------------------------------

    assign FAULT_RECOVER =
        INVALID_FSM ||
        INVALID_BCD_J1 ||
        INVALID_BCD_J2 ||
        INVALID_YP1 ||
        INVALID_YP2 ||
        INVALID_XB ||
        FAULT_TX;

endmodule