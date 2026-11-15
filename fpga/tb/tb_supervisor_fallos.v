`timescale 1ns/1ps

module tb_supervisor_fallos;

    // ------------------------------------
    // 1. Entradas del supervisor
    // ------------------------------------

    reg [2:0] STATE;

    reg [3:0] SCORE_J1;
    reg [3:0] SCORE_J2;

    reg [2:0] YP1;
    reg [2:0] YP2;
    reg [3:0] XB;

    reg FAULT_TX;

    // ------------------------------------
    // 2. Salidas del supervisor
    // ------------------------------------

    wire INVALID_FSM;
    wire INVALID_BCD_J1;
    wire INVALID_BCD_J2;
    wire INVALID_YP1;
    wire INVALID_YP2;
    wire INVALID_XB;

    wire FAULT_RECOVER;

    integer pruebas;
    integer casos_con_fallo;
    integer casos_sin_fallo;

    integer i;
    integer j;

    // ------------------------------------
    // 3. Modulo bajo prueba
    // ------------------------------------

    supervisor_fallos dut (
        .STATE(STATE),

        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),

        .YP1(YP1),
        .YP2(YP2),
        .XB(XB),

        .FAULT_TX(FAULT_TX),

        .INVALID_FSM(INVALID_FSM),
        .INVALID_BCD_J1(INVALID_BCD_J1),
        .INVALID_BCD_J2(INVALID_BCD_J2),

        .INVALID_YP1(INVALID_YP1),
        .INVALID_YP2(INVALID_YP2),
        .INVALID_XB(INVALID_XB),

        .FAULT_RECOVER(FAULT_RECOVER)
    );

    // ------------------------------------
    // 4. Tarea de comprobacion
    // ------------------------------------

    task comprobar;

        input [2:0] estado;
        input [3:0] score1;
        input [3:0] score2;
        input [2:0] paleta1;
        input [2:0] paleta2;
        input [3:0] pelota_x;
        input fallo_tx;

        input [8*80-1:0] nombre;

        // Referencia independiente
        reg exp_fsm;
        reg exp_bcd1;
        reg exp_bcd2;
        reg exp_yp1;
        reg exp_yp2;
        reg exp_xb;
        reg exp_fault;

        begin

            // Aplicar las entradas
            STATE = estado;

            SCORE_J1 = score1;
            SCORE_J2 = score2;

            YP1 = paleta1;
            YP2 = paleta2;
            XB = pelota_x;

            FAULT_TX = fallo_tx;

            // Modelo de referencia basado
            // en los intervalos permitidos.

            exp_fsm =
                (estado == 3'd6) ||
                (estado == 3'd7);

            exp_bcd1 = (score1 > 4'd9);
            exp_bcd2 = (score2 > 4'd9);

            exp_yp1 = (paleta1 > 3'd6);
            exp_yp2 = (paleta2 > 3'd6);

            exp_xb =
                (pelota_x < 4'd1) ||
                (pelota_x > 4'd14);

            exp_fault =
                exp_fsm ||
                exp_bcd1 ||
                exp_bcd2 ||
                exp_yp1 ||
                exp_yp2 ||
                exp_xb ||
                fallo_tx;

            // Estabilizacion combinacional
            #1;

            // Comparar todos los detectores
            // y la recuperacion global.

            if (
                INVALID_FSM !== exp_fsm ||
                INVALID_BCD_J1 !== exp_bcd1 ||
                INVALID_BCD_J2 !== exp_bcd2 ||
                INVALID_YP1 !== exp_yp1 ||
                INVALID_YP2 !== exp_yp2 ||
                INVALID_XB !== exp_xb ||
                FAULT_RECOVER !== exp_fault
            ) begin

                $display("-------------------------");
                $display("ERROR: %0s", nombre);

                $display(
                    "STATE=%b SCORE1=%d SCORE2=%d",
                    estado, score1, score2
                );

                $display(
                    "YP1=%d YP2=%d XB=%d TX=%b",
                    paleta1, paleta2,
                    pelota_x, fallo_tx
                );

                $display(
                    "Esperado FSM=%b BCD1=%b BCD2=%b",
                    exp_fsm, exp_bcd1, exp_bcd2
                );

                $display(
                    "Esperado YP1=%b YP2=%b XB=%b",
                    exp_yp1, exp_yp2, exp_xb
                );

                $display(
                    "FAULT_RECOVER esperado=%b obtenido=%b",
                    exp_fault, FAULT_RECOVER
                );

                $fatal(
                    1,
                    "Fallo en supervisor_fallos"
                );

            end

            pruebas = pruebas + 1;

            if (exp_fault)
                casos_con_fallo =
                    casos_con_fallo + 1;
            else
                casos_sin_fallo =
                    casos_sin_fallo + 1;

        end

    endtask

    // ------------------------------------
    // 5. Secuencia de pruebas
    // ------------------------------------

    initial begin

        STATE = 3'd0;
        SCORE_J1 = 4'd0;
        SCORE_J2 = 4'd0;
        YP1 = 3'd3;
        YP2 = 3'd3;
        XB = 4'd7;
        FAULT_TX = 1'b0;

        pruebas = 0;
        casos_con_fallo = 0;
        casos_sin_fallo = 0;

        $display("------------------------------");
        $display("TESTBENCH SUPERVISOR FALLOS");
        $display("------------------------------");

        // =================================
        // A. PRUEBAS DIRIGIDAS
        // =================================

        comprobar(
            1,0,0,3,3,7,0,
            "Estado normal de juego"
        );

        comprobar(
            0,0,0,3,3,7,0,
            "Estado ESPERA valido"
        );

        comprobar(
            5,0,0,3,3,7,0,
            "Estado PAUSA_MANUAL valido"
        );

        comprobar(
            6,0,0,3,3,7,0,
            "Estado FSM invalido 110"
        );

        comprobar(
            7,0,0,3,3,7,0,
            "Estado FSM invalido 111"
        );

        comprobar(
            1,9,9,3,3,7,0,
            "Puntajes BCD maximos validos"
        );

        comprobar(
            1,10,0,3,3,7,0,
            "BCD invalido J1"
        );

        comprobar(
            1,0,15,3,3,7,0,
            "BCD invalido J2"
        );

        comprobar(
            1,10,11,3,3,7,0,
            "Ambos puntajes invalidos"
        );

        comprobar(
            1,0,0,7,3,7,0,
            "Posicion invalida paleta J1"
        );

        comprobar(
            1,0,0,3,7,7,0,
            "Posicion invalida paleta J2"
        );

        comprobar(
            1,0,0,3,3,0,0,
            "Pelota XB igual a cero"
        );

        comprobar(
            1,0,0,3,3,15,0,
            "Pelota XB igual a quince"
        );

        comprobar(
            1,0,0,3,3,7,1,
            "Fallo del transmisor MAX7219"
        );

        comprobar(
            7,15,15,7,7,0,1,
            "Multiples fallos simultaneos"
        );

        comprobar(
            4,9,9,6,6,14,0,
            "Limites validos en FIN"
        );

        comprobar(
            1,0,0,3,3,7,0,
            "Retorno a entradas validas"
        );

        $display(
            "OK: 17 pruebas dirigidas"
        );

        // =================================
        // B. TODOS LOS ESTADOS FSM
        // =================================

        for (i=0; i<8; i=i+1) begin

            comprobar(
                i[2:0],0,0,3,3,7,0,
                "Barrido completo FSM"
            );

        end

        $display(
            "OK: 8 estados FSM verificados"
        );

        // =================================
        // C. TODOS LOS PARES BCD
        // =================================

        for (i=0; i<16; i=i+1) begin

            for (j=0; j<16; j=j+1) begin

                comprobar(
                    1,
                    i[3:0],
                    j[3:0],
                    3,3,7,0,
                    "Barrido BCD"
                );

            end

        end

        $display(
            "OK: 256 pares BCD verificados"
        );

        // =================================
        // D. TODAS LAS PALETAS
        // =================================

        for (i=0; i<8; i=i+1) begin

            for (j=0; j<8; j=j+1) begin

                comprobar(
                    1,0,0,
                    i[2:0],
                    j[2:0],
                    7,0,
                    "Barrido de paletas"
                );

            end

        end

        $display(
            "OK: 64 pares de paletas verificados"
        );

        // =================================
        // E. TODAS LAS POSICIONES XB
        // =================================

        for (i=0; i<16; i=i+1) begin

            comprobar(
                1,0,0,3,3,
                i[3:0],0,
                "Barrido XB"
            );

        end

        $display(
            "OK: 16 posiciones XB verificadas"
        );

        // =================================
        // F. FALLO DEL TRANSMISOR
        // =================================

        comprobar(
            1,0,0,3,3,7,0,
            "FAULT_TX inactivo"
        );

        comprobar(
            1,0,0,3,3,7,1,
            "FAULT_TX activo"
        );

        $display(
            "OK: Ambos valores de FAULT_TX"
        );

        // =================================
        // G. RESULTADOS FINALES
        // =================================

        if (pruebas != 363)
            $fatal(
                1,
                "Cantidad incorrecta de pruebas"
            );

        if (
            casos_con_fallo +
            casos_sin_fallo != pruebas
        )
            $fatal(
                1,
                "Contadores inconsistentes"
            );

        $display("------------------------------");

        $display(
            "PRUEBAS DIRIGIDAS: 17"
        );

        $display(
            "BARRIDO FSM: 8"
        );

        $display(
            "BARRIDO BCD: 256"
        );

        $display(
            "BARRIDO PALETAS: 64"
        );

        $display(
            "BARRIDO XB: 16"
        );

        $display(
            "BARRIDO FAULT_TX: 2"
        );

        $display(
            "CASOS CON FALLO: %0d",
            casos_con_fallo
        );

        $display(
            "CASOS SIN FALLO: %0d",
            casos_sin_fallo
        );

        $display(
            "TOTAL VERIFICADO: %0d",
            pruebas
        );

        $display(
            "FIN TESTBENCH SUPERVISOR FALLOS"
        );

        $display("------------------------------");

        $finish;

    end

endmodule