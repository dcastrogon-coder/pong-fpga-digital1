`timescale 1ns/1ps

module tb_reset_seguro;

    localparam integer NDB_TB = 4;

    reg CLK_SYS;
    reg RESET_RAW_ACTIVE;

    wire POR_REQ;
    wire RESET_CLEAN;

    integer comprobaciones;
    integer i;

    // ------------------------------------
    // 1. Modulo bajo prueba
    // ------------------------------------

    reset_seguro #(
        .NDB(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .RESET_RAW_ACTIVE(RESET_RAW_ACTIVE),
        .POR_REQ(POR_REQ),
        .RESET_CLEAN(RESET_CLEAN)
    );

    // Reloj nominal de 50 MHz
    initial CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // 2. Comprobacion general
    // ------------------------------------

    task comprobar;
        input [3:0] boot_esperado;
        input por_esperado;
        input reset_esperado;
        input [8*80-1:0] nombre;

        begin

            if (
                dut.BOOT !== boot_esperado ||
                POR_REQ !== por_esperado ||
                RESET_CLEAN !== reset_esperado ||
                dut.R_HOLD !== reset_esperado
            ) begin

                $display("-------------------------");
                $display("ERROR: %0s", nombre);

                $display(
                    "Esperado BOOT=%b POR=%b RESET=%b",
                    boot_esperado,
                    por_esperado,
                    reset_esperado
                );

                $display(
                    "Obtenido BOOT=%b POR=%b RESET=%b",
                    dut.BOOT,
                    POR_REQ,
                    RESET_CLEAN
                );

                $fatal(1, "Fallo en reset_seguro");

            end

            comprobaciones =
                comprobaciones + 1;

        end
    endtask

    // ------------------------------------
    // 3. Comprobar afirmacion asincrona
    // ------------------------------------

    task comprobar_async;

        begin

            comprobar(
                4'b1111,
                1'b0,
                1'b1,
                "Afirmacion asincrona"
            );

            if (
                dut.RELEASE_SYNC1 !== 1'b0 ||
                dut.RELEASE_SYNC2 !== 1'b0 ||
                dut.RELEASE_COUNT !== 20'd0
            ) begin

                $fatal(
                    1,
                    "RESET no limpio registros inmediatamente"
                );

            end

        end
    endtask

    // ------------------------------------
    // 4. Verificar liberacion completa
    // ------------------------------------

    task liberar_y_verificar;

        integer ciclo;

        begin

            @(negedge CLK_SYS);

            RESET_RAW_ACTIVE = 1'b0;

            #1;

            // La liberacion del boton no
            // debe quitar RESET inmediatamente.
            comprobar(
                4'b1111,
                1'b0,
                1'b1,
                "Liberacion inicial retenida"
            );

            // Dos etapas de sincronizacion
            // mas NDB ciclos de estabilidad.
            //
            // Para NDB=4:
            // RESET baja en el sexto flanco.

            for (
                ciclo = 1;
                ciclo <= NDB_TB + 2;
                ciclo = ciclo + 1
            ) begin

                @(posedge CLK_SYS);
                #1;

                if (ciclo < NDB_TB + 2) begin

                    comprobar(
                        4'b1111,
                        1'b0,
                        1'b1,
                        "RESET retenido durante filtro"
                    );

                end
                else begin

                    comprobar(
                        4'b1111,
                        1'b0,
                        1'b0,
                        "Liberacion estable confirmada"
                    );

                end

            end

            // Comprobar sincronizadores
            // y contador tras la liberacion.
            if (
                dut.RELEASE_SYNC1 !== 1'b1 ||
                dut.RELEASE_SYNC2 !== 1'b1 ||
                dut.RELEASE_COUNT !== 20'd0
            ) begin

                $fatal(
                    1,
                    "Estado interno incorrecto al liberar"
                );

            end

        end
    endtask

    // ------------------------------------
    // 5. Secuencia principal de pruebas
    // ------------------------------------

    initial begin

        RESET_RAW_ACTIVE = 1'b1;
        comprobaciones = 0;

        $display("------------------------------");
        $display("TESTBENCH RESET_SEGURO");
        $display("------------------------------");

        // =================================
        // A. ENCENDIDO DE LA FPGA
        // =================================

        #1;

        comprobar(
            4'b0000,
            1'b1,
            1'b1,
            "Valores iniciales"
        );

        $display("OK: Arranque inicial seguro");

        // =================================
        // B. SECUENCIA BOOT DE 4 CICLOS
        // =================================

        for (i = 1; i <= 4; i = i + 1) begin

            @(posedge CLK_SYS);
            #1;

            case (i)

                1: comprobar(
                    4'b0001, 1'b1, 1'b1,
                    "BOOT ciclo 1"
                );

                2: comprobar(
                    4'b0011, 1'b1, 1'b1,
                    "BOOT ciclo 2"
                );

                3: comprobar(
                    4'b0111, 1'b1, 1'b1,
                    "BOOT ciclo 3"
                );

                4: comprobar(
                    4'b1111, 1'b0, 1'b1,
                    "BOOT ciclo 4"
                );

            endcase

        end

        $display("OK: POR_REQ activo durante arranque");

        // Mantener RESET presionado.
        // BOOT no debe cambiar nuevamente.

        repeat (3) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b1,
                "RESET fisico mantenido"
            );

        end

        $display("OK: BOOT completo y estable");

        // =================================
        // C. PRIMERA LIBERACION
        // =================================

        liberar_y_verificar();

        $display(
            "OK: Liberacion sincronizada y filtrada"
        );

        // Comprobar que el RESET no
        // vuelva a activarse por si solo.

        repeat (5) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b0,
                "Reposo estable"
            );

        end

        $display("OK: RESET permanece liberado");

        // =================================
        // D. AFIRMACION ASINCRONA
        // =================================

        // Activar RESET entre flancos
        // de CLK_SYS.

        @(negedge CLK_SYS);
        #2;

        RESET_RAW_ACTIVE = 1'b1;

        // Comprobar antes del siguiente
        // flanco ascendente.
        #1;

        comprobar_async();

        $display("OK: Afirmacion asincrona");

        // Mantener presionado.
        repeat (2) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b1,
                "RESET mantenido"
            );

        end

        // =================================
        // E. REBOTE DURANTE LIBERACION
        // =================================

        @(negedge CLK_SYS);

        RESET_RAW_ACTIVE = 1'b0;

        // Permitir cuatro flancos:
        // aun no debe completarse
        // la liberacion.

        repeat (4) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b1,
                "Liberacion parcial"
            );

        end

        // El contador debe haber
        // avanzado dos ciclos.
        if (dut.RELEASE_COUNT !== 20'd2)
            $fatal(
                1,
                "Conteo parcial incorrecto"
            );

        // Rebote: RESET vuelve a activarse
        // entre flancos de reloj.

        @(negedge CLK_SYS);
        #2;

        RESET_RAW_ACTIVE = 1'b1;

        #1;

        comprobar_async();

        $display(
            "OK: Rebote reinicia contador y sincronizadores"
        );

        repeat (2) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b1,
                "RESET retenido tras rebote"
            );

        end

        // Ahora si, liberar completamente.
        liberar_y_verificar();

        $display(
            "OK: Nueva liberacion completa tras rebote"
        );

        // =================================
        // F. INDEPENDENCIA DE POR_REQ
        // =================================

        repeat (2) begin

            @(posedge CLK_SYS);
            #1;

            comprobar(
                4'b1111, 1'b0, 1'b0,
                "BOOT independiente del RESET"
            );

        end

        $display(
            "OK: RESET fisico no reinicia BOOT"
        );

        // =================================
        // G. PULSACION FISICA BREVE
        // =================================

        @(negedge CLK_SYS);
        #2;

        RESET_RAW_ACTIVE = 1'b1;

        #1;

        // RESET debe activarse aunque
        // la pulsacion sea menor que
        // un periodo de CLK_SYS.
        comprobar_async();

        // Soltar antes del siguiente
        // flanco ascendente.
        #1;

        RESET_RAW_ACTIVE = 1'b0;

        #1;

        comprobar(
            4'b1111,
            1'b0,
            1'b1,
            "Pulso breve retenido"
        );

        $display(
            "OK: Pulsacion breve detectada"
        );

        // Esperar liberacion filtrada
        // sin volver a cambiar la entrada.
        for (i = 1; i <= NDB_TB + 2; i = i + 1) begin

            @(posedge CLK_SYS);
            #1;

            if (i < NDB_TB + 2)
                comprobar(
                    4'b1111, 1'b0, 1'b1,
                    "Filtro tras pulso breve"
                );

            else
                comprobar(
                    4'b1111, 1'b0, 1'b0,
                    "Liberacion tras pulso breve"
                );

        end

        $display(
            "OK: Liberacion segura tras pulso breve"
        );

        // =================================
        // H. RESULTADOS FINALES
        // =================================

        $display("------------------------------");

        $display(
            "COMPROBACIONES SUPERADAS: %0d",
            comprobaciones
        );

        $display(
            "BOOT FINAL: %b",
            dut.BOOT
        );

        $display(
            "POR_REQ FINAL: %b",
            POR_REQ
        );

        $display(
            "RESET_CLEAN FINAL: %b",
            RESET_CLEAN
        );

        $display(
            "FIN TESTBENCH RESET_SEGURO"
        );

        $display("------------------------------");

        $finish;

    end

    // ------------------------------------
    // 6. Proteccion contra bloqueo
    // ------------------------------------

    initial begin
        #10000;
        $fatal(
            1,
            "Timeout del testbench RESET_SEGURO"
        );
    end

endmodule