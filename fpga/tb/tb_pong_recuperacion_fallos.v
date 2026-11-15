`timescale 1ns/1ps
// ============================================================
// PF ELECTRONICA DIGITAL 1 - FASE 3
// TB integrado: fallos de registros y recuperacion global.
//
// Instancia pong_top REAL. Acelera SOLO parametros de prueba.
// Inyecta corrupciones temporales mediante force/release sobre
// senales observadas por el supervisor de fallos; no fuerza
// FAULT_RECOVER, INIT_GLOBAL, los botones ni la FSM de reset.
//
// La prueba FAULT_TX fuerza la linea de alarma; valida su
// propagacion al reset global, NO el detector interno de TX.
// SOLO simulacion Questa. No agregar a Quartus.
// ============================================================
module tb_pong_recuperacion_fallos;

    localparam [2:0] ESPERA = 3'd0;
    localparam [2:0] JUEGO  = 3'd1;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b1;
    reg PAUSE_RAW = 1'b0;
    reg [1:0] CMD_RX1 = 2'b00;
    reg [1:0] CMD_RX2 = 2'b00;
    reg FRAME_1_VALID = 1'b0;
    reg FRAME_2_VALID = 1'b0;
    reg RF_HEARTBEAT = 1'b0;

    wire DIN, CLK_LED, LOAD;
    wire [3:0] SCORE_J1_BCD, SCORE_J2_BCD;

    integer rf_contador = 0;
    integer chequeos = 0;
    integer inyecciones = 0;
    integer recuperaciones = 0;

    pong_top #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4),
        .N_RF(25'd400),
        .N_BALL(24'd96),
        .N_PADDLE(24'd128),
        .H_LED(2),
        .FAR_IS_B(1'b1)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_RAW(START_RAW),
        .RESET_RAW(RESET_RAW),
        .PAUSE_RAW(PAUSE_RAW),
        .CMD_RX1(CMD_RX1),
        .FRAME_1_VALID(FRAME_1_VALID),
        .CMD_RX2(CMD_RX2),
        .FRAME_2_VALID(FRAME_2_VALID),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .SCORE_J1_BCD(SCORE_J1_BCD),
        .SCORE_J2_BCD(SCORE_J2_BCD)
    );

    // Mantiene vivos ambos enlaces; las tramas son pulsos
    // sincronizados en flancos negativos, lejos de la captura.
    always @(negedge CLK_SYS) begin
        FRAME_1_VALID = 1'b0;
        FRAME_2_VALID = 1'b0;
        if (RF_HEARTBEAT) begin
            if (rf_contador == 0) begin
                FRAME_1_VALID = 1'b1;
                FRAME_2_VALID = 1'b1;
            end
            if (rf_contador == 9)
                rf_contador = 0;
            else
                rf_contador = rf_contador + 1;
        end else begin
            rf_contador = 0;
        end
    end

    task esperar_init_y_rf;
        integer n;
        begin
            n = 0;
            while ((dut.INIT_GLOBAL !== 1'b0 ||
                    dut.RF_OK_EFF !== 1'b1) && n < 80) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.INIT_GLOBAL !== 1'b0 ||
                dut.RF_OK_EFF !== 1'b1)
                $fatal(1, "Timeout: INIT no libera o RF no valida");
        end
    endtask

    task comprobar_reset_seguro;
        begin
            if (dut.INIT_GLOBAL !== 1'b0 ||
                dut.FAULT_RECOVER !== 1'b0 ||
                dut.STATE !== ESPERA ||
                dut.GAME_EN !== 1'b0 ||
                dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
                dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3 ||
                dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
                dut.PHASE !== 1'b0 ||
                dut.SERVE_DIR !== 1'b1 ||
                SCORE_J1_BCD !== 4'd0 ||
                SCORE_J2_BCD !== 4'd0)
                $fatal(1, "Recuperacion incompleta: STATE=%b XB=%d YB=%d YP1=%d YP2=%d S1=%d S2=%d FAULT=%b INIT=%b",
                    dut.STATE, dut.XB, dut.YB, dut.YP1, dut.YP2,
                    SCORE_J1_BCD, SCORE_J2_BCD,
                    dut.FAULT_RECOVER, dut.INIT_GLOBAL);
            if (dut.u_temporizadores.CB !== 24'd0 ||
                dut.u_temporizadores.CP !== 24'd0)
                $fatal(1, "Contadores de temporizadores no regresaron a cero");
        end
    endtask

    task iniciar_juego;
        integer n;
        begin
            esperar_init_y_rf();
            if (dut.STATE !== ESPERA)
                $fatal(1, "Se esperaba ESPERA antes de pulsar START");
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            START_RAW = 1'b0;
            n = 0;
            while (dut.STATE !== JUEGO && n < 25) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.STATE !== JUEGO || dut.GAME_EN !== 1'b1 ||
                dut.FAULT_RECOVER !== 1'b0)
                $fatal(1, "START no habilito JUEGO despues de recuperar");
            repeat (5) @(negedge CLK_SYS);
            if (dut.STATE !== JUEGO || dut.INIT_GLOBAL !== 1'b0)
                $fatal(1, "JUEGO no se mantuvo estable");
        end
    endtask

    // ID de inyeccion:
    // 0 FSM=110; 1 FSM=111; 2 BCD J1=10; 3 BCD J2=15;
    // 4 YP1=7; 5 YP2=7; 6 XB=0; 7 XB=15; 8 FAULT_TX=1.
    task inyectar_y_recuperar;
        input integer id;
        input [8*40-1:0] etiqueta;
        begin
            if (dut.STATE !== JUEGO || dut.GAME_EN !== 1'b1 ||
                dut.RF_OK_EFF !== 1'b1 || dut.FAULT_RECOVER !== 1'b0)
                $fatal(1, "Precondicion de fallo no valida: %0s", etiqueta);

            @(negedge CLK_SYS);
            case (id)
                0: force dut.STATE    = 3'b110;
                1: force dut.STATE    = 3'b111;
                2: force dut.SCORE_J1 = 4'd10;
                3: force dut.SCORE_J2 = 4'd15;
                4: force dut.YP1      = 3'd7;
                5: force dut.YP2      = 3'd7;
                6: force dut.XB       = 4'd0;
                7: force dut.XB       = 4'd15;
                8: force dut.FAULT_TX = 1'b1;
                default: $fatal(1, "ID de prueba no soportado");
            endcase
            #1;

            // Comprobar el detector especifico, no solo el OR.
            case (id)
                0,1: if (dut.INVALID_FSM !== 1'b1)
                    $fatal(1, "No detecta FSM ilegal: %0s", etiqueta);
                2: if (dut.INVALID_BCD_J1 !== 1'b1)
                    $fatal(1, "No detecta BCD J1 invalido");
                3: if (dut.INVALID_BCD_J2 !== 1'b1)
                    $fatal(1, "No detecta BCD J2 invalido");
                4: if (dut.INVALID_YP1 !== 1'b1)
                    $fatal(1, "No detecta YP1=7");
                5: if (dut.INVALID_YP2 !== 1'b1)
                    $fatal(1, "No detecta YP2=7");
                6,7: if (dut.INVALID_XB !== 1'b1)
                    $fatal(1, "No detecta XB fuera del area valida");
                8: if (dut.FAULT_TX !== 1'b1)
                    $fatal(1, "No se aplico alarma TX");
            endcase

            if (dut.FAULT_RECOVER !== 1'b1 ||
                dut.INIT_GLOBAL !== 1'b1 ||
                dut.GAME_EN !== 1'b0)
                $fatal(1, "No se activo recuperacion inmediata: %0s", etiqueta);

            // Mantener la corrupcion hasta que el reset global
            // haya alcanzado dos flancos de reloj reales.
            repeat (2) @(posedge CLK_SYS);
            @(negedge CLK_SYS);
            case (id)
                0,1: release dut.STATE;
                2:   release dut.SCORE_J1;
                3:   release dut.SCORE_J2;
                4:   release dut.YP1;
                5:   release dut.YP2;
                6,7: release dut.XB;
                8:   release dut.FAULT_TX;
            endcase

            // Tras liberar el dato corrupto, la logica real del
            // dispositivo debe quedar en sus valores de reset.
            repeat (3) @(negedge CLK_SYS);
            comprobar_reset_seguro();
            inyecciones = inyecciones + 1;
            recuperaciones = recuperaciones + 1;
            chequeos = chequeos + 1;
            $display("OK %0d: %0s -> FAULT_RECOVER, INIT_GLOBAL, ESPERA y reset", chequeos, etiqueta);

            // Se exige poder reiniciar JUEGO tras CADA fallo.
            iniciar_juego();
        end
    endtask

    initial begin
        $display("===================================================");
        $display("TB PONG: SUPERVISION Y RECUPERACION DE FALLOS");
        $display("===================================================");

        repeat (4) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        RF_HEARTBEAT = 1'b1;
        esperar_init_y_rf();
        comprobar_reset_seguro();
        iniciar_juego();
        chequeos = chequeos + 1;
        $display("OK 1: POR/RESET, RF, START y JUEGO sin fallos falsos");

        inyectar_y_recuperar(0, "FSM ilegal 110");
        inyectar_y_recuperar(1, "FSM ilegal 111");
        inyectar_y_recuperar(2, "BCD J1 = 10");
        inyectar_y_recuperar(3, "BCD J2 = 15");
        inyectar_y_recuperar(4, "YP1 = 7");
        inyectar_y_recuperar(5, "YP2 = 7");
        inyectar_y_recuperar(6, "XB = 0");
        inyectar_y_recuperar(7, "XB = 15");
        inyectar_y_recuperar(8, "alarma externa FAULT_TX");

        // Prueba independiente del pulsador de reset desde JUEGO.
        @(negedge CLK_SYS);
        RESET_RAW = 1'b1;
        #1;
        if (dut.INIT_GLOBAL !== 1'b1)
            $fatal(1, "RESET_RAW no activo INIT_GLOBAL");
        repeat (10) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        esperar_init_y_rf();
        comprobar_reset_seguro();
        chequeos = chequeos + 1;
        $display("OK %0d: RESET_RAW durante JUEGO restituye ESPERA", chequeos);

        if (chequeos !== 11 || inyecciones !== 9 ||
            recuperaciones !== 9)
            $fatal(1, "Contadores incorrectos");

        $display("===================================================");
        $display("COMPROBACIONES: %0d / 11", chequeos);
        $display("FALLOS INYECTADOS: %0d", inyecciones);
        $display("RECUPERACIONES VERIFICADAS: %0d", recuperaciones);
        $display("FIN TB_PONG_RECUPERACION_FALLOS");
        $display("===================================================");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout general del testbench de recuperacion");
    end
endmodule
