module boton_evento #(
    // 20 ms a 50 MHz = 1,000,000 ciclos
    parameter [19:0] NDB = 20'd1000000
)(
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Entrada normalizada:
    // 1 = presionado, 0 = liberado
    input wire PRESSED_RAW,

    // Nivel estable confirmado
    output reg PRESSED_DB,

    // Pulso de un solo ciclo
    output reg PRESS_EVENT
);

    // ------------------------------------
    // 1. Sincronizador de dos FF
    // ------------------------------------

    reg SYNC_1;
    reg SYNC_2;

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin
            SYNC_1 <= 1'b0;
            SYNC_2 <= 1'b0;
        end
        else begin
            SYNC_1 <= PRESSED_RAW;
            SYNC_2 <= SYNC_1;
        end

    end

    // ------------------------------------
    // 2. Contador de estabilidad
    // ------------------------------------

    reg [19:0] CDB;

    wire DIFF;
    wire TERMINAL_DB;

    assign DIFF =
        SYNC_2 ^ PRESSED_DB;

    assign TERMINAL_DB =
        (CDB == (NDB - 20'd1));

    // ------------------------------------
    // 3. Antirrebote y evento
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        if (INIT_GLOBAL) begin

            CDB <= 20'd0;

            PRESSED_DB <= 1'b0;
            PRESS_EVENT <= 1'b0;

        end
        else begin

            // Por defecto, no hay evento.
            PRESS_EVENT <= 1'b0;

            // El nivel coincide con el
            // ultimo valor confirmado.
            if (!DIFF) begin

                CDB <= 20'd0;

            end

            // Existe un cambio pendiente.
            else if (TERMINAL_DB) begin

                // Cambio estable confirmado.
                PRESSED_DB <= SYNC_2;

                // Preparar siguiente cambio.
                CDB <= 20'd0;

                // Solo generar evento
                // al confirmar una presion.
                if (SYNC_2)
                    PRESS_EVENT <= 1'b1;

            end

            // Continuar contando estabilidad.
            else begin

                CDB <= CDB + 20'd1;

            end

        end

    end

endmodule