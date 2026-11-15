module imagen (
    input wire [12:0] SNAPSHOT,
    input wire [2:0] ROW_IDX,

    output reg [7:0] DATA_A,
    output reg [7:0] DATA_B
);

    // ------------------------------------
    // 1. Extraer posiciones registradas
    // ------------------------------------

    wire [2:0] YP1_S;
    wire [2:0] YP2_S;
    wire [3:0] XB_S;
    wire [2:0] YB_S;

    assign YP1_S = SNAPSHOT[12:10];
    assign YP2_S = SNAPSHOT[9:7];
    assign XB_S  = SNAPSHOT[6:3];
    assign YB_S  = SNAPSHOT[2:0];

    // ------------------------------------
    // 2. Detectar objetos en la fila
    // ------------------------------------

    wire P1_ROW;
    wire P2_ROW;
    wire BALL_ROW;

    // Las paletas ocupan dos filas.
    // Se utilizan 4 bits para impedir
    // desbordamiento al calcular YP + 1.

    assign P1_ROW =
        (ROW_IDX == YP1_S) ||
        ({1'b0, ROW_IDX} ==
         ({1'b0, YP1_S} + 4'd1));

    assign P2_ROW =
        (ROW_IDX == YP2_S) ||
        ({1'b0, ROW_IDX} ==
         ({1'b0, YP2_S} + 4'd1));

    // La pelota ocupa una sola fila.

    assign BALL_ROW = (ROW_IDX == YB_S);

    // ------------------------------------
    // 3. Generar bytes de cada modulo
    // ------------------------------------

    always @(*) begin

        DATA_A = 8'b00000000;
        DATA_B = 8'b00000000;

        // Paleta izquierda: columna 0
        // Correccion de orientacion horizontal
        if (P1_ROW)
            DATA_A[0] = 1'b1;

        // Paleta derecha: columna 15
        if (P2_ROW)
            DATA_B[7] = 1'b1;

        // Pelota
        if (BALL_ROW) begin

            // Columnas 0 a 7
            if (XB_S <= 4'd7)
                DATA_A[XB_S] = 1'b1;

            // Columnas 8 a 15
            else
                DATA_B[XB_S - 4'd8] = 1'b1;

        end

    end

endmodule