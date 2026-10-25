// ============================================================================
//  siete_segmentos.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Decodificador BCD a siete segmentos para el marcador (requisito R06).
//  Es combinacional y sale directo de la tabla de verdad de abajo.
//
//  Orden de los bits de salida: seg = {g, f, e, d, c, b, a}
//
//         a
//        ---
//     f |   | b
//        -g-
//     e |   | c
//        ---
//         d
//
//   valor | g f e d c b a   (lógica positiva, 1 = segmento encendido)
//   ------+---------------
//     0   | 0 1 1 1 1 1 1
//     1   | 0 0 0 0 1 1 0
//     2   | 1 0 1 1 0 1 1
//     3   | 1 0 0 1 1 1 1
//     4   | 1 1 0 0 1 1 0
//     5   | 1 1 0 1 1 0 1
//     6   | 1 1 1 1 1 0 1
//     7   | 0 0 0 0 1 1 1
//     8   | 1 1 1 1 1 1 1
//     9   | 1 1 0 1 1 1 1
//   10-15 | 1 0 0 0 0 0 0   <- mostramos un guion: si aparece, algo anda mal
//
//  Todavía no sabemos si los displays que compremos serán de ánodo común o de
//  cátodo común, así que la polaridad es un parámetro. Con ánodo común el
//  segmento se enciende con 0 (ACTIVO_BAJO = 1).
// ============================================================================

`timescale 1ns / 1ps

module siete_segmentos #(
    parameter ACTIVO_BAJO = 1
)(
    input  wire [3:0] valor,
    input  wire       apagar,     // para hacerlo titilar
    output wire [6:0] seg
);

    reg [6:0] patron;

    always @(*) begin
        case (valor)
            4'd0: patron = 7'b0111111;
            4'd1: patron = 7'b0000110;
            4'd2: patron = 7'b1011011;
            4'd3: patron = 7'b1001111;
            4'd4: patron = 7'b1100110;
            4'd5: patron = 7'b1101101;
            4'd6: patron = 7'b1111101;
            4'd7: patron = 7'b0000111;
            4'd8: patron = 7'b1111111;
            4'd9: patron = 7'b1101111;
            default: patron = 7'b1000000;
        endcase
    end

    wire [6:0] positivo = apagar ? 7'b0000000 : patron;

    assign seg = (ACTIVO_BAJO != 0) ? ~positivo : positivo;

endmodule
