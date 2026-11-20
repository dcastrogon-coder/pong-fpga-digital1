`timescale 1ns/1ps

module tb_temporizadores_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg GAME_EN = 1'b0;
    reg REARM_TIMERS = 1'b0;

    wire TICK_BALL;
    wire TICK_PADDLE;

    integer eventos_bola = 0;
    integer eventos_paleta = 0;
    integer pruebas = 0;

    // Periodos reducidos solo para simulacion
    temporizadores #(
        .N_BALL(24'd4),
        .N_PADDLE(24'd6)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GAME_EN(GAME_EN),
        .REARM_TIMERS(REARM_TIMERS),
        .TICK_BALL(TICK_BALL),
        .TICK_PADDLE(TICK_PADDLE)
    );

    // Contar los ticks efectivos
    always @(posedge CLK_SYS) begin
        if (TICK_BALL)
            eventos_bola = eventos_bola + 1;

        if (TICK_PADDLE)
            eventos_paleta = eventos_paleta + 1;
    end

    // Avanzar una cantidad de ciclos
    task esperar;
        input integer ciclos;
        begin
            repeat (ciclos) @(posedge CLK_SYS);
            #1;
        end
    endtask

    // Comprobar eventos y contadores internos
    task verificar;
        input integer esperado_bola;
        input integer esperado_paleta;
        input [23:0] esperado_cb;
        input [23:0] esperado_cp;
        begin
            #1;

            if (eventos_bola !== esperado_bola ||
                eventos_paleta !== esperado_paleta ||
                dut.CB !== esperado_cb ||
                dut.CP !== esperado_cp) begin

                $display("ERROR prueba %0d",
                         pruebas + 1);

                $display(
                    "BOLA: eventos=%0d CB=%0d",
                    eventos_bola, dut.CB
                );

                $display(
                    "PALETA: eventos=%0d CP=%0d",
                    eventos_paleta, dut.CP
                );

                $fatal(1, "Fallo de temporizadores F5");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    initial begin

        // 1. Inicializacion global
        esperar(2);
        verificar(0, 0, 24'd0, 24'd0);

        // 2. Sin GAME_EN no deben contar
        @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b0;

        esperar(10);
        verificar(0, 0, 24'd0, 24'd0);

        // Activar el juego
        @(negedge CLK_SYS);
        GAME_EN = 1'b1;

        // 3. Antes del primer tick de pelota
        esperar(3);
        verificar(0, 0, 24'd3, 24'd3);

        // 4. Primer tick de pelota
        esperar(1);
        verificar(1, 0, 24'd0, 24'd4);

        // 5. Primer tick de paleta
        esperar(2);
        verificar(1, 1, 24'd2, 24'd0);

        // 6. Segundo tick de pelota
        esperar(2);
        verificar(2, 1, 24'd0, 24'd2);

        // Desactivar el juego
        @(negedge CLK_SYS);
        GAME_EN = 1'b0;

        // 7. Contadores congelados en pausa
        esperar(10);
        verificar(2, 1, 24'd0, 24'd2);

        // Reactivar sin rearme para comprobar
        // que los contadores conservan su valor
        @(negedge CLK_SYS);
        GAME_EN = 1'b1;

        // 8. Continuacion de conteos
        esperar(2);
        verificar(2, 1, 24'd2, 24'd4);

        // 9. Nuevos ticks tras continuar
        esperar(2);
        verificar(3, 2, 24'd0, 24'd0);

        // Activar rearme de temporizadores
        @(negedge CLK_SYS);
        REARM_TIMERS = 1'b1;

        // 10. Rearme bloquea ticks y reinicia
        esperar(8);
        verificar(3, 2, 24'd0, 24'd0);

        // Liberar rearme
        @(negedge CLK_SYS);
        REARM_TIMERS = 1'b0;

        // 11. Nuevo periodo de pelota
        esperar(4);
        verificar(4, 2, 24'd0, 24'd4);

        // 12. Nuevo periodo de paleta
        esperar(2);
        verificar(4, 3, 24'd2, 24'd0);

        // Activar inicializacion global
        @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b1;

        // 13. Inicializacion reinicia contadores
        esperar(2);
        verificar(4, 3, 24'd0, 24'd0);

        $display("----------------------------");
        $display(
            "TEMPORIZADORES F5: %0d/13 PASS",
            pruebas
        );
        $display("----------------------------");

        $finish;
    end

    // Proteccion contra simulacion bloqueada
    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule

