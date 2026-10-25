// ============================================================================
//  tb_siete_segmentos.v  -  Tabla del marcador (apoya T06)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Recorremos las 16 entradas posibles en las dos polaridades y comparamos
//  con la tabla que dibujamos a mano. De paso imprimimos cada dígito en
//  "ASCII art" para verlo con nuestros propios ojos en el registro.
// ============================================================================

`timescale 1ns / 1ps

module tb_siete_segmentos;

    `include "tb_comun.vh"

    reg  [3:0] valor;
    reg        apagar;
    wire [6:0] seg_ac, seg_cc;   // ánodo común (activo en bajo) y cátodo común

    siete_segmentos #(.ACTIVO_BAJO(1)) dut_ac (.valor(valor), .apagar(apagar), .seg(seg_ac));
    siete_segmentos #(.ACTIVO_BAJO(0)) dut_cc (.valor(valor), .apagar(apagar), .seg(seg_cc));

    reg [6:0] tabla [0:15];
    integer i;

    // Dibuja el dígito con los segmentos {g,f,e,d,c,b,a}
    task dibujar;
        input [6:0] s;
        begin
            $display("     %s", s[0] ? " __ " : "    ");
            $display("     %s%s%s", s[5] ? "|" : " ", s[6] ? "__" : "  ", s[1] ? "|" : " ");
            $display("     %s%s%s", s[4] ? "|" : " ", s[3] ? "__" : "  ", s[2] ? "|" : " ");
        end
    endtask

    initial begin
        $display("== tb_siete_segmentos ==");
        tabla[0] = 7'b0111111; tabla[1] = 7'b0000110; tabla[2] = 7'b1011011;
        tabla[3] = 7'b1001111; tabla[4] = 7'b1100110; tabla[5] = 7'b1101101;
        tabla[6] = 7'b1111101; tabla[7] = 7'b0000111; tabla[8] = 7'b1111111;
        tabla[9] = 7'b1101111;
        for (i = 10; i < 16; i = i + 1) tabla[i] = 7'b1000000;

        apagar = 0;
        for (i = 0; i < 16; i = i + 1) begin
            valor = i; #1;
            `VERIFICAR(seg_cc == tabla[i], $sformatf("valor %0d catodo comun: %b", i, seg_cc))
            `VERIFICAR(seg_ac == ~tabla[i], $sformatf("valor %0d anodo comun: %b", i, seg_ac))
            if (i < 10) begin
                $display("  valor %0d  (gfedcba = %b)", i, seg_cc);
                dibujar(seg_cc);
            end
        end

        apagar = 1;
        for (i = 0; i < 16; i = i + 1) begin
            valor = i; #1;
            `VERIFICAR(seg_cc == 7'b0 && seg_ac == 7'h7F, "apagar no apago el display")
        end

        reporte_final("tb_siete_segmentos");
        $finish;
    end

endmodule
