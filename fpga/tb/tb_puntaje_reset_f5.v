`timescale 1ns/1ps

module tb_puntaje_reset_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg RESET_RAW_ACTIVE = 1'b0;

    reg GOAL_J1 = 1'b0;
    reg GOAL_J2 = 1'b0;
    reg CAPTURE_GOAL = 1'b0;
    reg POINT_EN = 1'b0;

    wire POR_REQ;
    wire RESET_CLEAN;
    wire INIT_GLOBAL;

    wire [3:0] SCORE_J1;
    wire [3:0] SCORE_J2;
    wire SCORER;
    wire WIN_NEXT;

    integer pruebas = 0;

    // RESET real del diseño, con tiempo reducido
    reset_seguro #(
        .NDB(20'd4)
    ) u_reset (
        .CLK_SYS(CLK_SYS),
        .RESET_RAW_ACTIVE(RESET_RAW_ACTIVE),
        .POR_REQ(POR_REQ),
        .RESET_CLEAN(RESET_CLEAN)
    );

    assign INIT_GLOBAL = POR_REQ | RESET_CLEAN;

    // Modulo de puntaje original
    puntaje dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),

        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(POINT_EN),

        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),
        .SCORER(SCORER),
        .WIN_NEXT(WIN_NEXT)
    );

    // Verificar marcadores
    task verificar;
        input [3:0] esperado_j1;
        input [3:0] esperado_j2;
        begin
            if (SCORE_J1 !== esperado_j1 ||
                SCORE_J2 !== esperado_j2) begin

                $display("ERROR prueba %0d",
                         pruebas + 1);

                $display("J1=%0d esperado=%0d",
                         SCORE_J1, esperado_j1);

                $display("J2=%0d esperado=%0d",
                         SCORE_J2, esperado_j2);

                $fatal(1, "Fallo de puntaje F5");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    // Gol valido del jugador 1
    task anotar_j1;
        begin
            @(negedge CLK_SYS);
            GOAL_J1 = 1'b1;
            CAPTURE_GOAL = 1'b1;

            @(negedge CLK_SYS);
            GOAL_J1 = 1'b0;
            CAPTURE_GOAL = 1'b0;
            POINT_EN = 1'b1;

            @(negedge CLK_SYS);
            POINT_EN = 1'b0;
            #1;
        end
    endtask

    // Gol valido del jugador 2
    task anotar_j2;
        begin
            @(negedge CLK_SYS);
            GOAL_J2 = 1'b1;
            CAPTURE_GOAL = 1'b1;

            @(negedge CLK_SYS);
            GOAL_J2 = 1'b0;
            CAPTURE_GOAL = 1'b0;
            POINT_EN = 1'b1;

            @(negedge CLK_SYS);
            POINT_EN = 1'b0;
            #1;
        end
    endtask

    initial begin

        // 1. Arranque del sistema
        repeat (15) @(posedge CLK_SYS);
        #1;
        verificar(4'd0, 4'd0);

        // 2. Primer punto del jugador 1
        anotar_j1();
        verificar(4'd1, 4'd0);

        // 3. Segundo punto del jugador 1
        anotar_j1();
        verificar(4'd2, 4'd0);

        // 4. Primer punto del jugador 2
        anotar_j2();
        verificar(4'd2, 4'd1);

        // 5. Sin nuevos eventos, conservar puntajes
        repeat (5) @(posedge CLK_SYS);
        #1;
        verificar(4'd2, 4'd1);

        // 6. Dos goles simultaneos no son validos
        @(negedge CLK_SYS);
        GOAL_J1 = 1'b1;
        GOAL_J2 = 1'b1;
        CAPTURE_GOAL = 1'b1;

        @(negedge CLK_SYS);
        GOAL_J1 = 1'b0;
        GOAL_J2 = 1'b0;
        CAPTURE_GOAL = 1'b0;

        if (SCORER !== 1'b1)
            $fatal(1, "Anotador alterado por gol invalido");

        verificar(4'd2, 4'd1);

        // 7. RESET con puntajes diferentes de cero
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b1;

        #1;
        if (RESET_CLEAN !== 1'b1)
            $fatal(1, "RESET no se activo");

        repeat (2) @(posedge CLK_SYS);
        #1;
        verificar(4'd0, 4'd0);

        // 8. Mantener RESET presionado
        repeat (3) @(posedge CLK_SYS);
        #1;
        verificar(4'd0, 4'd0);

        // 9. Liberar RESET y conservar cero
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b0;

        repeat (15) @(posedge CLK_SYS);
        #1;

        if (INIT_GLOBAL !== 1'b0)
            $fatal(1, "RESET no se libero");

        verificar(4'd0, 4'd0);

        // 10. El marcador funciona despues de RESET
        anotar_j2();
        verificar(4'd0, 4'd1);

        $display("----------------------------");
        $display("PUNTAJE Y RESET F5: %0d/10 PASS",
                 pruebas);
        $display("----------------------------");

        $finish;
    end

    // Proteccion contra simulacion bloqueada
    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule