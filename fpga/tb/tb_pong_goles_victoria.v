`timescale 1ns/1ps
// ============================================================
// PF ELECTRONICA DIGITAL 1 - FASE 3
// TB dirigido de integracion: goles, puntuacion, saque y FIN.
//
// Instancia el pong_top REAL. Solo acelera los temporizadores.
// Para provocar goles deterministas, ubica temporalmente
// registros de la pelota con force/release. NO fuerza GOAL,
// CAPTURE_GOAL, POINT_EN, marcadores ni STATE: esas rutas se
// prueban de extremo a extremo.
//
// IMPORTANTE: No sintetizable. Ejecutar SOLO en Questa.
// ============================================================
module tb_pong_goles_victoria;

    localparam [2:0] ESPERA = 3'd0;
    localparam [2:0] JUEGO  = 3'd1;
    localparam [2:0] PUNTO  = 3'd2;
    localparam [2:0] FIN    = 3'd4;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;     // 50 MHz nominal

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

    integer ciclos_rf = 0;
    integer capturas = 0;
    integer ciclos_punto = 0;
    integer goles_probados = 0;
    integer verificaciones = 0;
    integer k;

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

    // Tramas validas cada diez ciclos, para ambos jugadores.
    always @(negedge CLK_SYS) begin
        FRAME_1_VALID = 1'b0;
        FRAME_2_VALID = 1'b0;
        if (RF_HEARTBEAT) begin
            if (ciclos_rf == 0) begin
                FRAME_1_VALID = 1'b1;
                FRAME_2_VALID = 1'b1;
            end
            if (ciclos_rf == 9)
                ciclos_rf = 0;
            else
                ciclos_rf = ciclos_rf + 1;
        end else begin
            ciclos_rf = 0;
        end
    end

    // Cuenta los eventos reales, sin conducirlos artificialmente.
    always @(posedge CLK_SYS) begin
        if (!dut.INIT_GLOBAL && dut.CAPTURE_GOAL)
            capturas = capturas + 1;
        if (!dut.INIT_GLOBAL && dut.POINT_EN)
            ciclos_punto = ciclos_punto + 1;
    end

    task esperar_estado;
        input [2:0] esperado;
        input integer max_ciclos;
        integer n;
        begin
            n = 0;
            while (dut.STATE !== esperado && n < max_ciclos) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.STATE !== esperado)
                $fatal(1, "Timeout STATE: observado=%0d esperado=%0d", dut.STATE, esperado);
        end
    endtask

    task esperar_init_liberado;
        integer n;
        begin
            n = 0;
            while (dut.INIT_GLOBAL !== 1'b0 && n < 50) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.INIT_GLOBAL !== 1'b0)
                $fatal(1, "INIT_GLOBAL no se libero");
        end
    endtask

    task esperar_rf;
        integer n;
        begin
            n = 0;
            while (dut.RF_OK_EFF !== 1'b1 && n < 50) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.RF_OK_EFF !== 1'b1)
                $fatal(1, "Los enlaces RF no se habilitaron");
        end
    endtask

    task pulsar_start;
        begin
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            START_RAW = 1'b0;
            repeat (10) @(negedge CLK_SYS);
            esperar_estado(JUEGO, 5);
            if (dut.GAME_EN !== 1'b1)
                $fatal(1, "START no habilito GAME_EN");
        end
    endtask

    // Dirigido: lado_derecho=1 -> falla J2 y anota J1.
    //            lado_derecho=0 -> falla J1 y anota J2.
    // YB=0, PHASE=0 y paletas centradas (YP1=YP2=3)
    // garantizan que no haya impacto en la fila del evento.
    // No se fuerzan ni goles ni puntaje.
    task provocar_y_verificar_gol;
        input lado_derecho;
        input [3:0] score1_esperado;
        input [3:0] score2_esperado;
        input fin_esperado;
        integer n;
        reg saque_antes;
        reg [3:0] score1_antes, score2_antes;
        reg [2:0] estado_final;
        begin
            if (dut.STATE !== JUEGO || dut.RF_OK_EFF !== 1'b1)
                $fatal(1, "No se puede probar el gol fuera de JUEGO o con RF invalida");
            if (dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
                $fatal(1, "Paletas fuera de centro: el escenario dirigido no es valido");

            saque_antes = dut.SERVE_DIR;
            score1_antes = SCORE_J1_BCD;
            score2_antes = SCORE_J2_BCD;

            // Inyeccion dirigida SOLO de un estado fisico valido.
            @(negedge CLK_SYS);
            if (lado_derecho) begin
                force dut.u_pelota.XB = 4'd14;
                force dut.u_pelota.DX = 1'b1;
            end else begin
                force dut.u_pelota.XB = 4'd1;
                force dut.u_pelota.DX = 1'b0;
            end
            force dut.u_pelota.YB = 3'd0;
            force dut.u_pelota.PHASE = 1'b0;
            #1;
            if (dut.FAULT_RECOVER !== 1'b0)
                $fatal(1, "Inyeccion de posicion valida activo FAULT_RECOVER");

            // Espera el tick REAL que provoca la colision/gol.
            n = 0;
            while (dut.CAPTURE_GOAL !== 1'b1 && n < 200) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.CAPTURE_GOAL !== 1'b1)
                $fatal(1, "No se genero CAPTURE_GOAL en el borde (lado=%0d)", lado_derecho);
            if (lado_derecho) begin
                if (dut.GOAL_J1 !== 1'b1 || dut.GOAL_J2 !== 1'b0 ||
                    dut.HIT_J1 !== 1'b0 || dut.HIT_J2 !== 1'b0)
                    $fatal(1, "Clasificacion incorrecta: gol de J1 en borde derecho");
            end else begin
                if (dut.GOAL_J1 !== 1'b0 || dut.GOAL_J2 !== 1'b1 ||
                    dut.HIT_J1 !== 1'b0 || dut.HIT_J2 !== 1'b0)
                    $fatal(1, "Clasificacion incorrecta: gol de J2 en borde izquierdo");
            end
            if (SCORE_J1_BCD !== score1_antes || SCORE_J2_BCD !== score2_antes)
                $fatal(1, "El puntaje incremento antes de PUNTO");

            // En el flanco se captura el anotador y entra en PUNTO.
            @(posedge CLK_SYS);
            #1;
            if (dut.STATE !== PUNTO)
                $fatal(1, "El gol no llevo la FSM a PUNTO");
            if (dut.SERVE_DIR !== ~saque_antes)
                $fatal(1, "SERVE_DIR no alterno al capturar gol");

            // Liberamos antes del flanco PUNTO -> ESPERA/FIN.
            release dut.u_pelota.XB;
            release dut.u_pelota.DX;
            release dut.u_pelota.YB;
            release dut.u_pelota.PHASE;

            if (fin_esperado)
                estado_final = FIN;
            else
                estado_final = ESPERA;
            esperar_estado(estado_final, 5);

            if (SCORE_J1_BCD !== score1_esperado ||
                SCORE_J2_BCD !== score2_esperado)
                $fatal(1, "Marcador: observado %0d:%0d esperado %0d:%0d",
                    SCORE_J1_BCD, SCORE_J2_BCD,
                    score1_esperado, score2_esperado);

            if (!fin_esperado) begin
                if (dut.XB !== 4'd7 || dut.YB !== 3'd3)
                    $fatal(1, "El siguiente saque no centro la pelota");
                if (dut.DX !== dut.SERVE_DIR)
                    $fatal(1, "Direccion de saque no coincide con SERVE_DIR");
            end

            // Comprueba que no se incremente de nuevo en ESPERA/FIN.
            repeat (3) @(negedge CLK_SYS);
            if (dut.STATE !== estado_final ||
                SCORE_J1_BCD !== score1_esperado ||
                SCORE_J2_BCD !== score2_esperado)
                $fatal(1, "Hubo duplicacion de punto o cambio inesperado de estado");

            goles_probados = goles_probados + 1;
            verificaciones = verificaciones + 1;
            $display("OK gol %0d: anota J%0d | marcador %0d:%0d | estado %0d",
                goles_probados, lado_derecho ? 1 : 2,
                SCORE_J1_BCD, SCORE_J2_BCD, dut.STATE);
        end
    endtask

    initial begin
        $display("====================================================");
        $display("TB PONG INTEGRACION: GOLES, PUNTUACION Y VICTORIA");
        $display("====================================================");

        repeat (4) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        RF_HEARTBEAT = 1'b1;
        esperar_init_liberado();
        esperar_estado(ESPERA, 5);
        esperar_rf();
        if (SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0 ||
            dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3 ||
            dut.SERVE_DIR !== 1'b1)
            $fatal(1, "Estado inicial incorrecto");
        verificaciones = verificaciones + 1;
        $display("OK 1: reset, RF, marcador 0:0 y saque inicial");

        // Primer gol por borde izquierdo: anota J2.
        pulsar_start();
        provocar_y_verificar_gol(1'b0, 4'd0, 4'd1, 1'b0);

        // Nueve goles por borde derecho: J1 alcanza 9 y gana.
        // Los ocho primeros vuelven a ESPERA, el noveno a FIN.
        for (k = 1; k <= 9; k = k + 1) begin
            pulsar_start();
            provocar_y_verificar_gol(1'b1, k, 4'd1, (k == 9));
        end

        // En FIN se retienen resultados, no se rearma con START.
        begin : pulsar_start_fin
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            START_RAW = 1'b0;
            repeat (120) @(negedge CLK_SYS);
            if (dut.STATE !== FIN || dut.GAME_EN !== 1'b0 ||
                SCORE_J1_BCD !== 4'd9 || SCORE_J2_BCD !== 4'd1)
                $fatal(1, "FIN no retuvo la victoria 9:1");
        end
        verificaciones = verificaciones + 1;
        $display("OK: FIN retiene resultado 9:1 pese a START");

        // RESET fisico vuelve a ESPERA y limpia marcadores.
        @(negedge CLK_SYS);
        RESET_RAW = 1'b1;
        repeat (10) @(negedge CLK_SYS);
        if (dut.INIT_GLOBAL !== 1'b1 || dut.STATE !== ESPERA ||
            SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0)
            $fatal(1, "RESET fisico no limpio FIN y puntajes");
        RESET_RAW = 1'b0;
        esperar_init_liberado();
        esperar_estado(ESPERA, 5);
        if (dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3 ||
            dut.SERVE_DIR !== 1'b1)
            $fatal(1, "RESET no restauro condiciones iniciales");
        verificaciones = verificaciones + 1;
        $display("OK: RESET sale de FIN y restablece 0:0");

        if (capturas !== 10 || ciclos_punto !== 10)
            $fatal(1, "Eventos de gol duplicados/perdidos: CAPTURE=%0d POINT_EN=%0d",
                capturas, ciclos_punto);
        $display("OK: 10 CAPTURE_GOAL y 10 POINT_EN, uno por gol");
        $display("====================================================");
        $display("COMPROBACIONES: %0d / 13", verificaciones);
        $display("GOLES PROBADOS: %0d", goles_probados);
        $display("CAPTURE_GOAL OBSERVADOS: %0d", capturas);
        $display("POINT_EN OBSERVADOS: %0d", ciclos_punto);
        $display("FIN TB_PONG_GOLES_VICTORIA");
        $display("====================================================");
        $finish;
    end

    initial begin
        #600000;
        $fatal(1, "Timeout global: prueba de goles/victoria incompleta");
    end
endmodule
