`timescale 1ns/1ps

module tb_pelota;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg CENTER_EN;
    reg GAME_EN;
    reg TICK_BALL;
    reg SERVE_DIR;
    reg HIT;
    reg GOAL;

    wire [3:0] XB;
    wire [2:0] YB;
    wire DX, DY, PHASE;
    wire [3:0] X_CAND;
    wire [2:0] Y_CAND;
    wire DY_CAND;

    integer pruebas;
    integer i;
    integer x_exp, y_exp;
    reg dx_exp, dy_exp;

    pelota dut (
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
        .DY_CAND(DY_CAND)
    );

    // Reloj principal: 50 MHz
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // Aplicar entradas y comprobar registros
    // despues del flanco ascendente.
    task paso;
        input ci, cc, ce, ct, cs, ch, cg;
        input [3:0] ex;
        input [2:0] ey;
        input edx, edy, eph;
        input [8*60-1:0] nombre;
        begin
            @(negedge CLK_SYS);

            INIT_GLOBAL = ci;
            CENTER_EN   = cc;
            GAME_EN    = ce;
            TICK_BALL  = ct;
            SERVE_DIR  = cs;
            HIT        = ch;
            GOAL       = cg;

            @(posedge CLK_SYS);
            #1;

            if (XB !== ex || YB !== ey ||
                DX !== edx || DY !== edy ||
                PHASE !== eph) begin

                $display("ERROR: %0s", nombre);
                $display(
                    "Esperado X=%0d Y=%0d DX=%b DY=%b PH=%b",
                    ex, ey, edx, edy, eph
                );
                $display(
                    "Obtenido X=%0d Y=%0d DX=%b DY=%b PH=%b",
                    XB, YB, DX, DY, PHASE
                );
                $stop;
            end
            else begin
                pruebas = pruebas + 1;
                $display("OK: %0s", nombre);
            end
        end
    endtask

    // Comprobar salidas combinacionales
    task comprobar_candidato;
        input [3:0] ex;
        input [2:0] ey;
        input edy;
        input [8*60-1:0] nombre;
        begin
            #1;
            if (X_CAND !== ex ||
                Y_CAND !== ey ||
                DY_CAND !== edy) begin

                $display("ERROR CAND: %0s", nombre);
                $display(
                    "Esperado: XC=%0d YC=%0d DYC=%b",
                    ex, ey, edy
                );
                $display(
                    "Obtenido: XC=%0d YC=%0d DYC=%b",
                    X_CAND, Y_CAND, DY_CAND
                );
                $stop;
            end
            else begin
                pruebas = pruebas + 1;
                $display("OK: %0s", nombre);
            end
        end
    endtask

    initial begin
        pruebas = 0;

        INIT_GLOBAL = 0;
        CENTER_EN = 0;
        GAME_EN = 0;
        TICK_BALL = 0;
        SERVE_DIR = 1;
        HIT = 0;
        GOAL = 0;

        // 1. Inicializacion
        paso(1,0,0,0,1,0,0,
             7,3,1,1,0,"Inicializacion");

        // 2. Juego deshabilitado
        paso(0,0,0,1,1,0,0,
             7,3,1,1,0,"GAME_EN desactivado");

        // 3. Ausencia de tick
        paso(0,0,1,0,1,0,0,
             7,3,1,1,0,"Sin TICK_BALL");

        // 4. Primer avance horizontal
        paso(0,0,1,1,1,0,0,
             8,3,1,1,1,"Primer avance X");

        // 5. Pausa con PHASE=1
        paso(0,0,0,1,1,0,0,
             8,3,1,1,1,"Congelamiento PHASE");

        // 6. Habilitacion sin tick
        paso(0,0,1,0,1,0,0,
             8,3,1,1,1,"Sin avance al habilitar");

        // 7. Segundo avance X e Y
        paso(0,0,1,1,1,0,0,
             9,4,1,1,0,"Movimiento X e Y");

        // 8. GOAL prevalece sobre HIT
        paso(0,0,1,1,1,1,1,
             9,4,1,1,0,"GOAL bloquea registros");

        // 9. Centrado con saque izquierdo
        paso(0,1,1,1,0,1,1,
             7,3,0,1,0,"CENTER y SERVE_DIR");

        // 10. Avance hacia izquierda
        paso(0,0,1,1,0,0,0,
             6,3,0,1,1,"Avance izquierdo");

        // 11. Desplazamiento vertical
        paso(0,0,1,1,0,0,0,
             5,4,0,1,0,"Vertical cada dos ticks");

        // 12. INIT tiene maxima prioridad
        paso(1,1,1,1,0,1,1,
             7,3,1,1,0,"Prioridad INIT_GLOBAL");

        // 13. Trayectoria completa:
        //     rebote horizontal en ambos lados
        //     y vertical en ambas paredes.
        //
        // HIT se inyecta al alcanzar X=0/15.
        // La deteccion real corresponde
        // al futuro modulo colisiones.

        for (i = 1; i <= 24; i = i + 1) begin

            if (i <= 7)
                x_exp = 7 + i;
            else if (i == 8)
                x_exp = 14;
            else if (i <= 21)
                x_exp = 22 - i;
            else if (i == 22)
                x_exp = 1;
            else
                x_exp = i - 21;

            if (i <= 8)
                y_exp = 3 + i/2;
            else if (i <= 22)
                y_exp = 7 - (i-8)/2;
            else
                y_exp = (i-22)/2;

            dx_exp = (i < 8 || i >= 22);
            dy_exp = (i < 10 || i >= 24);

            paso(0,0,1,1,1,
                 (i == 8 || i == 22),0,
                 x_exp[3:0],y_exp[2:0],
                 dx_exp,dy_exp,(i % 2 == 1),
                 "Trayectoria con rebotes");

            // Prediccion en pared inferior
            if (i == 9)
                comprobar_candidato(
                    12,6,0,"Rebote inferior candidato"
                );

            // Prediccion en pared superior
            if (i == 23)
                comprobar_candidato(
                    3,1,1,"Rebote superior candidato"
                );
        end

        // 14. Conservacion tras la trayectoria
        paso(0,0,1,0,1,0,0,
             3,1,1,1,0,"Retencion sin tick");

        $display("------------------------------");
        $display("PRUEBAS SUPERADAS: %0d",pruebas);
        $display("FIN TESTBENCH PELOTA");
        $display("------------------------------");

        $finish;
    end

endmodule