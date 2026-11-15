`timescale 1ns/1ps

module tb_colisiones;

    reg GAME_EN;
    reg TICK_BALL;

    reg [3:0] XB;
    reg [3:0] X_CAND;
    reg [2:0] Y_CAND;
    reg DX;

    reg [2:0] YP1_EFF;
    reg [2:0] YP2_EFF;

    wire HIT_J1;
    wire HIT_J2;
    wire GOAL_J1;
    wire GOAL_J2;

    wire [3:0] eventos;

    integer pruebas;
    integer x, y, dxv, dyv, ph;
    integer yp1, yp2, en;
    integer yc_ref, dy_ref;
    reg [3:0] esperado;

    assign eventos = {
        HIT_J1, HIT_J2, GOAL_J1, GOAL_J2
    };

    // Modulo bajo prueba
    colisiones dut (
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

    // Prueba dirigida con resultado esperado
    task probar;
        input [3:0] x_in, xc_in;
        input [2:0] yc_in, p1_in, p2_in;
        input dx_in, en_in, tick_in;
        input [3:0] exp_in;
        input [8*70-1:0] nombre;
        begin
            XB = x_in;
            X_CAND = xc_in;
            Y_CAND = yc_in;
            YP1_EFF = p1_in;
            YP2_EFF = p2_in;
            DX = dx_in;
            GAME_EN = en_in;
            TICK_BALL = tick_in;

            #1;

            if (eventos !== exp_in) begin
                $display("ERROR: %0s", nombre);
                $display("Esperado: %b", exp_in);
                $display("Obtenido: %b", eventos);
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

        // Orden de eventos:
        // {HIT_J1, HIT_J2, GOAL_J1, GOAL_J2}

        // 1. Impacto contra paleta izquierda
        probar(1,0,3,3,3,0,1,1,
               4'b1000,"Impacto J1");

        // 2. J1 falla y anota J2
        probar(1,0,0,3,3,0,1,1,
               4'b0001,"Gol J2");

        // 3. Impacto contra paleta derecha
        probar(14,15,4,3,3,1,1,1,
               4'b0100,"Impacto J2");

        // 4. J2 falla y anota J1
        probar(14,15,7,3,3,1,1,1,
               4'b0010,"Gol J1");

        // 5. Movimiento interior
        probar(7,8,3,3,3,1,1,1,
               4'b0000,"Sin colision interior");

        // 6. Juego deshabilitado
        probar(14,15,7,3,3,1,0,1,
               4'b0000,"GAME_EN desactivado");

        // 7. Ausencia de TICK_BALL
        probar(1,0,0,3,3,0,1,0,
               4'b0000,"Sin TICK_BALL");

        // 8. Posicion efectiva J1
        probar(1,0,4,3,3,0,1,1,
               4'b1000,"Paleta efectiva J1");

        // 9. Posicion efectiva J2
        probar(14,15,6,3,5,1,1,1,
               4'b0100,"Paleta efectiva J2");

        // 10. Limite superior
        probar(1,0,0,0,3,0,1,1,
               4'b1000,"Impacto en Y=0");

        // 11. Limite inferior
        probar(14,15,7,3,6,1,1,1,
               4'b0100,"Impacto en Y=7");

        // 12. Direccion horizontal incorrecta
        probar(1,0,3,3,3,1,1,1,
               4'b0000,"Direccion no valida");

        // 13. Candidato X incorrecto
        probar(1,1,3,3,3,0,1,1,
               4'b0000,"Sin cruce izquierdo");

        // 14. Sin cruce derecho
        probar(14,14,3,3,3,1,1,1,
               4'b0000,"Sin cruce derecho");

        // 15. Ambos permisos desactivados
        probar(14,15,7,3,3,1,0,0,
               4'b0000,"Ambos permisos en cero");

        $display("Pruebas dirigidas: 15 OK");

        // --------------------------------
        // Comprobacion exhaustiva
        // de estados funcionales validos
        // --------------------------------

        for (x=1; x<=14; x=x+1)
        for (y=0; y<8; y=y+1)
        for (dxv=0; dxv<2; dxv=dxv+1)
        for (dyv=0; dyv<2; dyv=dyv+1)
        for (ph=0; ph<2; ph=ph+1)
        for (yp1=0; yp1<7; yp1=yp1+1)
        for (yp2=0; yp2<7; yp2=yp2+1)
        for (en=0; en<2; en=en+1) begin

            XB = x;
            DX = dxv;
            YP1_EFF = yp1;
            YP2_EFF = yp2;
            GAME_EN = en;
            TICK_BALL = 1;

            // Referencia horizontal
            X_CAND = dxv ? x+1 : x-1;

            // Referencia vertical F2
            dy_ref = dyv;

            if (ph) begin
                if ((y==0 && dyv==0) ||
                    (y==7 && dyv==1))
                    dy_ref = 1-dyv;

                yc_ref = y +
                         (dy_ref ? 1 : -1);
            end
            else begin
                yc_ref = y;
            end

            Y_CAND = yc_ref;

            // Resultado funcional esperado
            esperado = 4'b0000;

            if (en && dxv==0 && x==1) begin
                if ((yc_ref==yp1) ||
                    (yc_ref==yp1+1))
                    esperado = 4'b1000;
                else
                    esperado = 4'b0001;
            end

            else if (en && dxv==1 && x==14) begin
                if ((yc_ref==yp2) ||
                    (yc_ref==yp2+1))
                    esperado = 4'b0100;
                else
                    esperado = 4'b0010;
            end

            #1;

            if (eventos !== esperado) begin
                $display("ERROR EXHAUSTIVO");
                $display(
                    "X=%0d Y=%0d DX=%0d DY=%0d PH=%0d",
                    x,y,dxv,dyv,ph
                );
                $display(
                    "YP1=%0d YP2=%0d EN=%0d",
                    yp1,yp2,en
                );
                $display(
                    "Esperado=%b Obtenido=%b",
                    esperado,eventos
                );
                $stop;
            end

            pruebas = pruebas + 1;
        end

        $display("------------------------------");
        $display("PRUEBAS SUPERADAS: %0d", pruebas);
        $display("FIN TESTBENCH COLISIONES");
        $display("------------------------------");

        $finish;
    end

endmodule
