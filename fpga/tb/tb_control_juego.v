`timescale 1ns/1ps

module tb_control_juego;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg START_PULSE;
    reg PAUSE_PULSE;
    reg RF_OK_EFF;
    reg GOAL_J1;
    reg GOAL_J2;
    reg WIN_NEXT;

    wire [2:0] STATE;
    wire GAME_EN;
    wire CAPTURE_GOAL;
    wire POINT_EN;
    wire CENTER_EN;
    wire REARM_TIMERS;
    wire SERVE_DIR;

    integer pruebas_dir;
    integer pruebas_fsm;
    integer q, s, p, l, g, w, r;

    reg [2:0] esperado;
    reg saque_anterior;
    reg saque_esperado;
    reg captura_esperada;

    // Modulo bajo prueba
    control_juego dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .START_PULSE(START_PULSE),
        .PAUSE_PULSE(PAUSE_PULSE),
        .RF_OK_EFF(RF_OK_EFF),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .WIN_NEXT(WIN_NEXT),
        .STATE(STATE),
        .GAME_EN(GAME_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(POINT_EN),
        .CENTER_EN(CENTER_EN),
        .REARM_TIMERS(REARM_TIMERS),
        .SERVE_DIR(SERVE_DIR)
    );

    // Reloj nominal de 50 MHz
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // Modelo de referencia F2
    // ------------------------------------

    function [2:0] modelo_estado;
        input [2:0] q_actual;
        input st, pa, rf, gol, win, rst;

        begin
            if (rst || q_actual >= 6)
                modelo_estado = 0;

            else begin
                case (q_actual)

                    0: modelo_estado =
                        (rf && st) ? 1 : 0;

                    1: modelo_estado =
                        !rf ? 3 :
                        pa  ? 5 :
                        gol ? 2 : 1;

                    2: modelo_estado =
                        win ? 4 : 0;

                    3: modelo_estado =
                        (rf && st) ? 1 : 3;

                    4: modelo_estado = 4;

                    5: modelo_estado =
                        (rf && pa) ? 1 : 5;

                    default:
                        modelo_estado = 0;

                endcase
            end
        end
    endfunction

    // ------------------------------------
    // Verificar salidas combinacionales
    // ------------------------------------

    task comprobar_salidas;
        input [2:0] q_actual;
        input st, pa, rf, g1, g2, win, rst;

        reg egame, ecap, epoint;
        reg ecenter, erearm;
        reg [2:0] enext;

        begin
            egame = (q_actual == 1) &&
                    rf && !pa && !rst;

            ecap = egame && (g1 ^ g2);

            epoint = (q_actual == 2) &&
                     !rst;

            ecenter = epoint && !win;

            erearm = !rst && rf &&
                     (
                       (st && ((q_actual == 0) ||
                               (q_actual == 3))) ||
                       (pa && (q_actual == 5))
                     );

            enext = modelo_estado(
                q_actual, st, pa, rf,
                g1 ^ g2, win, rst
            );

            if ({
                GAME_EN,
                CAPTURE_GOAL,
                POINT_EN,
                CENTER_EN,
                REARM_TIMERS
            } !== {
                egame,
                ecap,
                epoint,
                ecenter,
                erearm
            }) begin
                $display("ERROR EN SALIDAS FSM");
                $display("Estado=%b",q_actual);
                $display("Entradas S=%b P=%b RF=%b",
                         st,pa,rf);
                $display("G1=%b G2=%b W=%b INIT=%b",
                         g1,g2,win,rst);
                $stop;
            end

            // NEXT_STATE no incluye el MUX
            // secuencial de INIT_GLOBAL.
            if (!rst && dut.NEXT_STATE !== enext) begin
                $display("ERROR NEXT_STATE");
                $display("Estado=%b",q_actual);
                $display("Esperado=%b Obtenido=%b",
                         enext,dut.NEXT_STATE);
                $stop;
            end
        end
    endtask

    // ------------------------------------
    // Prueba dirigida:
    // comprobar transicion real
    // ------------------------------------

    task paso;
        input st, pa, rf, g1, g2, win, rst;
        input [2:0] estado_actual;
        input [2:0] estado_final;
        input [8*70-1:0] nombre;

        reg [2:0] siguiente_ref;
        reg saque_ref;

        begin
            @(negedge CLK_SYS);

            START_PULSE = st;
            PAUSE_PULSE = pa;
            RF_OK_EFF = rf;
            GOAL_J1 = g1;
            GOAL_J2 = g2;
            WIN_NEXT = win;
            INIT_GLOBAL = rst;

            #1;

            if (STATE !== estado_actual) begin
                $display("ERROR ESTADO INICIAL: %0s",
                         nombre);
                $stop;
            end

            comprobar_salidas(
                estado_actual,
                st,pa,rf,g1,g2,win,rst
            );

            siguiente_ref = modelo_estado(
                estado_actual,st,pa,rf,
                g1 ^ g2,win,rst
            );

            if (siguiente_ref !== estado_final) begin
                $display("ERROR REFERENCIA: %0s",
                         nombre);
                $stop;
            end

            saque_ref = rst ? 1'b1 :
                        CAPTURE_GOAL ?
                        ~SERVE_DIR : SERVE_DIR;

            @(posedge CLK_SYS);
            #1;

            if (STATE !== estado_final ||
                SERVE_DIR !== saque_ref) begin
                $display("ERROR: %0s",nombre);
                $display("Esperado STATE=%b SERVE=%b",
                         estado_final,saque_ref);
                $display("Obtenido STATE=%b SERVE=%b",
                         STATE,SERVE_DIR);
                $stop;
            end

            pruebas_dir = pruebas_dir + 1;

            $display(
                "OK: %0s | STATE=%b SERVE=%b",
                nombre,STATE,SERVE_DIR
            );
        end
    endtask

    initial begin

        pruebas_dir = 0;
        pruebas_fsm = 0;

        INIT_GLOBAL = 1;
        START_PULSE = 0;
        PAUSE_PULSE = 0;
        RF_OK_EFF = 0;
        GOAL_J1 = 0;
        GOAL_J2 = 0;
        WIN_NEXT = 0;

        // Inicializacion del controlador
        @(posedge CLK_SYS);
        #1;

        if (STATE !== 0 || SERVE_DIR !== 1) begin
            $display("ERROR INICIALIZACION FSM");
            $stop;
        end

        pruebas_dir = pruebas_dir + 1;
        $display("OK: Inicializacion");

        // --------------------------------
        // Secuencia funcional dirigida
        // --------------------------------

        paso(1,0,0,0,0,0,0,0,0,
             "START sin RF");

        paso(1,0,1,0,0,0,0,0,1,
             "Inicio de partida");

        paso(0,0,1,0,0,0,0,1,1,
             "Juego activo");

        paso(0,1,1,1,0,0,0,1,5,
             "PAUSE domina gol");

        paso(1,0,1,0,0,0,0,5,5,
             "START ignorado en pausa manual");

        paso(0,1,0,0,0,0,0,5,5,
             "PAUSE con RF invalido");

        paso(0,0,1,0,0,0,0,5,5,
             "RF recuperado sin reanudar");

        paso(0,1,1,0,0,0,0,5,1,
             "PAUSE reanuda partida");

        paso(0,0,1,1,1,0,0,1,1,
             "Doble gol invalido");

        paso(0,0,1,1,0,0,0,1,2,
             "Captura gol J1");

        paso(0,1,0,0,0,0,0,2,0,
             "PUNTO no ganador");

        paso(1,0,1,0,0,0,0,0,1,
             "Nuevo inicio");

        paso(0,1,0,0,1,0,0,1,3,
             "RF domina PAUSE y gol");

        paso(0,1,1,0,0,0,0,3,3,
             "PAUSE ignorado en PAUSA_RF");

        paso(1,0,1,0,0,0,0,3,1,
             "START recupera PAUSA_RF");

        paso(0,0,1,0,1,0,0,1,2,
             "Captura gol J2");

        paso(0,0,0,0,0,1,0,2,4,
             "PUNTO ganador entra FIN");

        paso(1,1,1,1,0,0,0,4,4,
             "FIN conserva resultado");

        paso(0,0,1,0,0,0,1,4,0,
             "INIT_GLOBAL desde FIN");

        // --------------------------------
        // Comprobacion exhaustiva
        // 8 estados x 2^6 entradas
        // --------------------------------

        for (q=0; q<8; q=q+1)
        for (s=0; s<2; s=s+1)
        for (p=0; p<2; p=p+1)
        for (l=0; l<2; l=l+1)
        for (g=0; g<2; g=g+1)
        for (w=0; w<2; w=w+1)
        for (r=0; r<2; r=r+1) begin

            @(negedge CLK_SYS);

            // Inyeccion de estado para
            // cubrir tambien 110 y 111.
            // Solo se utiliza en testbench.
            dut.STATE = q[2:0];

            START_PULSE = s;
            PAUSE_PULSE = p;
            RF_OK_EFF = l;
            GOAL_J1 = g;
            GOAL_J2 = 0;
            WIN_NEXT = w;
            INIT_GLOBAL = r;

            #1;

            comprobar_salidas(
                q[2:0],s,p,l,g,0,w,r
            );

            esperado = modelo_estado(
                q[2:0],s,p,l,g,w,r
            );

            saque_anterior = SERVE_DIR;

            captura_esperada = (q == 1) &&
                               l && !p && !r && g;

            saque_esperado = r ? 1'b1 :
                captura_esperada ?
                ~saque_anterior : saque_anterior;

            @(posedge CLK_SYS);
            #1;

            if (STATE !== esperado ||
                SERVE_DIR !== saque_esperado) begin

                $display("ERROR EXHAUSTIVO FSM");
                $display(
                    "Q=%0d S=%0d P=%0d L=%0d",
                    q,s,p,l
                );
                $display(
                    "G=%0d W=%0d INIT=%0d",
                    g,w,r
                );
                $display(
                    "Esperado Q=%b DS=%b",
                    esperado,saque_esperado
                );
                $display(
                    "Obtenido Q=%b DS=%b",
                    STATE,SERVE_DIR
                );
                $stop;
            end

            pruebas_fsm = pruebas_fsm + 1;
        end

        $display("------------------------------");
        $display("DIRIGIDAS OK: %0d",pruebas_dir);
        $display("COMBINACIONES FSM OK: %0d",
                 pruebas_fsm);
        $display("FIN TESTBENCH CONTROL_JUEGO");
        $display("------------------------------");

        $finish;
    end

endmodule