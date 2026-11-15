module temporizadores #(
    // Periodos nominales a 50 MHz
    parameter [23:0] N_BALL   = 24'd10000000,
    parameter [23:0] N_PADDLE = 24'd12500000
)(
    input wire CLK_SYS,
    input wire INIT_GLOBAL,
    input wire GAME_EN,
    input wire REARM_TIMERS,

    output wire TICK_BALL,
    output wire TICK_PADDLE
);

    // ------------------------------------
    // 1. Contadores de 24 bits
    // ------------------------------------

    reg [23:0] CB;
    reg [23:0] CP;

    // Valores terminales
    localparam [23:0] TC_BALL =
        N_BALL - 24'd1;

    localparam [23:0] TC_PADDLE =
        N_PADDLE - 24'd1;

    // ------------------------------------
    // 2. Condiciones de terminal
    // ------------------------------------

    wire FIN_BALL;
    wire FIN_PADDLE;

    assign FIN_BALL =
        (CB == TC_BALL);

    assign FIN_PADDLE =
        (CP == TC_PADDLE);

    // ------------------------------------
    // 3. Permiso efectivo
    // ------------------------------------

    wire CE;

    assign CE =
        GAME_EN &&
        !REARM_TIMERS &&
        !INIT_GLOBAL;

    // ------------------------------------
    // 4. Generacion de ticks
    // ------------------------------------

    assign TICK_BALL =
        CE && FIN_BALL;

    assign TICK_PADDLE =
        CE && FIN_PADDLE;

    // ------------------------------------
    // 5. Contador de pelota
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL || REARM_TIMERS)
            CB <= 24'd0;

        else if (GAME_EN) begin

            if (FIN_BALL)
                CB <= 24'd0;

            else
                CB <= CB + 24'd1;

        end

        // GAME_EN=0: conservar CB
    end

    // ------------------------------------
    // 6. Contador de paletas
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL || REARM_TIMERS)
            CP <= 24'd0;

        else if (GAME_EN) begin

            if (FIN_PADDLE)
                CP <= 24'd0;

            else
                CP <= CP + 24'd1;

        end

        // GAME_EN=0: conservar CP
    end

endmodule