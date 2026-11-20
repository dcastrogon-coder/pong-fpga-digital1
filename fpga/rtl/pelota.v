module pelota (
    input wire CLK_SYS,
    input wire INIT_GLOBAL,
    input wire CENTER_EN,
    input wire GAME_EN,
    input wire TICK_BALL,

    input wire SERVE_DIR,
    input wire HIT,
    input wire GOAL,

    output reg [3:0] XB,
    output reg [2:0] YB,
    output reg DX,
    output reg DY,
    output reg PHASE,

    output wire [3:0] X_CAND,
    output wire [2:0] Y_CAND,
    output wire DY_CAND
);

    // ------------------------------------
    // 1. Movimiento horizontal candidato
    // ------------------------------------

    assign X_CAND = DX ?
                    (XB + 4'd1) :
                    (XB - 4'd1);

    // ------------------------------------
    // 2. Deteccion de borde superior/inferior en cada tick
    // ------------------------------------

    wire REFLECT_Y;

    assign REFLECT_Y =
        ((YB == 3'd0) && !DY) ||
        ((YB == 3'd7) &&  DY);

    // Direccion vertical corregida
    assign DY_CAND = DY ^ REFLECT_Y;

    // ------------------------------------
    // 3. Movimiento vertical en cada tick (diagonal 45 grados)
    // ------------------------------------

    assign Y_CAND = DY_CAND ?
                    (YB + 3'd1) :
                    (YB - 3'd1);

    // ------------------------------------
    // 4. Registros secuenciales
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        // Inicializacion global
        if (INIT_GLOBAL) begin
            XB    <= 4'd7;
            YB    <= 3'd3;
            DX    <= 1'b1;
            DY    <= 1'b1;
            PHASE <= 1'b0;
        end

        // Centrado para un nuevo saque
        else if (CENTER_EN) begin
            XB    <= 4'd7;
            YB    <= 3'd3;
            DX    <= SERVE_DIR;
            DY    <= 1'b1;
            PHASE <= 1'b0;
        end

        // Avance habilitado
        else if (GAME_EN && TICK_BALL) begin

            // Gol: conservar todos los registros
            if (GOAL) begin
                // Sin actualizacion
            end

            else begin

                // Impacto horizontal
                if (HIT) begin
                    XB <= XB;
                    DX <= ~DX;
                end

                // Movimiento interior
                else begin
                    XB <= X_CAND;
                    DX <= DX;
                end

                // Actualizacion vertical
                YB <= Y_CAND;
                DY <= DY_CAND;

                // Se conserva PHASE por compatibilidad de interfaz;
                // ya no controla el avance vertical
                PHASE <= ~PHASE;

            end
        end

        // Sin habilitacion:
        // todos los registros conservan su valor

    end

endmodule