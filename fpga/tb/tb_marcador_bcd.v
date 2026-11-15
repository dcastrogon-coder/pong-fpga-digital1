`timescale 1ns/1ps

module tb_marcador_bcd;

    // ------------------------------------
    // 1. Entradas y salidas
    // ------------------------------------

    reg [3:0] SCORE_J1;
    reg [3:0] SCORE_J2;

    wire [3:0] SCORE_J1_BCD;
    wire [3:0] SCORE_J2_BCD;

    integer pruebas_validas;
    integer pruebas_exhaustivas;
    integer pares_invalidos;

    integer i;
    integer j;

    // ------------------------------------
    // 2. Modulo bajo prueba
    // ------------------------------------

    marcador_bcd dut (
        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),

        .SCORE_J1_BCD(SCORE_J1_BCD),
        .SCORE_J2_BCD(SCORE_J2_BCD)
    );

    // ------------------------------------
    // 3. Tarea de comprobacion
    // ------------------------------------

    task comprobar;
        input [3:0] valor_j1;
        input [3:0] valor_j2;

        begin

            SCORE_J1 = valor_j1;
            SCORE_J2 = valor_j2;

            // Esperar estabilizacion
            #1;

            // Ecuacion 68 de F2:
            // las salidas deben ser iguales
            // a sus entradas correspondientes.

            if (
                SCORE_J1_BCD !== valor_j1 ||
                SCORE_J2_BCD !== valor_j2
            ) begin

                $display("-------------------------");
                $display("ERROR MARCADOR BCD");

                $display(
                    "Entradas J1=%h J2=%h",
                    valor_j1, valor_j2
                );

                $display(
                    "Salidas J1=%h J2=%h",
                    SCORE_J1_BCD,
                    SCORE_J2_BCD
                );

                $display("-------------------------");

                $stop;

            end

        end
    endtask

    // ------------------------------------
    // 4. Secuencia principal
    // ------------------------------------

    initial begin

        SCORE_J1 = 4'd0;
        SCORE_J2 = 4'd0;

        pruebas_validas = 0;
        pruebas_exhaustivas = 0;
        pares_invalidos = 0;

        $display("------------------------------");
        $display("TESTBENCH MARCADOR BCD");
        $display("------------------------------");

        // =================================
        // A. PUNTAJES VALIDOS
        // =================================

        // Cada jugador puede tener valores
        // de 0 a 9.
        //
        // Total: 10 x 10 = 100 casos.

        for (i = 0; i < 10; i = i + 1) begin

            for (j = 0; j < 10; j = j + 1) begin

                comprobar(
                    i[3:0],
                    j[3:0]
                );

                pruebas_validas =
                    pruebas_validas + 1;

            end

        end

        $display(
            "OK: %0d pares BCD validos",
            pruebas_validas
        );

        // =================================
        // B. VERIFICACION EXHAUSTIVA
        // =================================

        // Entradas posibles:
        //
        // J1: 16 combinaciones.
        // J2: 16 combinaciones.
        //
        // Total: 16 x 16 = 256 casos.
        //
        // Incluye codigos invalidos
        // del 10 al 15.

        for (i = 0; i < 16; i = i + 1) begin

            for (j = 0; j < 16; j = j + 1) begin

                comprobar(
                    i[3:0],
                    j[3:0]
                );

                pruebas_exhaustivas =
                    pruebas_exhaustivas + 1;

                if ((i > 9) || (j > 9)) begin

                    pares_invalidos =
                        pares_invalidos + 1;

                end

            end

        end

        $display(
            "OK: %0d combinaciones exhaustivas",
            pruebas_exhaustivas
        );

        // =================================
        // C. COMPROBACIONES FINALES
        // =================================

        if (pruebas_validas != 100) begin

            $display(
                "ERROR: Cantidad de pruebas validas"
            );

            $stop;

        end

        if (pruebas_exhaustivas != 256) begin

            $display(
                "ERROR: Cantidad de pruebas exhaustivas"
            );

            $stop;

        end

        if (pares_invalidos != 156) begin

            $display(
                "ERROR: Conteo de pares invalidos"
            );

            $stop;

        end

        // =================================
        // D. RESULTADO FINAL
        // =================================

        $display("------------------------------");

        $display(
            "PARES VALIDOS VERIFICADOS: %0d",
            pruebas_validas
        );

        $display(
            "COMBINACIONES EXHAUSTIVAS: %0d",
            pruebas_exhaustivas
        );

        $display(
            "PARES CON BCD INVALIDO: %0d",
            pares_invalidos
        );

        $display(
            "TOTAL DE COMPROBACIONES: %0d",
            pruebas_validas + pruebas_exhaustivas
        );

        $display(
            "FIN TESTBENCH MARCADOR BCD"
        );

        $display("------------------------------");

        $finish;

    end

endmodule