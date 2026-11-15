module captura_imagen (
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Solicitud del transmisor MAX7219
    input wire CAPTURE_REQ,

    // Posiciones actuales del juego
    input wire [2:0] YP1,
    input wire [2:0] YP2,
    input wire [3:0] XB,
    input wire [2:0] YB,

    // Instantanea registrada de 13 bits
    output reg [12:0] SNAPSHOT,

    // Confirmacion de captura
    output reg FRAME_READY
);

    // ------------------------------------
    // Captura sincronizada de imagen
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        // Inicializacion global
        if (INIT_GLOBAL) begin

            SNAPSHOT <= {
                3'd3,  // YP1 inicial
                3'd3,  // YP2 inicial
                4'd7,  // XB inicial
                3'd3   // YB inicial
            };

            FRAME_READY <= 1'b0;

        end

        // Nueva solicitud de captura
        else if (CAPTURE_REQ) begin

            SNAPSHOT <= {
                YP1,
                YP2,
                XB,
                YB
            };

            FRAME_READY <= 1'b1;

        end

        // Sin nueva solicitud
        else begin

            // SNAPSHOT conserva su valor
            FRAME_READY <= 1'b0;

        end

    end

endmodule