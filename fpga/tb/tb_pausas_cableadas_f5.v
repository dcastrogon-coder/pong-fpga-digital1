`timescale 1ns/1ps

module tb_pausas_cableadas_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg START_PULSE = 1'b0;
    reg PAUSE_PULSE = 1'b0;

    reg J1_DETECT_N = 1'b1;
    reg J2_DETECT_N = 1'b1;

    wire RF_OK_EFF;
    wire [2:0] STATE;

    localparam [2:0]
        ESPERA       = 3'b000,
        JUEGO        = 3'b001,
        PAUSA_RF     = 3'b011,
        PAUSA_MANUAL = 3'b101;

    // Supervisor con filtro reducido para simulacion
    supervisor_cableado #(
        .NDB(20'd4)
    ) u_supervisor (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),

        .J1_UP_N(1'b1),
        .J1_DOWN_N(1'b1),
        .J1_DETECT_N(J1_DETECT_N),

        .J2_UP_N(1'b1),
        .J2_DOWN_N(1'b1),
        .J2_DETECT_N(J2_DETECT_N),

        .CMD_J1(),
        .CMD_J2(),
        .RF1_OK_EFF(),
        .RF2_OK_EFF(),
        .RF_OK_EFF(RF_OK_EFF)
    );

    // FSM original de F3
    control_juego u_fsm (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .START_PULSE(START_PULSE),
        .PAUSE_PULSE(PAUSE_PULSE),
        .RF_OK_EFF(RF_OK_EFF),

        .GOAL_J1(1'b0),
        .GOAL_J2(1'b0),
        .WIN_NEXT(1'b0),

        .STATE(STATE),
        .GAME_EN(),
        .CAPTURE_GOAL(),
        .POINT_EN(),
        .CENTER_EN(),
        .REARM_TIMERS(),
        .SERVE_DIR()
    );

    integer pruebas = 0;

    task esperar_filtro;
        begin
            repeat (12) @(posedge CLK_SYS);
            #1;
        end
    endtask

    task pulsar_start;
        begin
            @(negedge CLK_SYS);
            START_PULSE = 1'b1;
            @(posedge CLK_SYS);
            #1;
            @(negedge CLK_SYS);
            START_PULSE = 1'b0;
        end
    endtask

    task pulsar_pausa;
        begin
            @(negedge CLK_SYS);
            PAUSE_PULSE = 1'b1;
            @(posedge CLK_SYS);
            #1;
            @(negedge CLK_SYS);
            PAUSE_PULSE = 1'b0;
        end
    endtask

    task verificar;
        input [2:0] estado_esperado;
        input rf_esperado;
        begin
            if (STATE !== estado_esperado ||
                RF_OK_EFF !== rf_esperado) begin
                $display("ERROR prueba %0d", pruebas + 1);
                $display("STATE=%b esperado=%b",
                         STATE, estado_esperado);
                $display("RF_OK=%b esperado=%b",
                         RF_OK_EFF, rf_esperado);
                $fatal(1, "Fallo de integracion F5");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    initial begin
        repeat (3) @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b0;

        // 1. Espera sin controles
        esperar_filtro();
        verificar(ESPERA, 1'b0);

        // 2. START no inicia sin controles
        pulsar_start();
        verificar(ESPERA, 1'b0);

        // 3. Conectar ambos controles
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;
        esperar_filtro();
        verificar(ESPERA, 1'b1);

        // 4. START inicia el juego
        pulsar_start();
        verificar(JUEGO, 1'b1);

        // 5. Desconectar jugador 1
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b1;
        esperar_filtro();
        verificar(PAUSA_RF, 1'b0);

        // 6. Reconectar no reanuda automaticamente
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        esperar_filtro();
        verificar(PAUSA_RF, 1'b1);

        // 7. START reanuda tras reconexion
        pulsar_start();
        verificar(JUEGO, 1'b1);

        // 8. PAUSE activa pausa manual
        pulsar_pausa();
        verificar(PAUSA_MANUAL, 1'b1);

        // 9. START no cancela pausa manual
        pulsar_start();
        verificar(PAUSA_MANUAL, 1'b1);

        // 10. PAUSE reanuda el juego
        pulsar_pausa();
        verificar(JUEGO, 1'b1);

        // 11. Desconectar jugador 2
        @(negedge CLK_SYS);
        J2_DETECT_N = 1'b1;
        esperar_filtro();
        verificar(PAUSA_RF, 1'b0);

        // 12. Reconectar jugador 2
        @(negedge CLK_SYS);
        J2_DETECT_N = 1'b0;
        esperar_filtro();
        verificar(PAUSA_RF, 1'b1);

        // 13. START permite reanudar
        pulsar_start();
        verificar(JUEGO, 1'b1);
		  
		  // 14. Activar pausa manual
        pulsar_pausa();
        verificar(PAUSA_MANUAL, 1'b1);

        // 15. Desconectar J1 durante pausa manual
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b1;
        esperar_filtro();
        verificar(PAUSA_MANUAL, 1'b0);

        // 16. PAUSE no reanuda sin J1
        pulsar_pausa();
        verificar(PAUSA_MANUAL, 1'b0);

        // 17. Reconectar J1
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        esperar_filtro();
        verificar(PAUSA_MANUAL, 1'b1);

        // 18. PAUSE reanuda tras reconexion
        pulsar_pausa();
        verificar(JUEGO, 1'b1);

        $display("----------------------------");
        $display("PAUSAS F5: %0d/18 PASS", pruebas);
        $display("----------------------------");

        $finish;
    end

endmodule