`timescale 1ns/1ps

module tb_paletas;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg CENTER_EN;
    reg CAPTURE_GOAL;
    reg GAME_EN;
    reg TICK_PADDLE;

    reg [1:0] CMD_J1;
    reg [1:0] CMD_J2;

    wire [2:0] YP1;
    wire [2:0] YP2;
    wire [2:0] YP1_EFF;
    wire [2:0] YP2_EFF;

    integer pruebas;

    // Modulo bajo prueba
    paletas dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CENTER_EN(CENTER_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .GAME_EN(GAME_EN),
        .TICK_PADDLE(TICK_PADDLE),
        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),
        .YP1(YP1),
        .YP2(YP2),
        .YP1_EFF(YP1_EFF),
        .YP2_EFF(YP2_EFF)
    );

    // Reloj de 50 MHz: periodo 20 ns
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // Comprobar posiciones registradas
    task comprobar;
        input [2:0] e1, e2;
        input [8*70-1:0] nombre;
        begin
            if (YP1 !== e1 || YP2 !== e2) begin
                $display("ERROR: %0s", nombre);
                $display("Esperado: %d, %d", e1, e2);
                $display("Obtenido: %d, %d", YP1, YP2);
                $stop;
            end
            else begin
                pruebas = pruebas + 1;
                $display("OK: %0s", nombre);
            end
        end
    endtask

    // Comprobar posiciones efectivas
    task comprobar_eff;
        input [2:0] e1, e2;
        input [8*70-1:0] nombre;
        begin
            if (YP1_EFF !== e1 ||
                YP2_EFF !== e2) begin
                $display("ERROR EFF: %0s", nombre);
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

        INIT_GLOBAL = 1;
        CENTER_EN = 0;
        CAPTURE_GOAL = 0;
        GAME_EN = 0;
        TICK_PADDLE = 0;
        CMD_J1 = 2'b00;
        CMD_J2 = 2'b00;

        // P1: inicializacion
        @(posedge CLK_SYS); #1;
        comprobar(3, 3, "Inicializacion");

        // P2: movimiento independiente
        @(negedge CLK_SYS);
        INIT_GLOBAL = 0;
        GAME_EN = 1;
        TICK_PADDLE = 1;
        CMD_J1 = 2'b01;
        CMD_J2 = 2'b10;

        #1;
        comprobar_eff(2, 4, "Posicion efectiva");

        @(posedge CLK_SYS); #1;
        comprobar(2, 4, "Movimiento independiente");

        // P3: sin tick no hay movimiento
        @(negedge CLK_SYS);
        TICK_PADDLE = 0;

        @(posedge CLK_SYS); #1;
        comprobar(2, 4, "Sin tick");

        // P4: pulsacion sostenida
        @(negedge CLK_SYS);
        TICK_PADDLE = 1;

        @(posedge CLK_SYS); #1;
        comprobar(1, 5, "Pulsacion sostenida 1");

        @(posedge CLK_SYS); #1;
        comprobar(0, 6, "Pulsacion sostenida 2");

        // P5: limites verticales
        @(posedge CLK_SYS); #1;
        comprobar(0, 6, "Limites 0 y 6");

        // P6: comandos simultaneos
        @(negedge CLK_SYS);
        CMD_J1 = 2'b11;
        CMD_J2 = 2'b11;

        @(posedge CLK_SYS); #1;
        comprobar(0, 6, "Conflicto de botones");

        // P7: juego deshabilitado
        @(negedge CLK_SYS);
        GAME_EN = 0;
        CMD_J1 = 2'b10;
        CMD_J2 = 2'b01;

        @(posedge CLK_SYS); #1;
        comprobar(0, 6, "Juego deshabilitado");

        // P8: centrado
        @(negedge CLK_SYS);
        CENTER_EN = 1;

        @(posedge CLK_SYS); #1;
        comprobar(3, 3, "Centrado");

        // P9: gol y tick simultaneos
        @(negedge CLK_SYS);
        CENTER_EN = 0;
        GAME_EN = 1;
        CAPTURE_GOAL = 1;
        CMD_J1 = 2'b01;
        CMD_J2 = 2'b10;

        #1;
        comprobar_eff(2, 4, "EFF durante gol");

        @(posedge CLK_SYS); #1;
        comprobar(3, 3, "Gol bloquea escritura");

        // P10: movimiento posterior
        @(negedge CLK_SYS);
        CAPTURE_GOAL = 0;

        @(posedge CLK_SYS); #1;
        comprobar(2, 4, "Movimiento posterior");

        // P11: prioridad de inicializacion
        @(negedge CLK_SYS);
        INIT_GLOBAL = 1;

        @(posedge CLK_SYS); #1;
        comprobar(3, 3, "Prioridad INIT");

        $display("--------------------------");
        $display("PRUEBAS SUPERADAS: %0d", pruebas);
        $display("FIN TESTBENCH PALETAS");
        $display("--------------------------");

        $finish;
    end

endmodule