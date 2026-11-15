module puntaje (
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Eventos del modulo de colisiones
    input wire GOAL_J1,
    input wire GOAL_J2,

    // Habilitaciones de la FSM
    input wire CAPTURE_GOAL,
    input wire POINT_EN,

    // Marcadores BCD registrados
    output reg [3:0] SCORE_J1,
    output reg [3:0] SCORE_J2,

    // Anotador registrado
    // 0 = jugador 1; 1 = jugador 2
    output reg SCORER,

    // Prediccion de victoria
    output wire WIN_NEXT
);

    // ------------------------------------
    // 1. Validacion del evento de gol
    // ------------------------------------

    wire VALID_GOAL;
    wire CG;

    // Solo se acepta exactamente un gol
    assign VALID_GOAL = GOAL_J1 ^ GOAL_J2;

    assign CG = CAPTURE_GOAL && VALID_GOAL;

    // ------------------------------------
    // 2. Registro del anotador
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL)
            SCORER <= 1'b0;

        else if (CG)
            SCORER <= GOAL_J2;

        // Sin captura valida:
        // conservar anotador anterior
    end

    // ------------------------------------
    // 3. Incrementos seleccionados
    // ------------------------------------

    wire INC_J1;
    wire INC_J2;

    assign INC_J1 = POINT_EN &&
                    !SCORER &&
                    (SCORE_J1 < 4'd9);

    assign INC_J2 = POINT_EN &&
                    SCORER &&
                    (SCORE_J2 < 4'd9);

    // ------------------------------------
    // 4. Registros de puntuacion
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin
            SCORE_J1 <= 4'd0;
            SCORE_J2 <= 4'd0;
        end

        else begin
            if (INC_J1)
                SCORE_J1 <= SCORE_J1 + 4'd1;

            if (INC_J2)
                SCORE_J2 <= SCORE_J2 + 4'd1;
        end
    end

    // ------------------------------------
    // 5. Deteccion anticipada de victoria
    // ------------------------------------

    wire WIN_J1;
    wire WIN_J2;

    assign WIN_J1 = !SCORER &&
                    (SCORE_J1 >= 4'd8);

    assign WIN_J2 = SCORER &&
                    (SCORE_J2 >= 4'd8);

    assign WIN_NEXT = POINT_EN &&
                      (WIN_J1 || WIN_J2);

endmodule