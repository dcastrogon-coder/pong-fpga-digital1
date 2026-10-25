// ============================================================================
//  tb_pelota.v  -  Pruebas T03, T04 y T05
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Aquí probamos el registro de la pelota con su lógica de colisiones ya
//  conectada. Tiene tres partes:
//
//   1. Casos dirigidos: rebote en el techo, en el piso, con cada paleta y un
//      gol de cada lado. Son los casos que uno dibujaría a mano en el tablero.
//   2. Una "partida aleatoria" de miles de pasos donde movemos las paletas al
//      azar y comparamos cada paso con el modelo de referencia.
//   3. Un monitor que vigila todo el tiempo que la pelota SOLO cambia en el
//      ciclo siguiente a un tick (o a un saque) -> T03, y que cada vez que
//      la pelota se escapa aparece exactamente UN pulso de gol -> T05.
// ============================================================================

`timescale 1ns / 1ps

module tb_pelota;

    `include "tb_comun.vh"
    `include "modelo_referencia.vh"

    reg        clk = 0, rst = 1;
    reg        tick = 0, hab = 1, saque = 0, s_dx = 1, s_dy = 1;
    reg  [2:0] s_y = 3;
    reg  [2:0] yp1 = 2, yp2 = 2;
    wire [XB-1:0] x;
    wire [2:0] y;
    wire       dx, dy, g1, g2, rpal, rpar;

    always #10 clk = ~clk;   // 50 MHz, como la tarjeta

    pelota #(.LP(3), .ANCHO(ANCHO)) dut (
        .clk(clk), .rst(rst), .tick(tick), .habilitar(hab),
        .saque(saque), .saque_dx(s_dx), .saque_dy(s_dy), .saque_y(s_y),
        .yp1(yp1), .yp2(yp2),
        .x(x), .y(y), .dx(dx), .dy(dy),
        .gol_j1(g1), .gol_j2(g2), .rebote_paleta(rpal), .rebote_pared(rpar)
    );

    // ------------------------------------------------------------------
    // Monitor T03 y T05
    // ------------------------------------------------------------------
    reg [8:0] est_ant;
    reg       tick_ant = 0, hab_ant = 0, saque_ant = 0;
    reg       fuera_ant = 0;
    integer   goles_pulsos = 0, escapes = 0;

    wire [8:0] est   = {x, y, dx, dy};
    wire       fuera = (x == 0) || (x == ULT);

    always @(posedge clk) begin
        if (!rst) begin
            if (est !== est_ant && !(tick_ant && hab_ant) && !saque_ant) begin
                errores = errores + 1;
                $display("  [FALLA] t=%0t : la pelota cambio sin tick ni saque", $time);
            end
            if (g1 || g2) goles_pulsos = goles_pulsos + 1;
            if (fuera && !fuera_ant) escapes = escapes + 1;
            // El gol tiene que coincidir con la llegada a la columna 0 o a la última
            if ((g1 || g2) && !(fuera && !fuera_ant)) begin
                errores = errores + 1;
                $display("  [FALLA] t=%0t : pulso de gol sin escape", $time);
            end
            if (g1 && x != ULT) begin errores = errores + 1; $display("  [FALLA] gol_j1 con X=%0d", x); end
            if (g2 && x != 0)  begin errores = errores + 1; $display("  [FALLA] gol_j2 con X=%0d", x); end
        end
        est_ant   <= est;
        tick_ant  <= tick;
        hab_ant   <= hab;
        saque_ant <= saque;
        fuera_ant <= fuera;
    end

    // ------------------------------------------------------------------
    // Tareas de apoyo
    // ------------------------------------------------------------------
    task dar_tick;
        begin
            @(negedge clk) tick = 1;
            @(negedge clk) tick = 0;
            repeat (3) @(negedge clk);
        end
    endtask

    task sacar;
        input dir_x, dir_y;
        input [2:0] fila;
        begin
            @(negedge clk) begin saque = 1; s_dx = dir_x; s_dy = dir_y; s_y = fila; end
            @(negedge clk) saque = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    // Avanza un tick comparando con el modelo de referencia
    integer rnx, rny, rdx, rdy, ri, rd, rg1, rg2, rp, rf;
    task tick_verificado;
        begin
            ref_paso(x, y, dx, dy, yp1, yp2, 3, rnx, rny, rdx, rdy, ri, rd, rg1, rg2, rp, rf);
            @(negedge clk) tick = 1;
            @(negedge clk) begin
                tick = 0;
                `VERIFICAR(g1 == rg1 && g2 == rg2 && rpal == (ri | rd) && rpar == rp,
                    $sformatf("eventos distintos al modelo en X=%0d Y=%0d", x, y))
            end
            `VERIFICAR(x == rnx && y == rny && dx == rdx && dy == rdy,
                $sformatf("paso distinto al modelo: RTL (%0d,%0d,%0d,%0d) ref (%0d,%0d,%0d,%0d)",
                          x, y, dx, dy, rnx, rny, rdx, rdy))
            repeat (2) @(negedge clk);
        end
    endtask

    integer i, k;

    initial begin
        $dumpfile("sim/tb_pelota.vcd");
        $dumpvars(0, tb_pelota);
        $display("== tb_pelota (%0d columnas) ==", ANCHO);

        repeat (4) @(negedge clk);
        rst = 0;
        repeat (2) @(negedge clk);
        `VERIFICAR(x == (ANCHO/2 - 1) && y == 3 && dx == 1 && dy == 1, "estado de reinicio")

        // ------------- T03: sin tick no se mueve -------------
        repeat (200) @(negedge clk);
        `VERIFICAR(x == (ANCHO/2 - 1) && y == 3, "la pelota se movio sin tick")
        dar_tick;
        `VERIFICAR(x == (ANCHO/2) && y == 4, $sformatf("un tick = una casilla: X=%0d Y=%0d", x, y))

        // ------------- habilitar = 0 congela -------------
        hab = 0; dar_tick; dar_tick;
        `VERIFICAR(x == (ANCHO/2) && y == 4, "se movio con habilitar = 0")
        hab = 1;

        // ------------- T04a: rebote en el techo -------------
        sacar(1, 0, 3'd1);            // sale desde la fila 1 subiendo
        tick_verificado;              // -> fila 0
        `VERIFICAR(y == 0 && dy == 0, "llegada al techo")
        tick_verificado;              // rebota
        `VERIFICAR(y == 1 && dy == 1, $sformatf("T04a rebote techo: Y=%0d DY=%0d", y, dy))

        // ------------- T04b: rebote en el piso -------------
        sacar(0, 1, 3'd6);
        tick_verificado;              // -> fila 7
        tick_verificado;              // rebota
        `VERIFICAR(y == 6 && dy == 0, $sformatf("T04b rebote piso: Y=%0d DY=%0d", y, dy))

        // ------------- T04c: rebote con la paleta de J2 -------------
        // Sacamos hacia J2 y ponemos la paleta justo donde va a llegar.
        sacar(1, 1, 3'd3);
        while (x != ULT - 1) tick_verificado;             // hasta la columna vecina a J2
        yp2 = (y >= 1) ? y - 1 : 0;                       // la fila de la pelota queda en el centro de la paleta
        tick_verificado;
        `VERIFICAR(dx == 0 && x == ULT - 2, $sformatf("T04c rebote paleta J2: X=%0d DX=%0d", x, dx))

        // ------------- T04d: rebote con la paleta de J1 -------------
        while (x != 1) tick_verificado;                   // hasta la columna vecina a J1
        yp1 = (y >= 1) ? ((y - 1 > 5) ? 5 : y - 1) : 0;
        tick_verificado;
        `VERIFICAR(dx == 1 && x == 2, $sformatf("T04d rebote paleta J1: X=%0d DX=%0d", x, dx))

        // ------------- T05a: gol de J2 (J1 falla) -------------
        sacar(0, 1, 3'd3);
        while (x != 1) tick_verificado;
        yp1 = (y >= 4) ? 0 : 5;                           // quitamos la paleta del camino
        begin : gol_izq
            integer antes;
            antes = goles_pulsos;
            tick_verificado;
            `VERIFICAR(x == 0 && goles_pulsos == antes + 1, "T05a gol de J2")
            // Ticks adicionales: la pelota queda quieta y NO se repite el gol
            for (k = 0; k < 5; k = k + 1) tick_verificado;
            `VERIFICAR(x == 0 && goles_pulsos == antes + 1, "T05a el gol se conto mas de una vez")
        end

        // ------------- T05b: gol de J1 (J2 falla) -------------
        sacar(1, 0, 3'd4);
        while (x != ULT - 1) tick_verificado;
        yp2 = (y >= 4) ? 0 : 5;
        tick_verificado;
        `VERIFICAR(x == ULT, "T05b gol de J1")

        // ------------- Saque y tick en el mismo ciclo: gana el saque -------------
        @(negedge clk) begin tick = 1; saque = 1; s_dx = 0; s_dy = 0; s_y = 5; end
        @(negedge clk) begin tick = 0; saque = 0; end
        @(negedge clk);
        `VERIFICAR(x == (ANCHO/2) && y == 5 && dx == 0 && dy == 0, "prioridad del saque sobre el tick")

        // ------------- Partida aleatoria contra el modelo -------------
        $display("  partida aleatoria de 6000 pasos...");
        for (i = 0; i < 6000; i = i + 1) begin
            // Las paletas se mueven al azar como si fueran jugadores torpes
            k = $random % 3;
            if (k == 1 && yp1 < 5) yp1 = yp1 + 1; else if (k == 2 && yp1 > 0) yp1 = yp1 - 1;
            k = $random % 3;
            if (k == 1 && yp2 < 5) yp2 = yp2 + 1; else if (k == 2 && yp2 > 0) yp2 = yp2 - 1;

            if (x == 0 || x == ULT) begin
                tick_verificado;  // un tick extra en la posición de gol
                sacar($random, $random, 3 + ($random & 1));
            end else begin
                tick_verificado;
            end
        end

        $display("  pulsos de gol: %0d   escapes de la pelota: %0d", goles_pulsos, escapes);
        `VERIFICAR(goles_pulsos == escapes, "T05 numero de goles distinto al de escapes")
        `VERIFICAR(goles_pulsos > 20, "la partida aleatoria casi no produjo goles (prueba poco util)")

        reporte_final("tb_pelota");
        $finish;
    end

endmodule
