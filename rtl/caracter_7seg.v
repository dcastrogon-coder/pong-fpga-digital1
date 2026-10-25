// ============================================================================
//  caracter_7seg.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Amplía el decodificador de siete segmentos con unas cuantas letras para
//  poder escribir mensajes cortos en el display de 8 dígitos de la tarjeta
//  ("HOLA", "PAUS", "GOL", "GAnA"...). Para los dígitos 0-9 reutilizamos
//  siete_segmentos.v, que ya estaba probado; aquí solo agregamos las letras.
//
//  Salida en lógica positiva (1 = segmento encendido), orden {g,f,e,d,c,b,a}.
//  La polaridad física se aplica en display_multiplexado.v.
//
//   código | símbolo | g f e d c b a
//   -------+---------+---------------
//    0-9   | 0-9     | (tabla de siete_segmentos.v)
//    10    | H       | 1 1 1 0 1 1 0
//    11    | L       | 0 1 1 1 0 0 0
//    12    | A       | 1 1 1 0 1 1 1
//    13    | P       | 1 1 1 0 0 1 1
//    14    | U       | 0 1 1 1 1 1 0
//    15    | G       | 0 1 1 1 1 0 1
//    16    | n       | 1 0 1 0 1 0 0
//    17    | -       | 1 0 0 0 0 0 0
//    18    | (vacío) | 0 0 0 0 0 0 0
//    19-31 | (vacío) | 0 0 0 0 0 0 0
//  La "O" y la "S" las escribimos con el 0 y el 5.
// ============================================================================

`timescale 1ns / 1ps

module caracter_7seg (
    input  wire [4:0] codigo,
    output wire [6:0] seg        // {g,f,e,d,c,b,a}, 1 = encendido
);

    // Los dígitos salen del decodificador de siempre (en lógica positiva)
    wire [6:0] seg_digito;
    siete_segmentos #(.ACTIVO_BAJO(0)) u_digito (
        .valor(codigo[3:0]), .apagar(1'b0), .seg(seg_digito)
    );

    // Lo escribimos como función + assign (y no como always @(*)) por lo
    // mismo que en generador_ticks: así el simulador lo evalúa desde t = 0.
    function [6:0] letra;
        input [4:0] c;
        begin
            case (c)
                5'd10:   letra = 7'b1110110;   // H
                5'd11:   letra = 7'b0111000;   // L
                5'd12:   letra = 7'b1110111;   // A
                5'd13:   letra = 7'b1110011;   // P
                5'd14:   letra = 7'b0111110;   // U
                5'd15:   letra = 7'b0111101;   // G
                5'd16:   letra = 7'b1010100;   // n
                5'd17:   letra = 7'b1000000;   // -
                default: letra = 7'b0000000;   // vacío
            endcase
        end
    endfunction

    assign seg = (codigo < 5'd10) ? seg_digito : letra(codigo);

endmodule
