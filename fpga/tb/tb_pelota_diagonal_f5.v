`timescale 1ns/1ps

module tb_pelota_diagonal_f5;
    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg CENTER_EN   = 1'b0;
    reg GAME_EN     = 1'b1;
    reg TICK_BALL   = 1'b0;
    reg SERVE_DIR   = 1'b1;
    reg HIT         = 1'b0;
    reg GOAL        = 1'b0;

    wire [3:0] XB, X_CAND;
    wire [2:0] YB, Y_CAND;
    wire DX, DY, PHASE, DY_CAND;

    pelota dut (
        .CLK_SYS(CLK_SYS), .INIT_GLOBAL(INIT_GLOBAL),
        .CENTER_EN(CENTER_EN), .GAME_EN(GAME_EN),
        .TICK_BALL(TICK_BALL), .SERVE_DIR(SERVE_DIR),
        .HIT(HIT), .GOAL(GOAL),
        .XB(XB), .YB(YB), .DX(DX), .DY(DY), .PHASE(PHASE),
        .X_CAND(X_CAND), .Y_CAND(Y_CAND), .DY_CAND(DY_CAND)
    );

    integer verificaciones = 0;

    task comprobar;
        input [3:0] x_esperado;
        input [2:0] y_esperado;
        input dx_esperado;
        input dy_esperado;
        begin
            if (XB !== x_esperado || YB !== y_esperado ||
                DX !== dx_esperado || DY !== dy_esperado) begin
                $display("ERROR: esperado X=%0d Y=%0d DX=%0b DY=%0b; obtenido X=%0d Y=%0d DX=%0b DY=%0b",
                    x_esperado, y_esperado, dx_esperado, dy_esperado,
                    XB, YB, DX, DY);
                $fatal(1, "Fallo en pelota diagonal");
            end
            verificaciones = verificaciones + 1;
            $display("OK %0d: X=%0d Y=%0d DX=%0b DY=%0b", verificaciones, XB, YB, DX, DY);
        end
    endtask

    task avanzar_tick;
        begin
            @(negedge CLK_SYS);
            TICK_BALL = 1'b1;
            @(posedge CLK_SYS);
            #1;
            @(negedge CLK_SYS);
            TICK_BALL = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(posedge CLK_SYS);
        #1;
        comprobar(4'd7, 3'd3, 1'b1, 1'b1);
        @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b0;

        // Una columna y una fila por tick.
        avanzar_tick(); comprobar(4'd8,  3'd4, 1'b1, 1'b1);
        avanzar_tick(); comprobar(4'd9,  3'd5, 1'b1, 1'b1);
        avanzar_tick(); comprobar(4'd10, 3'd6, 1'b1, 1'b1);
        avanzar_tick(); comprobar(4'd11, 3'd7, 1'b1, 1'b1);
        // Rebote en limite inferior: de Y=7 pasa a Y=6.
        avanzar_tick(); comprobar(4'd12, 3'd6, 1'b1, 1'b0);

        // Juego deshabilitado: la pelota no debe moverse.
        GAME_EN = 1'b0;
        avanzar_tick(); comprobar(4'd12, 3'd6, 1'b1, 1'b0);
        GAME_EN = 1'b1;

        // Gol: conservar posicion hasta que el sistema centre la pelota.
        GOAL = 1'b1;
        avanzar_tick(); comprobar(4'd12, 3'd6, 1'b1, 1'b0);
        GOAL = 1'b0;

        // Choque con paleta: invertir direccion X sin salir de la columna.
        HIT = 1'b1;
        avanzar_tick(); comprobar(4'd12, 3'd5, 1'b0, 1'b0);
        HIT = 1'b0;
        avanzar_tick(); comprobar(4'd11, 3'd4, 1'b0, 1'b0);

        // Centrado y saque hacia la izquierda.
        SERVE_DIR = 1'b0;
        @(negedge CLK_SYS);
        CENTER_EN = 1'b1;
        @(posedge CLK_SYS);
        #1;
        comprobar(4'd7, 3'd3, 1'b0, 1'b1);
        @(negedge CLK_SYS);
        CENTER_EN = 1'b0;
        avanzar_tick(); comprobar(4'd6, 3'd4, 1'b0, 1'b1);

        $display("PASS: pelota diagonal F5; %0d verificaciones correctas", verificaciones);
        $finish;
    end
endmodule
