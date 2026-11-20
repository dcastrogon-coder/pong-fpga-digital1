module filtro_entrada_cableada #(
    // 20 ms a 50 MHz
    parameter [19:0] NDB = 20'd1000000
)(
    input  wire CLK_SYS,
    input  wire INIT_GLOBAL,
    input  wire RAW_N,
    output reg  CLEAN_N
);

    // Sincronizador de dos etapas
    reg SYNC_1;
    reg SYNC_2;

    // Contador de estabilidad
    reg [19:0] COUNT;

    localparam [19:0] TC_DB = NDB - 20'd1;

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin

            SYNC_1 <= 1'b1;
            SYNC_2 <= 1'b1;
            CLEAN_N <= 1'b1;
            COUNT <= 20'd0;

        end
        else begin

            // Sincronizacion de la entrada externa
            SYNC_1 <= RAW_N;
            SYNC_2 <= SYNC_1;

            // La entrada coincide con el valor filtrado
            if (SYNC_2 == CLEAN_N) begin
                COUNT <= 20'd0;
            end

            // Cambio estable durante NDB ciclos
            else if (COUNT == TC_DB) begin
                CLEAN_N <= SYNC_2;
                COUNT <= 20'd0;
            end

            // Continuar comprobando estabilidad
            else begin
                COUNT <= COUNT + 20'd1;
            end

        end

    end

endmodule