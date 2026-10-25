// ============================================================================
//  tb_puntaje.v  -  Pruebas T05 y T06
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Revisamos el marcador por separado:
//   - un pulso de gol suma exactamente un punto y solo al jugador correcto;
//   - si "contar" está en 0 (pausa, punto anotado...) el gol no se cuenta;
//   - el contador se satura en 9 y levanta la bandera de victoria;
//   - "limpiar" y "rst" devuelven el marcador a 0-0.
// ============================================================================

`timescale 1ns / 1ps

module tb_puntaje;

    `include "tb_comun.vh"

    reg clk = 0, rst = 1, limpiar = 0, contar = 1, g1 = 0, g2 = 0;
    wire [3:0] p1, p2;
    wire gana1, gana2;

    always #10 clk = ~clk;

    puntaje #(.PUNTOS_VICTORIA(9)) dut (
        .clk(clk), .rst(rst), .limpiar(limpiar), .contar(contar),
        .gol_j1(g1), .gol_j2(g2), .p1(p1), .p2(p2), .gana_j1(gana1), .gana_j2(gana2)
    );

    task gol;
        input jugador;   // 0 = J1, 1 = J2
        begin
            @(negedge clk) begin g1 = (jugador == 0); g2 = (jugador == 1); end
            @(negedge clk) begin g1 = 0; g2 = 0; end
            @(negedge clk);
        end
    endtask

    integer i;

    initial begin
        $dumpfile("sim/tb_puntaje.vcd");
        $dumpvars(0, tb_puntaje);
        $display("== tb_puntaje ==");

        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        `VERIFICAR(p1 == 0 && p2 == 0 && !gana1 && !gana2, "marcador inicial")

        // Un gol de cada jugador
        gol(0);
        `VERIFICAR(p1 == 1 && p2 == 0, $sformatf("T05 gol J1: %0d-%0d", p1, p2))
        gol(1);
        `VERIFICAR(p1 == 1 && p2 == 1, $sformatf("T05 gol J2: %0d-%0d", p1, p2))

        // Un pulso largo (varios ciclos) mostraría si se cuenta más de una vez.
        // En el diseño real el gol dura un ciclo, pero queremos saber qué pasa.
        @(negedge clk) g1 = 1;
        @(negedge clk) g1 = 0;
        `VERIFICAR(p1 == 2, "pulso de un ciclo suma uno")

        // Con contar = 0 no suma nada
        contar = 0;
        gol(0); gol(1);
        `VERIFICAR(p1 == 2 && p2 == 1, "se conto un gol con contar = 0")
        contar = 1;

        // Llevamos a J1 hasta 9 y seguimos metiendo goles: debe saturarse
        for (i = 0; i < 12; i = i + 1) gol(0);
        `VERIFICAR(p1 == 9 && gana1 && !gana2, $sformatf("saturacion en 9: p1=%0d", p1))
        `VERIFICAR(p2 == 1, "el gol de J1 afecto a J2")

        // T06: limpiar
        @(negedge clk) limpiar = 1;
        @(negedge clk) limpiar = 0;
        `VERIFICAR(p1 == 0 && p2 == 0 && !gana1, "T06 limpiar marcador")

        // T06: rst en medio de la partida
        gol(1); gol(1); gol(0);
        `VERIFICAR(p1 == 1 && p2 == 2, "marcador antes del reinicio")
        @(negedge clk) rst = 1;
        @(negedge clk) rst = 0;
        `VERIFICAR(p1 == 0 && p2 == 0, "T06 reinicio")

        // J2 gana
        for (i = 0; i < 9; i = i + 1) gol(1);
        `VERIFICAR(p2 == 9 && gana2 && !gana1, "victoria de J2")

        reporte_final("tb_puntaje");
        $finish;
    end

endmodule
