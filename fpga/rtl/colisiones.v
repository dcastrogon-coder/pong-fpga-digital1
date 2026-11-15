module colisiones (
    // Habilitaciones del juego
    input wire GAME_EN,
    input wire TICK_BALL,

    // Posicion y direccion de la pelota
    input wire [3:0] XB,
    input wire [3:0] X_CAND,
    input wire [2:0] Y_CAND,
    input wire DX,

    // Posiciones efectivas de las paletas
    input wire [2:0] YP1_EFF,
    input wire [2:0] YP2_EFF,

    // Eventos de impacto
    output wire HIT_J1,
    output wire HIT_J2,

    // Eventos de anotacion
    output wire GOAL_J1,
    output wire GOAL_J2
);

    // ------------------------------------
    // 1. Permiso de evaluacion
    // ------------------------------------

    wire AB;

    assign AB = GAME_EN && TICK_BALL;

    // ------------------------------------
    // 2. Deteccion de bordes horizontales
    // ------------------------------------

    wire EL;
    wire ER;

    // Intento de entrar en columna izquierda
    assign EL = !DX &&
                (XB == 4'd1) &&
                (X_CAND == 4'd0);

    // Intento de entrar en columna derecha
    assign ER = DX &&
                (XB == 4'd14) &&
                (X_CAND == 4'd15);

    // ------------------------------------
    // 3. Comparacion con paletas
    // ------------------------------------

    wire P1;
    wire P2;

    // Paleta izquierda: dos filas verticales
    assign P1 = (Y_CAND == YP1_EFF) ||
                (Y_CAND == (YP1_EFF + 3'd1));

    // Paleta derecha: dos filas verticales
    assign P2 = (Y_CAND == YP2_EFF) ||
                (Y_CAND == (YP2_EFF + 3'd1));

    // ------------------------------------
    // 4. Deteccion de impactos
    // ------------------------------------

    assign HIT_J1 = AB && EL && P1;
    assign HIT_J2 = AB && ER && P2;

    // ------------------------------------
    // 5. Deteccion de goles
    // ------------------------------------

    // Si falla J2, anota J1
    assign GOAL_J1 = AB && ER && !P2;

    // Si falla J1, anota J2
    assign GOAL_J2 = AB && EL && !P1;

endmodule