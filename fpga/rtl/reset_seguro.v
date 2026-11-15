module reset_seguro #(
    // 20 ms a 50 MHz
    parameter [19:0] NDB = 20'd1000000
)(
    input wire CLK_SYS,

    // 1 = RESET fisico presionado
    // 0 = RESET fisico liberado
    input wire RESET_RAW_ACTIVE,

    // Solicitud por arranque
    output wire POR_REQ,

    // RESET fisico acondicionado
    output wire RESET_CLEAN
);

    // ------------------------------------
    // 1. Arranque seguro: BOOT
    // ------------------------------------

    // Valor de encendido solicitado por F2.
    // Debe verificarse su implementacion
    // real en Quartus para la Cyclone IV E.

    reg [3:0] BOOT = 4'b0000;

    always @(posedge CLK_SYS) begin

        BOOT <= {
            BOOT[2:0],
            1'b1
        };

    end

    // Activo durante los primeros
    // cuatro ciclos del reloj.

    assign POR_REQ = ~BOOT[3];

    // ------------------------------------
    // 2. Sincronizador de liberacion
    // ------------------------------------

    reg RELEASE_SYNC1 = 1'b0;
    reg RELEASE_SYNC2 = 1'b0;

    // ------------------------------------
    // 3. Contador de estabilidad
    // ------------------------------------

    reg [19:0] RELEASE_COUNT = 20'd0;

    wire RELEASE_STABLE;

    assign RELEASE_STABLE =
        (RELEASE_COUNT == NDB - 20'd1);

    // ------------------------------------
    // 4. Registro de RESET fisico
    // ------------------------------------

    // Inicia reteniendo el RESET.
    // Se afirma asincronamente.
    // Se libera de manera sincronizada.

    reg R_HOLD = 1'b1;

    always @(posedge CLK_SYS or
             posedge RESET_RAW_ACTIVE) begin

        // --------------------------------
        // RESET presionado:
        // afirmacion asincrona
        // --------------------------------

        if (RESET_RAW_ACTIVE) begin

            R_HOLD <= 1'b1;

            RELEASE_SYNC1 <= 1'b0;
            RELEASE_SYNC2 <= 1'b0;

            RELEASE_COUNT <= 20'd0;

        end

        // --------------------------------
        // RESET no presionado:
        // procesar liberacion
        // --------------------------------

        else begin

            // Dos etapas de sincronizacion
            // del nivel de liberacion.

            RELEASE_SYNC1 <= 1'b1;
            RELEASE_SYNC2 <= RELEASE_SYNC1;

            // Mientras el RESET
            // continua retenido.
            if (R_HOLD) begin

                // Esperar a que la liberacion
                // atraviese ambos FF.
                if (!RELEASE_SYNC2) begin

                    RELEASE_COUNT <= 20'd0;

                end

                // Liberacion estable por NDB
                // ciclos consecutivos.
                else if (RELEASE_STABLE) begin

                    R_HOLD <= 1'b0;

                    RELEASE_COUNT <= 20'd0;

                end

                // Contar estabilidad.
                else begin

                    RELEASE_COUNT <=
                        RELEASE_COUNT + 20'd1;

                end

            end

            // RESET ya liberado:
            // conservar estado inactivo.
            else begin

                RELEASE_COUNT <= 20'd0;

            end

        end

    end

    // ------------------------------------
    // 5. Salida de RESET acondicionado
    // ------------------------------------

    assign RESET_CLEAN = R_HOLD;

endmodule