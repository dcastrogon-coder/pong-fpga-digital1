`timescale 1ns/1ps

module tb_temporizadores;

    // Periodos reducidos para simulacion
    localparam integer NB = 4;
    localparam integer NP = 5;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg GAME_EN;
    reg REARM_TIMERS;

    wire TICK_BALL;
    wire TICK_PADDLE;

    integer pruebas;
    integer ticks_ball;
    integer ticks_paddle;
    integer coincidencias;
    integer i;

    // Modelo de referencia independiente
    integer ref_cb;
    integer ref_cp;

    reg tick_b_anterior;
    reg tick_p_anterior;

    // Modulo bajo prueba
    temporizadores #(
        .N_BALL(24'd4),
        .N_PADDLE(24'd5)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GAME_EN(GAME_EN),
        .REARM_TIMERS(REARM_TIMERS),
        .TICK_BALL(TICK_BALL),
        .TICK_PADDLE(TICK_PADDLE)
    );

    // Reloj de 50 MHz: periodo 20 ns
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // Aplicar un ciclo y verificar
    // ------------------------------------

    task paso;
        input rst, juego, rearme;
        input [8*70-1:0] nombre;

        reg esperado_b;
        reg esperado_p;

        begin
            @(negedge CLK_SYS);

            INIT_GLOBAL  = rst;
            GAME_EN     = juego;
            REARM_TIMERS = rearme;

            #1;

            // Prediccion antes del flanco
            esperado_b =
                juego && !rst && !rearme &&
                (ref_cb == NB - 1);

            esperado_p =
                juego && !rst && !rearme &&
                (ref_cp == NP - 1);

            // Comparar salidas combinacionales
            if (TICK_BALL !== esperado_b ||
                TICK_PADDLE !== esperado_p) begin

                $display("ERROR TICKS: %0s", nombre);
                $display(
                    "Esperado BALL=%b PADDLE=%b",
                    esperado_b, esperado_p
                );
                $display(
                    "Obtenido BALL=%b PADDLE=%b",
                    TICK_BALL, TICK_PADDLE
                );
                $stop;
            end

            // No debe haber ticks consecutivos
            if ((tick_b_anterior && esperado_b) ||
                (tick_p_anterior && esperado_p)) begin

                $display(
                    "ERROR: Tick repetido en %0s",
                    nombre
                );
                $stop;
            end

            tick_b_anterior = esperado_b;
            tick_p_anterior = esperado_p;

            if (esperado_b)
                ticks_ball = ticks_ball + 1;

            if (esperado_p)
                ticks_paddle = ticks_paddle + 1;

            if (esperado_b && esperado_p)
                coincidencias = coincidencias + 1;

            // Modelo de siguiente estado
            if (rst || rearme) begin
                ref_cb = 0;
                ref_cp = 0;
            end
            else if (juego) begin
                if (ref_cb == NB - 1)
                    ref_cb = 0;
                else
                    ref_cb = ref_cb + 1;

                if (ref_cp == NP - 1)
                    ref_cp = 0;
                else
                    ref_cp = ref_cp + 1;
            end

            // Comprobar registros tras flanco
            @(posedge CLK_SYS);
            #1;

            if (dut.CB !== ref_cb[23:0] ||
                dut.CP !== ref_cp[23:0]) begin

                $display(
                    "ERROR CONTADORES: %0s",
                    nombre
                );
                $display(
                    "Esperado CB=%0d CP=%0d",
                    ref_cb, ref_cp
                );
                $display(
                    "Obtenido CB=%0d CP=%0d",
                    dut.CB, dut.CP
                );
                $stop;
            end

            pruebas = pruebas + 1;

            $display(
                "OK: %0s | CB=%0d CP=%0d",
                nombre, dut.CB, dut.CP
            );
        end
    endtask

    // ------------------------------------
    // Secuencia de pruebas
    // ------------------------------------

    initial begin

        pruebas = 0;
        ticks_ball = 0;
        ticks_paddle = 0;
        coincidencias = 0;

        ref_cb = 0;
        ref_cp = 0;

        tick_b_anterior = 0;
        tick_p_anterior = 0;

        INIT_GLOBAL = 1;
        GAME_EN = 0;
        REARM_TIMERS = 0;

        // 1. Inicializacion
        @(posedge CLK_SYS);
        #1;

        if (dut.CB !== 0 || dut.CP !== 0) begin
            $display("ERROR INIT");
            $stop;
        end

        pruebas = pruebas + 1;
        $display("OK: Inicializacion");

        // 2. Juego detenido
        paso(0,0,0,"Juego deshabilitado");

        // 3. Funcionamiento continuo
        // 20 ciclos:
        // BALL produce 5 ticks
        // PADDLE produce 4 ticks
        // Coinciden una vez

        for (i=0; i<20; i=i+1) begin
            paso(0,1,0,"Movimiento continuo");
        end

        if (ticks_ball != 5 ||
            ticks_paddle != 4 ||
            coincidencias != 1) begin

            $display("ERROR PERIODICIDAD");
            $display(
                "BALL=%0d PADDLE=%0d SIM=%0d",
                ticks_ball,
                ticks_paddle,
                coincidencias
            );
            $stop;
        end

        $display("OK: Periodicidad 4/5");
        $display("OK: Ticks coincidentes");

        // 4. Avance parcial
        for (i=0; i<3; i=i+1) begin
            paso(0,1,0,"Avance parcial");
        end

        // CB=3: terminal de pelota
        // CP=3: aun no terminal

        // 5. Pausa justo antes del tick
        paso(0,0,0,"Pausa en terminal BALL");

        // 6. Pausa sostenida
        paso(0,0,0,"Pausa sostenida");

        // 7. Rearme completo
        paso(0,1,1,"Rearme de contadores");

        // 8. Reanudacion:
        // no deben aparecer ticks adelantados
        for (i=0; i<3; i=i+1) begin
            paso(0,1,0,"Periodo tras rearme");
        end

        // 9. Primer tick de pelota
        paso(0,1,0,"Primer tick BALL");

        // 10. Primer tick de paletas
        paso(0,1,0,"Primer tick PADDLE");

        // 11. Rearme prioritario
        paso(0,1,1,"Rearme prioritario");

        // 12. Preparar terminal de paletas
        for (i=0; i<4; i=i+1) begin
            paso(0,1,0,"Preparar terminal CP");
        end

        // 13. INIT domina tick pendiente
        paso(1,1,0,"INIT domina terminal");

        // 14. Retencion despues de INIT
        paso(0,0,0,"Retencion final");

        $display("------------------------------");
        $display("CICLOS VERIFICADOS: %0d",
                 pruebas);
        $display("TICKS BALL: %0d",ticks_ball);
        $display("TICKS PADDLE: %0d",
                 ticks_paddle);
        $display("COINCIDENCIAS: %0d",
                 coincidencias);
        $display("FIN TESTBENCH TEMPORIZADORES");
        $display("------------------------------");

        $finish;

    end

endmodule