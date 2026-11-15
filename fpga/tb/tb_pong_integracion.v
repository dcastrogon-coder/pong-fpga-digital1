`timescale 1ns/1ps

// FASE 3 - Prueba inicial de integracion del Pong.
// NOTA: Los parametros reducidos SOLO son para simulacion.
// No reemplaza los testbenches modulares ni la verificacion fisica.
module tb_pong_integracion;

    localparam [2:0] ESPERA       = 3'd0;
    localparam [2:0] JUEGO        = 3'd1;
    localparam [2:0] PAUSA_RF     = 3'd3;
    localparam [2:0] PAUSA_MANUAL = 3'd5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;   // 50 MHz nominal

    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b1;
    reg PAUSE_RAW = 1'b0;

    reg  [1:0] CMD_RX1 = 2'b00;
    reg  [1:0] CMD_RX2 = 2'b00;
    reg FRAME_1_VALID = 1'b0;
    reg FRAME_2_VALID = 1'b0;
    reg RF_HEARTBEAT = 1'b0;

    wire DIN, CLK_LED, LOAD;
    wire [3:0] SCORE_J1_BCD, SCORE_J2_BCD;

    integer ciclos_rf = 0;
    integer pulsos_load = 0;
    integer verificaciones = 0;
    integer rearmes = 0;
    integer eventos_start = 0;
    integer eventos_pause = 0;

    reg [3:0] xb_pausa;
    reg [2:0] yb_pausa, yp1_pausa, yp2_pausa;
    reg [3:0] score1_pausa, score2_pausa;
    integer load_antes;

    pong_top #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4),
        .N_RF(25'd200),
        .N_BALL(24'd64),
        .N_PADDLE(24'd80),
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

    // Genera tramas RF validas cada 10 ciclos cuando esta habilitado.
    // Cambiar CMD_RX sin una trama valida no actualizaria los comandos.
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
        end
        else begin
            ciclos_rf = 0;
        end
    end

    always @(posedge LOAD) begin
        if (!dut.INIT_GLOBAL) begin
            if (CLK_LED !== 1'b0)
                $fatal(1, "LOAD coincide con CLK_LED alto");
            pulsos_load = pulsos_load + 1;
        end
    end

    always @(posedge CLK_SYS) begin
        if (dut.START_PULSE)
            eventos_start = eventos_start + 1;
        if (dut.PAUSE_PULSE)
            eventos_pause = eventos_pause + 1;
        if (!dut.INIT_GLOBAL && dut.REARM_TIMERS) begin
            #1;
            if (dut.u_temporizadores.CB !== 24'd0 ||
                dut.u_temporizadores.CP !== 24'd0)
                $fatal(1, "REARM_TIMERS no llevo ambos contadores a cero");
            rearmes = rearmes + 1;
        end
    end

    task esperar_estado;
        input [2:0] estado_esperado;
        input integer max_ciclos;
        integer n;
        begin
            n = 0;
            while (dut.STATE !== estado_esperado && n < max_ciclos) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.STATE !== estado_esperado)
                $fatal(1, "Timeout: STATE=%b, esperado=%b", dut.STATE, estado_esperado);
        end
    endtask

    task esperar_rf;
        input valor_esperado;
        input integer max_ciclos;
        integer n;
        begin
            n = 0;
            while (dut.RF_OK_EFF !== valor_esperado && n < max_ciclos) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.RF_OK_EFF !== valor_esperado)
                $fatal(1, "Timeout: RF_OK_EFF=%b, esperado=%b", dut.RF_OK_EFF, valor_esperado);
        end
    endtask

    task presionar_start;
        begin
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            START_RAW = 1'b0;
            repeat (10) @(negedge CLK_SYS);
        end
    endtask

    task presionar_pause;
        begin
            @(negedge CLK_SYS);
            PAUSE_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            PAUSE_RAW = 1'b0;
            repeat (10) @(negedge CLK_SYS);
        end
    endtask

    initial begin
        $display("===============================================");
        $display("TB INTEGRACION PONG: ARRANQUE, RF, START, PAUSE");
        $display("===============================================");

        // 1. RESET fisico, arranque y liberacion filtrada.
        repeat (4) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        RF_HEARTBEAT = 1'b1;

        // El filtro reducido libera en pocos ciclos.
        begin : esperar_inicio
            integer n;
            n = 0;
            while (dut.INIT_GLOBAL !== 1'b0 && n < 30) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.INIT_GLOBAL !== 1'b0)
                $fatal(1, "INIT_GLOBAL no se desactivo tras liberar RESET");
        end
        esperar_estado(ESPERA, 5);
        if (SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0 ||
            dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
            $fatal(1, "Posiciones/puntajes iniciales incorrectos");
        if (dut.FAULT_RECOVER !== 1'b0)
            $fatal(1, "FAULT_RECOVER activo en condiciones iniciales validas");
        verificaciones = verificaciones + 1;
        $display("OK 1: Arranque, reset y posiciones iniciales");

        // 2. Ambas tramas RF habilitan la validez conjunta.
        esperar_rf(1'b1, 30);
        verificaciones = verificaciones + 1;
        $display("OK 2: Dos enlaces RF vigentes");

        // 3. START activa JUEGO.
        presionar_start();
        esperar_estado(JUEGO, 5);
        if (dut.GAME_EN !== 1'b1)
            $fatal(1, "GAME_EN no se activo en JUEGO");
        verificaciones = verificaciones + 1;
        $display("OK 3: START conduce a JUEGO");

        // 4. PAUSE conserva la dinamica del juego.
        presionar_pause();
        esperar_estado(PAUSA_MANUAL, 5);
        if (dut.GAME_EN !== 1'b0)
            $fatal(1, "GAME_EN no se desactivo en PAUSA_MANUAL");
        xb_pausa = dut.XB;
        yb_pausa = dut.YB;
        yp1_pausa = dut.YP1;
        yp2_pausa = dut.YP2;
        score1_pausa = SCORE_J1_BCD;
        score2_pausa = SCORE_J2_BCD;
        load_antes = pulsos_load;

        // 3000 ciclos permiten observar la actividad serial del MAX7219
        // aun cuando el movimiento permanece pausado.
        repeat (3000) @(negedge CLK_SYS);
        if (dut.STATE !== PAUSA_MANUAL || dut.GAME_EN !== 1'b0 ||
            dut.XB !== xb_pausa || dut.YB !== yb_pausa ||
            dut.YP1 !== yp1_pausa || dut.YP2 !== yp2_pausa ||
            SCORE_J1_BCD !== score1_pausa || SCORE_J2_BCD !== score2_pausa)
            $fatal(1, "Movimiento/puntaje cambio durante PAUSA_MANUAL");
        verificaciones = verificaciones + 1;
        $display("OK 4: PAUSA_MANUAL congela movimiento y puntajes");

        if (pulsos_load <= load_antes || pulsos_load < 14)
            $fatal(1, "No se detecto refresco del MAX7219 durante PAUSA");
        verificaciones = verificaciones + 1;
        $display("OK 5: MAX7219 transmite durante PAUSA (%0d LOAD)", pulsos_load);

        // 5. La segunda pulsacion PAUSE reanuda el juego.
        presionar_pause();
        esperar_estado(JUEGO, 5);
        if (dut.GAME_EN !== 1'b1)
            $fatal(1, "GAME_EN no se reanudo");
        verificaciones = verificaciones + 1;
        $display("OK 6: Segunda PAUSE reanuda JUEGO");

        // 6. Cesar las tramas causa perdida RF y PAUSA_RF.
        RF_HEARTBEAT = 1'b0;
        esperar_rf(1'b0, 240);
        esperar_estado(PAUSA_RF, 5);
        if (dut.GAME_EN !== 1'b0)
            $fatal(1, "GAME_EN no se inhibio por perdida RF");
        verificaciones = verificaciones + 1;
        $display("OK 7: Timeout RF conduce a PAUSA_RF");

        // 7. Vuelven las tramas, pero se exige START para reanudar.
        RF_HEARTBEAT = 1'b1;
        esperar_rf(1'b1, 30);
        repeat (4) @(negedge CLK_SYS);
        if (dut.STATE !== PAUSA_RF)
            $fatal(1, "PAUSA_RF abandono su estado sin START");
        presionar_start();
        esperar_estado(JUEGO, 5);
        if (dut.GAME_EN !== 1'b1)
            $fatal(1, "No regreso a JUEGO tras recuperar RF y START");
        verificaciones = verificaciones + 1;
        $display("OK 8: RF restaurado y nuevo START reanudan juego");

        if (rearmes < 2 || eventos_start < 2 || eventos_pause < 2)
            $fatal(1, "Faltaron eventos START/PAUSE o rearmes");
        verificaciones = verificaciones + 1;
        $display("OK 9: Eventos y REARM_TIMERS observados");

        $display("===============================================");
        $display("COMPROBACIONES DE INTEGRACION: %0d / 9", verificaciones);
        $display("PULSOS LOAD OBSERVADOS: %0d", pulsos_load);
        $display("START_PULSE OBSERVADOS: %0d", eventos_start);
        $display("PAUSE_PULSE OBSERVADOS: %0d", eventos_pause);
        $display("REARM_TIMERS OBSERVADOS: %0d", rearmes);
        $display("FIN TB_PONG_INTEGRACION");
        $display("===============================================");
        $finish;
    end

    initial begin
        #300000;
        $fatal(1, "Timeout general de la simulacion de integracion");
    end
endmodule