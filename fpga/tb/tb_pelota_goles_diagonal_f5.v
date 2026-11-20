`timescale 1ns/1ps
// Regresion F5 para movimiento diagonal: pelota + colisiones + FSM + puntaje.
// Se actualizan solamente las posiciones Y esperadas tras los ticks.


module tb_pelota_goles_diagonal_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg START_PULSE = 1'b0;
    reg TICK_BALL = 1'b0;

    // Paletas colocadas para permitir goles
    reg [2:0] YP1_EFF = 3'd1;
    reg [2:0] YP2_EFF = 3'd1;

    wire [3:0] XB;
    wire [2:0] YB;
    wire DX, DY, PHASE;
    wire [3:0] X_CAND;
    wire [2:0] Y_CAND;

    wire HIT_J1, HIT_J2;
    wire GOAL_J1, GOAL_J2;
    wire HIT, GOAL;

    wire [2:0] STATE;
    wire GAME_EN;
    wire CAPTURE_GOAL;
    wire POINT_EN;
    wire CENTER_EN;
    wire SERVE_DIR;
    wire WIN_NEXT;

    wire [3:0] SCORE_J1;
    wire [3:0] SCORE_J2;

    localparam [2:0]
        ESPERA = 3'b000,
        JUEGO  = 3'b001,
        PUNTO  = 3'b010;

    integer pruebas = 0;

    assign HIT = HIT_J1 | HIT_J2;
    assign GOAL = GOAL_J1 | GOAL_J2;

    // 1. Pelota real
    pelota u_pelota (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CENTER_EN(CENTER_EN),
        .GAME_EN(GAME_EN),
        .TICK_BALL(TICK_BALL),
        .SERVE_DIR(SERVE_DIR),
        .HIT(HIT),
        .GOAL(GOAL),
        .XB(XB),
        .YB(YB),
        .DX(DX),
        .DY(DY),
        .PHASE(PHASE),
        .X_CAND(X_CAND),
        .Y_CAND(Y_CAND),
        .DY_CAND()
    );

    // 2. Colisiones reales
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

    // 3. Maquina de estados
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
        .CENTER_EN(CENTER_EN),
        .REARM_TIMERS(),
        .SERVE_DIR(SERVE_DIR)
    );

    // 4. Marcador real
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

    // Verificacion automatica
    task comprobar;
        input condicion;
        input [8*80-1:0] descripcion;
        begin
            if (condicion !== 1'b1) begin
                $display("ERROR: %0s", descripcion);
                $display(
                    "STATE=%b XB=%0d YB=%0d DX=%b",
                    STATE, XB, YB, DX
                );
                $display(
                    "J1=%0d J2=%0d",
                    SCORE_J1, SCORE_J2
                );
                $fatal(1, "Fallo de integracion");
            end

            pruebas = pruebas + 1;
            $display(
                "PASS prueba %0d: %0s",
                pruebas, descripcion
            );
        end
    endtask

    // Generar un pulso START
    task iniciar;
        begin
            @(negedge CLK_SYS);
            START_PULSE = 1'b1;

            @(posedge CLK_SYS);
            #1;

            @(negedge CLK_SYS);
            START_PULSE = 1'b0;
        end
    endtask

    // Generar N ticks reales de movimiento
    task avanzar;
        input integer cantidad;
        integer i;
        begin
            for (i = 0; i < cantidad; i = i + 1) begin
                @(negedge CLK_SYS);
                TICK_BALL = 1'b1;

                @(negedge CLK_SYS);
                TICK_BALL = 1'b0;
            end
        end
    endtask

    initial begin

        // Inicializacion global
        repeat (3) @(posedge CLK_SYS);
        #1;
        INIT_GLOBAL = 1'b0;

        // 1. Posicion inicial
        comprobar(
            STATE === ESPERA &&
            XB === 4'd7 &&
            YB === 3'd3 &&
            DX === 1'b1,
            "Pelota inicializada"
        );

        // 2. Marcadores a cero
        comprobar(
            SCORE_J1 === 4'd0 &&
            SCORE_J2 === 4'd0,
            "Marcadores inicializados"
        );

        // 3. Iniciar juego
        iniciar();
        comprobar(
            STATE === JUEGO &&
            GAME_EN === 1'b1,
            "Inicio de partida"
        );

        // 4. Sin ticks, la pelota no avanza
        repeat (3) @(posedge CLK_SYS);
        #1;
        comprobar(
            XB === 4'd7 &&
            YB === 3'd3,
            "Pelota detenida sin tick"
        );

        // 5. Avanzar hacia J2
        avanzar(7);
        comprobar(
            XB === 4'd14 &&
            YB === 3'd4 &&
            DX === 1'b1,
            "Diagonal 45 grados hacia derecha"
        );

        // 6. J2 falla: gol para J1
        @(negedge CLK_SYS);
        TICK_BALL = 1'b1;
        #1;

        comprobar(
            GOAL_J1 === 1'b1 &&
            GOAL_J2 === 1'b0 &&
            HIT_J2 === 1'b0,
            "Deteccion real de gol J1"
        );

        // 7. FSM captura el gol
        @(posedge CLK_SYS);
        #1;
        comprobar(
            STATE === PUNTO &&
            SCORE_J1 === 4'd0,
            "Captura del primer gol"
        );

        // 8. Registrar punto y centrar
        @(negedge CLK_SYS);
        TICK_BALL = 1'b0;

        @(posedge CLK_SYS);
        #1;

        comprobar(
            STATE === ESPERA &&
            SCORE_J1 === 4'd1 &&
            SCORE_J2 === 4'd0 &&
            XB === 4'd7 &&
            YB === 3'd3 &&
            DX === 1'b0,
            "Punto J1 y saque hacia izquierda"
        );

        // 9. Iniciar segunda ronda
        iniciar();
        comprobar(
            STATE === JUEGO,
            "Segunda ronda iniciada"
        );

        // 10. Avanzar hacia J1
        avanzar(6);
        comprobar(
            XB === 4'd1 &&
            YB === 3'd5 &&
            DX === 1'b0,
            "Diagonal 45 grados hacia izquierda"
        );

        // 11. J1 falla: gol para J2
        @(negedge CLK_SYS);
        TICK_BALL = 1'b1;
        #1;

        comprobar(
            GOAL_J2 === 1'b1 &&
            GOAL_J1 === 1'b0 &&
            HIT_J1 === 1'b0,
            "Deteccion real de gol J2"
        );

        // 12. FSM captura el segundo gol
        @(posedge CLK_SYS);
        #1;

        comprobar(
            STATE === PUNTO &&
            SCORE_J2 === 4'd0,
            "Captura del segundo gol"
        );

        // 13. Registrar segundo punto y centrar
        @(negedge CLK_SYS);
        TICK_BALL = 1'b0;

        @(posedge CLK_SYS);
        #1;

        comprobar(
            STATE === ESPERA &&
            SCORE_J1 === 4'd1 &&
            SCORE_J2 === 4'd1 &&
            XB === 4'd7 &&
            YB === 3'd3 &&
            DX === 1'b1,
            "Punto J2 y saque hacia derecha"
        );

        // 14. Conservar marcadores en espera
        repeat (5) @(posedge CLK_SYS);
        #1;

        comprobar(
            STATE === ESPERA &&
            SCORE_J1 === 4'd1 &&
            SCORE_J2 === 4'd1,
            "Marcadores conservados"
        );

        $display("----------------------------");
        $display(
            "PASS: pelota + colisiones + goles diagonales F5; %0d/14 pruebas correctas",
            pruebas
        );
        $display("----------------------------");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule