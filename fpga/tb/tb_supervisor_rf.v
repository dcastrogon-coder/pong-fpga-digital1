`timescale 1ns/1ps

module tb_supervisor_rf;

    localparam integer N_RF_TB = 5;

    reg CLK_SYS;
    reg INIT_GLOBAL;

    reg [1:0] CMD_RX1;
    reg [1:0] CMD_RX2;

    reg FRAME_1_VALID;
    reg FRAME_2_VALID;

    wire [1:0] CMD_J1;
    wire [1:0] CMD_J2;

    wire RF1_OK_EFF;
    wire RF2_OK_EFF;
    wire RF_OK_EFF;

    integer pruebas;
    integer tramas1;
    integer tramas2;
    integer vencimientos1;
    integer vencimientos2;
    integer rescates_terminal;

    integer i;

    // ------------------------------------
    // 1. Modelo de referencia
    // ------------------------------------

    integer ref_age1;
    integer ref_age2;

    reg ref_rf1;
    reg ref_rf2;

    reg [1:0] ref_cmd1;
    reg [1:0] ref_cmd2;

    // ------------------------------------
    // 2. Modulo bajo prueba
    // ------------------------------------

    supervisor_rf #(
        .N_RF(25'd5)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),

        .CMD_RX1(CMD_RX1),
        .FRAME_1_VALID(FRAME_1_VALID),

        .CMD_RX2(CMD_RX2),
        .FRAME_2_VALID(FRAME_2_VALID),

        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),

        .RF1_OK_EFF(RF1_OK_EFF),
        .RF2_OK_EFF(RF2_OK_EFF),
        .RF_OK_EFF(RF_OK_EFF)
    );

    // Reloj de 50 MHz
    initial CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // 3. Tarea de verificacion por ciclo
    // ------------------------------------

    task paso;

        input rst;
        input v1;
        input [1:0] c1;
        input v2;
        input [1:0] c2;
        input [8*80-1:0] nombre;

        reg exp1;
        reg exp2;

        reg next_rf1;
        reg next_rf2;

        reg [1:0] next_cmd1;
        reg [1:0] next_cmd2;

        integer next_age1;
        integer next_age2;

        reg post_exp1;
        reg post_exp2;

        begin

            @(negedge CLK_SYS);

            INIT_GLOBAL = rst;

            FRAME_1_VALID = v1;
            FRAME_2_VALID = v2;

            CMD_RX1 = c1;
            CMD_RX2 = c2;

            #1;

            // ----------------------------
            // A. Prediccion combinacional
            // antes del flanco.
            // ----------------------------

            exp1 =
                ref_rf1 &&
                (ref_age1 == N_RF_TB - 1) &&
                !v1;

            exp2 =
                ref_rf2 &&
                (ref_age2 == N_RF_TB - 1) &&
                !v2;

            if (
                dut.EXPIRE1 !== exp1 ||
                dut.EXPIRE2 !== exp2
            ) begin

                $display(
                    "ERROR EXPIRE: %0s",
                    nombre
                );

                $fatal(
                    1,
                    "Deteccion anticipada incorrecta"
                );

            end

            if (
                RF1_OK_EFF !== (ref_rf1 && !exp1) ||
                RF2_OK_EFF !== (ref_rf2 && !exp2) ||
                RF_OK_EFF !==
                    (ref_rf1 && !exp1 &&
                     ref_rf2 && !exp2)
            ) begin

                $display(
                    "ERROR RF_OK antes de flanco: %0s",
                    nombre
                );

                $fatal(
                    1,
                    "Validez RF combinacional incorrecta"
                );

            end

            // ----------------------------
            // B. Modelo del siguiente estado
            // ----------------------------

            next_age1 = ref_age1;
            next_age2 = ref_age2;

            next_rf1 = ref_rf1;
            next_rf2 = ref_rf2;

            next_cmd1 = ref_cmd1;
            next_cmd2 = ref_cmd2;

            if (rst) begin

                next_age1 = 0;
                next_age2 = 0;

                next_rf1 = 1'b0;
                next_rf2 = 1'b0;

                next_cmd1 = 2'b00;
                next_cmd2 = 2'b00;

            end

            else begin

                // ------------------------
                // Jugador 1
                // ------------------------

                if (v1) begin

                    next_age1 = 0;
                    next_rf1 = 1'b1;
                    next_cmd1 = c1;

                end

                else if (
                    ref_age1 == N_RF_TB - 1
                ) begin

                    next_age1 = N_RF_TB - 1;
                    next_rf1 = 1'b0;

                end

                else begin

                    next_age1 = ref_age1 + 1;

                end

                // ------------------------
                // Jugador 2
                // ------------------------

                if (v2) begin

                    next_age2 = 0;
                    next_rf2 = 1'b1;
                    next_cmd2 = c2;

                end

                else if (
                    ref_age2 == N_RF_TB - 1
                ) begin

                    next_age2 = N_RF_TB - 1;
                    next_rf2 = 1'b0;

                end

                else begin

                    next_age2 = ref_age2 + 1;

                end

            end

            // ----------------------------
            // C. Estadisticas de prueba
            // ----------------------------

            if (!rst) begin

                if (v1)
                    tramas1 = tramas1 + 1;

                if (v2)
                    tramas2 = tramas2 + 1;

                if (exp1)
                    vencimientos1 =
                        vencimientos1 + 1;

                if (exp2)
                    vencimientos2 =
                        vencimientos2 + 1;

                // Trama recibida en el
                // terminal con enlace vigente.
                if (
                    (v1 && ref_rf1 &&
                     ref_age1 == N_RF_TB - 1) ||
                    (v2 && ref_rf2 &&
                     ref_age2 == N_RF_TB - 1)
                )
                    rescates_terminal =
                        rescates_terminal + 1;

            end

            // ----------------------------
            // D. Comprobar flanco de reloj
            // ----------------------------

            @(posedge CLK_SYS);
            #1;

            if (
                dut.AGE1 !== next_age1[24:0] ||
                dut.AGE2 !== next_age2[24:0]
            ) begin

                $display(
                    "ERROR EDADES: %0s",
                    nombre
                );

                $display(
                    "Esperado AGE1=%0d AGE2=%0d",
                    next_age1, next_age2
                );

                $display(
                    "Obtenido AGE1=%0d AGE2=%0d",
                    dut.AGE1, dut.AGE2
                );

                $fatal(
                    1,
                    "Contadores RF incorrectos"
                );

            end

            if (
                dut.RF1 !== next_rf1 ||
                dut.RF2 !== next_rf2 ||
                CMD_J1 !== next_cmd1 ||
                CMD_J2 !== next_cmd2
            ) begin

                $display(
                    "ERROR REGISTROS: %0s",
                    nombre
                );

                $fatal(
                    1,
                    "Validez o comandos incorrectos"
                );

            end

            // ----------------------------
            // E. Verificacion combinacional
            // despues del flanco
            // ----------------------------

            post_exp1 =
                next_rf1 &&
                (next_age1 == N_RF_TB - 1) &&
                !v1;

            post_exp2 =
                next_rf2 &&
                (next_age2 == N_RF_TB - 1) &&
                !v2;

            if (
                RF1_OK_EFF !==
                    (next_rf1 && !post_exp1) ||
                RF2_OK_EFF !==
                    (next_rf2 && !post_exp2) ||
                RF_OK_EFF !==
                    (next_rf1 && !post_exp1 &&
                     next_rf2 && !post_exp2)
            ) begin

                $display(
                    "ERROR RF_OK despues de flanco: %0s",
                    nombre
                );

                $fatal(
                    1,
                    "Validez efectiva incorrecta"
                );

            end

            // Actualizar modelo de referencia
            ref_age1 = next_age1;
            ref_age2 = next_age2;

            ref_rf1 = next_rf1;
            ref_rf2 = next_rf2;

            ref_cmd1 = next_cmd1;
            ref_cmd2 = next_cmd2;

            pruebas = pruebas + 1;

        end

    endtask

    // ------------------------------------
    // 4. Secuencia de pruebas
    // ------------------------------------

    initial begin

        INIT_GLOBAL = 1'b1;

        FRAME_1_VALID = 1'b0;
        FRAME_2_VALID = 1'b0;

        CMD_RX1 = 2'b00;
        CMD_RX2 = 2'b00;

        ref_age1 = 0;
        ref_age2 = 0;

        ref_rf1 = 0;
        ref_rf2 = 0;

        ref_cmd1 = 2'b00;
        ref_cmd2 = 2'b00;

        pruebas = 0;
        tramas1 = 0;
        tramas2 = 0;
        vencimientos1 = 0;
        vencimientos2 = 0;
        rescates_terminal = 0;

        $display("------------------------------");
        $display("TESTBENCH SUPERVISOR RF");
        $display("------------------------------");

        // =================================
        // A. INICIALIZACION
        // =================================

        // INIT debe dominar ambas tramas.
        paso(
            1,1,2'b11,1,2'b10,
            "INIT domina tramas"
        );

        repeat (2)
            paso(
                0,0,2'b00,0,2'b00,
                "Sin tramas iniciales"
            );

        if (RF_OK_EFF !== 1'b0)
            $fatal(1,"RF activo sin tramas");

        $display("OK: Inicializacion RF");

        // =================================
        // B. ALTA DE LOS DOS ENLACES
        // =================================

        paso(
            0,1,2'b01,0,2'b00,
            "Primera trama J1"
        );

        if (
            RF1_OK_EFF !== 1'b1 ||
            RF2_OK_EFF !== 1'b0
        )
            $fatal(1,"Alta independiente J1");

        paso(
            0,0,2'b00,1,2'b10,
            "Primera trama J2"
        );

        if (RF_OK_EFF !== 1'b1)
            $fatal(1,"Ambos enlaces deben estar activos");

        $display("OK: Alta independiente de J1 y J2");

        // =================================
        // C. COMANDOS Y RENOVACIONES
        // =================================

        paso(
            0,1,2'b11,1,2'b01,
            "Comando conflicto J1"
        );

        paso(
            0,1,2'b00,1,2'b00,
            "Comandos mantener"
        );

        // Cambiar CMD_RX sin FRAME_VALID
        // no debe actualizar CMD_J1 ni CMD_J2.

        repeat (3)
            paso(
                0,0,2'b10,0,2'b11,
                "Sin trama: retener comandos"
            );

        paso(
            0,1,2'b01,1,2'b10,
            "Renovacion de ambos"
        );

        $display("OK: Comandos y retencion");

        // =================================
        // D. TIMEOUT Y TRAMA TERMINAL
        // =================================

        // Llevar ambos AGE hasta 4.
        // RF1 y RF2 siguen registrados en 1,
        // pero RF_OK_EFF debe caer por EXPIRE.

        repeat (4)
            paso(
                0,0,2'b00,0,2'b00,
                "Avance hacia terminal"
            );

        if (
            dut.RF1 !== 1'b1 ||
            dut.RF2 !== 1'b1 ||
            RF_OK_EFF !== 1'b0
        )
            $fatal(
                1,
                "Inhibicion anticipada incorrecta"
            );

        $display("OK: Timeout anticipado");

        // J1 recibe una trama en terminal.
        // J2 no recibe ninguna y expira.

        paso(
            0,1,2'b10,0,2'b00,
            "J1 rescata enlace, J2 expira"
        );

        if (
            RF1_OK_EFF !== 1'b1 ||
            RF2_OK_EFF !== 1'b0
        )
            $fatal(
                1,
                "Prioridad de trama terminal incorrecta"
            );

        $display("OK: Trama domina timeout terminal");

        // Recuperar J2.
        paso(
            0,0,2'b00,1,2'b01,
            "Recuperar enlace J2"
        );

        if (RF_OK_EFF !== 1'b1)
            $fatal(1,"Recuperacion J2 incorrecta");

        $display("OK: Recuperacion de J2");

        // =================================
        // E. EXPIRACION SIMULTANEA
        // =================================

        // Reiniciar edades de ambos enlaces.
        paso(
            0,1,2'b01,1,2'b10,
            "Renovar ambos enlaces"
        );

        repeat (4)
            paso(
                0,0,2'b00,0,2'b00,
                "Preparar vencimiento simultaneo"
            );

        paso(
            0,0,2'b00,0,2'b00,
            "Expiracion simultanea"
        );

        if (
            dut.RF1 !== 1'b0 ||
            dut.RF2 !== 1'b0 ||
            RF_OK_EFF !== 1'b0
        )
            $fatal(
                1,
                "Expiracion simultanea incorrecta"
            );

        $display("OK: Expiracion simultanea");

        // Los contadores quedan saturados.
        repeat (3)
            paso(
                0,0,2'b00,0,2'b00,
                "Timeout sostenido"
            );

        if (
            dut.AGE1 !== 25'd4 ||
            dut.AGE2 !== 25'd4
        )
            $fatal(
                1,
                "Los contadores deben saturarse"
            );

        $display("OK: Contadores saturados");

        // =================================
        // F. RECUPERACION INDEPENDIENTE
        // =================================

        paso(
            0,1,2'b01,0,2'b00,
            "Recuperar solo J1"
        );

        if (RF_OK_EFF !== 1'b0)
            $fatal(1,"J2 sigue sin enlace");

        paso(
            0,0,2'b00,1,2'b10,
            "Recuperar J2"
        );

        if (RF_OK_EFF !== 1'b1)
            $fatal(1,"Recuperacion conjunta incorrecta");

        paso(
            0,1,2'b00,1,2'b11,
            "Comandos 00 y 11"
        );

        $display("OK: Recuperacion independiente");

        // =================================
        // G. PRIORIDAD DE INIT_GLOBAL
        // =================================

        paso(
            1,1,2'b11,1,2'b10,
            "INIT sobre tramas validas"
        );

        if (
            RF_OK_EFF !== 1'b0 ||
            CMD_J1 !== 2'b00 ||
            CMD_J2 !== 2'b00
        )
            $fatal(
                1,
                "INIT_GLOBAL no tiene prioridad"
            );

        $display("OK: Prioridad INIT_GLOBAL");

        // =================================
        // H. VENCIMIENTO INDEPENDIENTE J1
        // =================================

        repeat (2)
            paso(
                0,0,2'b00,0,2'b00,
                "Sin enlaces despues de INIT"
            );

        paso(
            0,1,2'b01,1,2'b10,
            "Restablecer ambos enlaces"
        );

        repeat (3)
            paso(
                0,0,2'b00,0,2'b00,
                "Envejecer ambos enlaces"
            );

        // Renovar solo J2.
        // J1 alcanza el valor terminal.
        paso(
            0,0,2'b00,1,2'b01,
            "Renovar J2 antes de timeout J1"
        );

        paso(
            0,0,2'b00,0,2'b00,
            "Expiracion independiente J1"
        );

        if (
            dut.RF1 !== 1'b0 ||
            dut.RF2 !== 1'b1
        )
            $fatal(
                1,
                "Expiracion independiente J1 incorrecta"
            );

        paso(
            0,1,2'b10,0,2'b00,
            "Recuperar J1"
        );

        if (RF_OK_EFF !== 1'b1)
            $fatal(
                1,
                "Recuperacion final incorrecta"
            );

        $display("OK: Expiracion independiente J1");

        // =================================
        // I. RESULTADOS FINALES
        // =================================

        if (
            pruebas != 39 ||
            tramas1 != 10 ||
            tramas2 != 10 ||
            vencimientos1 != 2 ||
            vencimientos2 != 2 ||
            rescates_terminal != 1
        )
            $fatal(
                1,
                "Conteo final de pruebas incorrecto"
            );

        $display("------------------------------");

        $display(
            "CICLOS VERIFICADOS: %0d",
            pruebas
        );

        $display(
            "TRAMAS J1: %0d",
            tramas1
        );

        $display(
            "TRAMAS J2: %0d",
            tramas2
        );

        $display(
            "VENCIMIENTOS J1: %0d",
            vencimientos1
        );

        $display(
            "VENCIMIENTOS J2: %0d",
            vencimientos2
        );

        $display(
            "RESCATES EN TERMINAL: %0d",
            rescates_terminal
        );

        $display(
            "RF_OK_EFF FINAL: %b",
            RF_OK_EFF
        );

        $display(
            "FIN TESTBENCH SUPERVISOR RF"
        );

        $display("------------------------------");

        $finish;

    end

endmodule