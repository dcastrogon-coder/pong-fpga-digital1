module control_juego (
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Pulsos de botones acondicionados
    input wire START_PULSE,
    input wire PAUSE_PULSE,

    // Validez efectiva de ambos enlaces RF
    input wire RF_OK_EFF,

    // Eventos de colisiones
    input wire GOAL_J1,
    input wire GOAL_J2,

    // Prediccion de victoria del marcador
    input wire WIN_NEXT,

    // Estado registrado de la FSM
    output reg [2:0] STATE,

    // Senales de control del sistema
    output wire GAME_EN,
    output wire CAPTURE_GOAL,
    output wire POINT_EN,
    output wire CENTER_EN,
    output wire REARM_TIMERS,

    // Direccion del siguiente saque
    output reg SERVE_DIR
);

    // ------------------------------------
    // 1. Codificacion de estados
    // ------------------------------------

    localparam [2:0]
        ESPERA       = 3'b000,
        JUEGO        = 3'b001,
        PUNTO        = 3'b010,
        PAUSA_RF     = 3'b011,
        FIN          = 3'b100,
        PAUSA_MANUAL = 3'b101;

    reg [2:0] NEXT_STATE;

    // ------------------------------------
    // 2. Deteccion de gol unico
    // ------------------------------------

    wire GOAL_VALID;

    assign GOAL_VALID = GOAL_J1 ^ GOAL_J2;

    // ------------------------------------
    // 3. Logica combinacional de la FSM
    // ------------------------------------

    always @(*) begin

        // Por defecto conservar estado
        NEXT_STATE = STATE;

        case (STATE)

            ESPERA: begin
                if (RF_OK_EFF && START_PULSE)
                    NEXT_STATE = JUEGO;
            end

            JUEGO: begin

                // Prioridad 1: perdida RF
                if (!RF_OK_EFF)
                    NEXT_STATE = PAUSA_RF;

                // Prioridad 2: pausa manual
                else if (PAUSE_PULSE)
                    NEXT_STATE = PAUSA_MANUAL;

                // Prioridad 3: gol valido
                else if (GOAL_VALID)
                    NEXT_STATE = PUNTO;

                else
                    NEXT_STATE = JUEGO;
            end

            PUNTO: begin

                if (WIN_NEXT)
                    NEXT_STATE = FIN;
                else
                    NEXT_STATE = ESPERA;
            end

            PAUSA_RF: begin

                if (RF_OK_EFF && START_PULSE)
                    NEXT_STATE = JUEGO;
                else
                    NEXT_STATE = PAUSA_RF;
            end

            FIN: begin
                NEXT_STATE = FIN;
            end

            PAUSA_MANUAL: begin

                if (RF_OK_EFF && PAUSE_PULSE)
                    NEXT_STATE = JUEGO;
                else
                    NEXT_STATE = PAUSA_MANUAL;
            end

            // Recuperacion de codigo invalido
            default: begin
                NEXT_STATE = ESPERA;
            end

        endcase
    end

    // ------------------------------------
    // 4. Registro secuencial de estado
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL)
            STATE <= ESPERA;
        else
            STATE <= NEXT_STATE;

    end

    // ------------------------------------
    // 5. Habilitacion del motor
    // ------------------------------------

    // Inhibicion inmediata por RF,
    // PAUSE e inicializacion.

    assign GAME_EN =
        (STATE == JUEGO) &&
        RF_OK_EFF &&
        !PAUSE_PULSE &&
        !INIT_GLOBAL;

    // ------------------------------------
    // 6. Captura de gol
    // ------------------------------------

    assign CAPTURE_GOAL =
        GAME_EN &&
        GOAL_VALID;

    // ------------------------------------
    // 7. Incremento del marcador
    // ------------------------------------

    assign POINT_EN =
        (STATE == PUNTO) &&
        !INIT_GLOBAL;

    // ------------------------------------
    // 8. Centrado despues del punto
    // ------------------------------------

    assign CENTER_EN =
        (STATE == PUNTO) &&
        !WIN_NEXT &&
        !INIT_GLOBAL;

    // ------------------------------------
    // 9. Rearme de temporizadores
    // ------------------------------------

    assign REARM_TIMERS =
        !INIT_GLOBAL &&
        RF_OK_EFF &&
        (
            (
                START_PULSE &&
                (
                    (STATE == ESPERA) ||
                    (STATE == PAUSA_RF)
                )
            )
            ||
            (
                PAUSE_PULSE &&
                (STATE == PAUSA_MANUAL)
            )
        );

    // ------------------------------------
    // 10. Alternancia del saque
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL)
            SERVE_DIR <= 1'b1;

        else if (CAPTURE_GOAL)
            SERVE_DIR <= ~SERVE_DIR;

    end

endmodule