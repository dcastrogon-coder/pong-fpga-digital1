module paletas (
    input wire CLK_SYS,
    input wire INIT_GLOBAL,
    input wire CENTER_EN,
    input wire CAPTURE_GOAL,
    input wire GAME_EN,
    input wire TICK_PADDLE,

    input wire [1:0] CMD_J1,
    input wire [1:0] CMD_J2,

    output reg [2:0] YP1,
    output reg [2:0] YP2,

    output wire [2:0] YP1_EFF,
    output wire [2:0] YP2_EFF
);

    // Posiciones candidatas
    reg [2:0] next_yp1;
    reg [2:0] next_yp2;

    // Permiso de movimiento
    wire EP;

    assign EP = GAME_EN && TICK_PADDLE;

    // ------------------------------------
    // Logica combinacional - Jugador 1
    // ------------------------------------
    always @(*) begin
        next_yp1 = YP1;

        if (EP) begin
            case (CMD_J1)
                2'b01: begin
                    if (YP1 > 3'd0 && YP1 <= 3'd6)
                        next_yp1 = YP1 - 3'd1;
                end

                2'b10: begin
                    if (YP1 < 3'd6)
                        next_yp1 = YP1 + 3'd1;
                end

                default: next_yp1 = YP1;
            endcase
        end
    end

    // ------------------------------------
    // Logica combinacional - Jugador 2
    // ------------------------------------
    always @(*) begin
        next_yp2 = YP2;

        if (EP) begin
            case (CMD_J2)
                2'b01: begin
                    if (YP2 > 3'd0 && YP2 <= 3'd6)
                        next_yp2 = YP2 - 3'd1;
                end

                2'b10: begin
                    if (YP2 < 3'd6)
                        next_yp2 = YP2 + 3'd1;
                end

                default: next_yp2 = YP2;
            endcase
        end
    end

    // Posiciones efectivas para colisiones
    assign YP1_EFF = next_yp1;
    assign YP2_EFF = next_yp2;

    // ------------------------------------
    // Logica secuencial
    // ------------------------------------
    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin
            YP1 <= 3'd3;
            YP2 <= 3'd3;
        end

        else if (CENTER_EN) begin
            YP1 <= 3'd3;
            YP2 <= 3'd3;
        end

        else if (CAPTURE_GOAL) begin
            YP1 <= YP1;
            YP2 <= YP2;
        end

        else begin
            YP1 <= next_yp1;
            YP2 <= next_yp2;
        end
    end

endmodule