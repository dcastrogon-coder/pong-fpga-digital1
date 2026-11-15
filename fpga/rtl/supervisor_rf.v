module supervisor_rf #(
    // 500 ms a 50 MHz
    parameter [24:0] N_RF = 25'd25000000
)(
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Receptor del jugador 1
    input wire [1:0] CMD_RX1,
    input wire FRAME_1_VALID,

    // Receptor del jugador 2
    input wire [1:0] CMD_RX2,
    input wire FRAME_2_VALID,

    // Comandos registrados hacia paletas
    output reg [1:0] CMD_J1,
    output reg [1:0] CMD_J2,

    // Validez efectiva de los enlaces
    output wire RF1_OK_EFF,
    output wire RF2_OK_EFF,

    // Validez conjunta hacia la FSM
    output wire RF_OK_EFF
);

    // ------------------------------------
    // 1. Contadores de ausencia RF
    // ------------------------------------

    reg [24:0] AGE1;
    reg [24:0] AGE2;

    localparam [24:0] TC_RF =
        N_RF - 25'd1;

    // ------------------------------------
    // 2. Registros de validez
    // ------------------------------------

    reg RF1;
    reg RF2;

    // ------------------------------------
    // 3. Deteccion anticipada de timeout
    // Ecuacion (71) de F2
    // ------------------------------------

    wire EXPIRE1;
    wire EXPIRE2;

    assign EXPIRE1 =
        RF1 &&
        (AGE1 == TC_RF) &&
        !FRAME_1_VALID;

    assign EXPIRE2 =
        RF2 &&
        (AGE2 == TC_RF) &&
        !FRAME_2_VALID;

    // ------------------------------------
    // 4. Validez efectiva
    // Ecuaciones (72) y (73) de F2
    // ------------------------------------

    assign RF1_OK_EFF =
        RF1 && !EXPIRE1;

    assign RF2_OK_EFF =
        RF2 && !EXPIRE2;

    assign RF_OK_EFF =
        RF1_OK_EFF && RF2_OK_EFF;

    // ------------------------------------
    // 5. Supervisor del jugador 1
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin

            AGE1 <= 25'd0;
            RF1 <= 1'b0;
            CMD_J1 <= 2'b00;

        end

        // Nueva trama valida:
        // prioridad sobre timeout
        else if (FRAME_1_VALID) begin

            AGE1 <= 25'd0;
            RF1 <= 1'b1;
            CMD_J1 <= CMD_RX1;

        end

        // Se alcanzo el limite RF
        else if (AGE1 == TC_RF) begin

            AGE1 <= TC_RF;
            RF1 <= 1'b0;

            // CMD_J1 conserva su valor

        end

        // Seguir contando sin trama
        else begin

            AGE1 <= AGE1 + 25'd1;

            // RF1 conserva su valor
            // CMD_J1 conserva su valor

        end

    end

    // ------------------------------------
    // 6. Supervisor del jugador 2
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin

            AGE2 <= 25'd0;
            RF2 <= 1'b0;
            CMD_J2 <= 2'b00;

        end

        // Nueva trama valida:
        // prioridad sobre timeout
        else if (FRAME_2_VALID) begin

            AGE2 <= 25'd0;
            RF2 <= 1'b1;
            CMD_J2 <= CMD_RX2;

        end

        // Se alcanzo el limite RF
        else if (AGE2 == TC_RF) begin

            AGE2 <= TC_RF;
            RF2 <= 1'b0;

            // CMD_J2 conserva su valor

        end

        // Seguir contando sin trama
        else begin

            AGE2 <= AGE2 + 25'd1;

            // RF2 conserva su valor
            // CMD_J2 conserva su valor

        end

    end

endmodule