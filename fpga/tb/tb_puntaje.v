`timescale 1ns/1ps

module tb_puntaje;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg GOAL_J1;
    reg GOAL_J2;
    reg CAPTURE_GOAL;
    reg POINT_EN;

    wire [3:0] SCORE_J1;
    wire [3:0] SCORE_J2;
    wire SCORER;
    wire WIN_NEXT;

    integer pruebas;
    integer i;

    // Modelo de referencia del marcador
    integer ref_j1;
    integer ref_j2;
    reg ref_scorer;

    // Modulo bajo prueba
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

    // Reloj de 50 MHz
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // Aplicar un ciclo y verificar
    // ------------------------------------

    task ciclo;
        input rst, g1, g2, cap, pen;
        input [8*64-1:0] nombre;

        integer next_j1;
        integer next_j2;
        reg next_scorer;
        reg win_esperado;

        begin
            @(negedge CLK_SYS);

            INIT_GLOBAL = rst;
            GOAL_J1 = g1;
            GOAL_J2 = g2;
            CAPTURE_GOAL = cap;
            POINT_EN = pen;

            #1;

            // WIN_NEXT se evalua antes
            // de actualizar los registros.
            win_esperado = pen &&
                ((!ref_scorer && ref_j1 >= 8) ||
                 ( ref_scorer && ref_j2 >= 8));

            if (WIN_NEXT !== win_esperado) begin
                $display("ERROR WIN_NEXT: %0s", nombre);
                $display("Esperado=%b Obtenido=%b",
                         win_esperado, WIN_NEXT);
                $stop;
            end

            // Calcular siguiente estado esperado
            next_j1 = ref_j1;
            next_j2 = ref_j2;
            next_scorer = ref_scorer;

            if (rst) begin
                next_j1 = 0;
                next_j2 = 0;
                next_scorer = 0;
            end
            else begin

                // El incremento usa SCORER anterior
                if (pen && !ref_scorer && ref_j1 < 9)
                    next_j1 = ref_j1 + 1;

                if (pen && ref_scorer && ref_j2 < 9)
                    next_j2 = ref_j2 + 1;

                // Captura del anotador
                if (cap && (g1 ^ g2))
                    next_scorer = g2;
            end

            @(posedge CLK_SYS);
            #1;

            if (SCORE_J1 !== next_j1[3:0] ||
                SCORE_J2 !== next_j2[3:0] ||
                SCORER !== next_scorer) begin

                $display("ERROR: %0s", nombre);
                $display(
                    "Esperado J1=%0d J2=%0d SC=%b",
                    next_j1, next_j2, next_scorer
                );
                $display(
                    "Obtenido J1=%0d J2=%0d SC=%b",
                    SCORE_J1, SCORE_J2, SCORER
                );
                $stop;
            end

            // Actualizar referencia
            ref_j1 = next_j1;
            ref_j2 = next_j2;
            ref_scorer = next_scorer;

            pruebas = pruebas + 1;

            $display(
                "OK: %0s | J1=%0d J2=%0d SC=%b",
                nombre, SCORE_J1, SCORE_J2, SCORER
            );
        end
    endtask

    // ------------------------------------
    // Secuencia principal de pruebas
    // ------------------------------------

    initial begin

        pruebas = 0;
        ref_j1 = 0;
        ref_j2 = 0;
        ref_scorer = 0;

        INIT_GLOBAL = 0;
        GOAL_J1 = 0;
        GOAL_J2 = 0;
        CAPTURE_GOAL = 0;
        POINT_EN = 0;

        // 1. Inicializacion
        ciclo(1,0,0,0,0,"Inicializacion global");

        // 2. Capturar anotador J1
        ciclo(0,1,0,1,0,"Captura J1");

        // 3. Incrementar J1
        ciclo(0,0,0,0,1,"Primer punto J1");

        // 4. Sin POINT_EN, no repetir
        ciclo(0,0,0,0,0,"Sin duplicacion");

        // 5. Gol sin captura: ignorar
        ciclo(0,0,1,0,0,"Gol sin CAPTURE_GOAL");

        // 6. Capturar anotador J2
        ciclo(0,0,1,1,0,"Captura J2");

        // 7. Incrementar J2
        ciclo(0,0,0,0,1,"Primer punto J2");

        // 8. Dos goles simultaneos:
        //    SCORER no debe cambiar
        ciclo(0,1,1,1,0,"Doble gol invalido");

        // 9. INIT tiene prioridad sobre
        //    captura e incremento
        ciclo(1,1,0,1,1,"Prioridad INIT");

        // 10. Conservar despues de INIT
        ciclo(0,0,0,0,0,"Retencion tras INIT");

        // --------------------------------
        // Puntaje del jugador 1
        // --------------------------------

        ciclo(0,1,0,1,0,"Seleccionar J1");

        // Llevar J1 de 0 a 8
        for (i=1; i<=8; i=i+1) begin
            ciclo(0,0,0,0,1,"Acumular puntos J1");
        end

        // En 8, sin POINT_EN:
        // WIN_NEXT debe ser cero
        ciclo(0,0,0,0,0,"J1 en 8 sin victoria");

        // De 8 a 9: WIN_NEXT activo
        ciclo(0,0,0,0,1,"Victoria J1");

        // Saturacion en 9
        ciclo(0,0,0,0,1,"Saturacion J1");

        // --------------------------------
        // Puntaje del jugador 2
        // --------------------------------

        ciclo(0,0,1,1,0,"Seleccionar J2");

        // Llevar J2 de 0 a 8
        for (i=1; i<=8; i=i+1) begin
            ciclo(0,0,0,0,1,"Acumular puntos J2");
        end

        // De 8 a 9: WIN_NEXT activo
        ciclo(0,0,0,0,1,"Victoria J2");

        // Saturacion en 9
        ciclo(0,0,0,0,1,"Saturacion J2");

        // Cambiar SCORER sin modificar
        // los puntajes almacenados
        ciclo(0,1,0,1,0,"Captura sin incremento");

        ciclo(0,0,0,0,0,"Retencion de marcadores");

        // --------------------------------
        // RESET final
        // --------------------------------

        ciclo(1,0,0,0,0,"RESET final");

        ciclo(0,0,0,0,0,"Retencion en cero");

        $display("------------------------------");
        $display("PRUEBAS SUPERADAS: %0d", pruebas);
        $display("FIN TESTBENCH PUNTAJE");
        $display("------------------------------");

        $finish;

    end

endmodule