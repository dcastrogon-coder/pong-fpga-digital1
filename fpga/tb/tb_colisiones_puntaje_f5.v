`timescale 1ns/1ps

module tb_colisiones_puntaje_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg START_PULSE = 1'b0;
    reg TICK_BALL = 1'b0;

    reg [3:0] XB = 4'd7;
    reg [3:0] X_CAND = 4'd8;
    reg [2:0] Y_CAND = 3'd3;
    reg DX = 1'b1;

    reg [2:0] YP1_EFF = 3'd1;
    reg [2:0] YP2_EFF = 3'd2;

    wire HIT_J1, HIT_J2;
    wire GOAL_J1, GOAL_J2;

    wire [2:0] STATE;
    wire GAME_EN;
    wire CAPTURE_GOAL;
    wire POINT_EN;
    wire WIN_NEXT;

    wire [3:0] SCORE_J1;
    wire [3:0] SCORE_J2;

    localparam [2:0]
        ESPERA = 3'b000,
        JUEGO  = 3'b001,
        PUNTO  = 3'b010;

    integer pruebas = 0;

    // Deteccion real de colisiones
    colisiones u_colisiones (
        .GAME_EN(GAME_EN),
        .TICK_BALL(TICK_BALL),
        .XB(XB),
        .X_CAND(X_CAND),
        .Y_CAND(Y_CAND),
        .DX(DX),
        .YP1_EFF(YP1_EFF),
        .YP2_EFF(YP2_EFF),
        .HIT_J1(HIT_J1),
        .HIT_J2(HIT_J2),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2)
    );

    // Maquina de estados real
    control_juego u_fsm (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .START_PULSE(START_PULSE),
        .PAUSE_PULSE(1'b0),
        .RF_OK_EFF(1'b1),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .WIN_NEXT(WIN_NEXT),
        .STATE(STATE),
        .GAME_EN(GAME_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(POINT_EN),
        .CENTER_EN(),
        .REARM_TIMERS(),
        .SERVE_DIR()
    );

    // Marcador real
    puntaje u_puntaje (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(POINT_EN),
        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),
        .SCORER(),
        .WIN_NEXT(WIN_NEXT)
    );

    task verificar_estado_puntaje;
        input [2:0] esperado_estado;
        input [3:0] esperado_j1;
        input [3:0] esperado_j2;
        begin
            #1;
            if (STATE !== esperado_estado ||
                SCORE_J1 !== esperado_j1 ||
                SCORE_J2 !== esperado_j2) begin

                $display("ERROR prueba %0d", pruebas + 1);
                $display("Estado=%b J1=%0d J2=%0d",
                         STATE, SCORE_J1, SCORE_J2);
                $fatal(1, "Estado o puntaje incorrecto");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    task verificar_eventos;
        input esperado_h1;
        input esperado_h2;
        input esperado_g1;
        input esperado_g2;
        begin
            #1;
            if (HIT_J1 !== esperado_h1 ||
                HIT_J2 !== esperado_h2 ||
                GOAL_J1 !== esperado_g1 ||
                GOAL_J2 !== esperado_g2) begin

                $display("ERROR prueba %0d", pruebas + 1);
                $display("HIT=%b%b GOAL=%b%b",
                         HIT_J1, HIT_J2,
                         GOAL_J1, GOAL_J2);
                $fatal(1, "Evento de colision incorrecto");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    task iniciar;
        begin
            @(negedge CLK_SYS);
            START_PULSE = 1'b1;

            @(posedge CLK_SYS);
            #1;
            START_PULSE = 1'b0;
        end
    endtask

    initial begin

        // 1. Inicializacion
        repeat (3) @(posedge CLK_SYS);
        #1;
        INIT_GLOBAL = 1'b0;
        verificar_estado_puntaje(ESPERA, 4'd0, 4'd0);

        // 2. Iniciar juego
        iniciar();
        verificar_estado_puntaje(JUEGO, 4'd0, 4'd0);

        // Preparar llegada al borde derecho
        @(negedge CLK_SYS);
        XB = 4'd14;
        X_CAND = 4'd15;
        Y_CAND = 3'd2;
        DX = 1'b1;

        // 3. Sin tick no hay eventos
        TICK_BALL = 1'b0;
        verificar_eventos(0, 0, 0, 0);

        // 4. Impacto contra paleta J2
        TICK_BALL = 1'b1;
        verificar_eventos(0, 1, 0, 0);

        // 5. J2 falla: gol para J1
        @(negedge CLK_SYS);
        Y_CAND = 3'd5;
        TICK_BALL = 1'b1;
        verificar_eventos(0, 0, 1, 0);

        // 6. FSM captura el gol
        @(posedge CLK_SYS);
        #1;
        verificar_estado_puntaje(PUNTO, 4'd0, 4'd0);

        // 7. Se incrementa J1
        @(negedge CLK_SYS);
        TICK_BALL = 1'b0;

        @(posedge CLK_SYS);
        #1;
        verificar_estado_puntaje(ESPERA, 4'd1, 4'd0);

        // 8. Nueva ronda
        iniciar();
        verificar_estado_puntaje(JUEGO, 4'd1, 4'd0);

        // 9. J1 falla: gol para J2
        @(negedge CLK_SYS);
        XB = 4'd1;
        X_CAND = 4'd0;
        Y_CAND = 3'd5;
        DX = 1'b0;
        TICK_BALL = 1'b1;

        verificar_eventos(0, 0, 0, 1);

        // 10. FSM captura el segundo gol
        @(posedge CLK_SYS);
        #1;
        verificar_estado_puntaje(PUNTO, 4'd1, 4'd0);

        // 11. Se incrementa J2
        @(negedge CLK_SYS);
        TICK_BALL = 1'b0;

        @(posedge CLK_SYS);
        #1;
        verificar_estado_puntaje(ESPERA, 4'd1, 4'd1);

        // 12. Sin eventos, conservar marcadores
        repeat (5) @(posedge CLK_SYS);
        #1;
        verificar_estado_puntaje(ESPERA, 4'd1, 4'd1);

        $display("----------------------------");
        $display("COLISIONES Y PUNTAJE F5: %0d/12 PASS",
                 pruebas);
        $display("----------------------------");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule