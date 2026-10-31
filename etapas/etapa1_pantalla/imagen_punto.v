// ============================================================================
//  imagen_punto.v  -  Etapa 1: generador de imagen de "un solo punto"
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  En la etapa 1 todavía no hay pelota ni paletas: solo queremos prender UN
//  LED en la posición (X, Y) y comprobar que llega al sitio correcto de la
//  pantalla de 8 x 32. Lo armamos a propósito con decodificadores, porque así
//  el circuito sale directo de las tablas de verdad que hicimos:
//
//     Y[2:0]  --> decodificador 3 a 8 --> F7..F0  (qué fila / qué dígito)
//     X[4:3]  --> decodificador 2 a 4 --> C3..C0  (qué matriz / qué chip)
//     X[2:0]  --> decodificador 3 a 8 --> B7..B0  (qué columna dentro de la matriz)
//
//  Y cada bit que le mandamos a los MAX7219 es un AND de tres salidas:
//
//     LED(matriz m, dígito d, bit b) = C_m · F_d · B_b
//
//  Son 4 x 8 x 8 = 256 compuertas AND de tres entradas, una por LED.
//
//  Ojo con el orden de los bits: en estos módulos el bit 7 de cada dígito es
//  la columna de la IZQUIERDA de la matriz. Por eso la columna k dentro de la
//  matriz (k = X[2:0]) corresponde al bit 7 - k. Si al montar se ve en espejo,
//  se pone INV_BITS = 1; si se ve de cabeza, INV_DIGITOS = 1.
//
//  Además dejamos un patrón de calibración (una "Γ" por matriz con el brazo
//  de m + 2 LEDs) que se ve cuando modo_prueba = 1. Sirve para saber, de un
//  vistazo, si alguna matriz quedó girada o si el orden de los chips está al
//  revés.
// ============================================================================

`timescale 1ns / 1ps

module imagen_punto #(
    parameter INV_BITS    = 0,
    parameter INV_DIGITOS = 0
)(
    input  wire [4:0]   x,             // columna 0..31
    input  wire [2:0]   y,             // fila 0..7 (0 = arriba)
    input  wire         modo_prueba,
    output wire [255:0] bytes          // bytes[(matriz*8 + dígito)*8 +: 8]
);

    // ------------------------------------------------------------------
    // Los tres decodificadores (tablas 3, 4 y 5 de la guía de la etapa 1)
    // ------------------------------------------------------------------
    wire [7:0] F = 8'b0000_0001 << y;          // fila
    wire [3:0] C = 4'b0001      << x[4:3];     // matriz (chip)
    wire [7:0] K = 8'b0000_0001 << x[2:0];     // columna dentro de la matriz

    // La columna k va en el bit 7 - k: le damos la vuelta al vector
    wire [7:0] B;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_rev
            assign B[i] = (INV_BITS != 0) ? K[i] : K[7 - i];
        end
    endgenerate

    // ------------------------------------------------------------------
    // Matriz de compuertas AND (y el multiplexor con el patrón de prueba)
    // ------------------------------------------------------------------
    genvar m, d, b;
    generate
        for (m = 0; m < 4; m = m + 1) begin : g_mat
            for (d = 0; d < 8; d = d + 1) begin : g_dig
                for (b = 0; b < 8; b = b + 1) begin : g_bit
                    // fila física que maneja este dígito
                    localparam integer FILA = (INV_DIGITOS != 0) ? (7 - d) : d;
                    // columna dentro de la matriz que maneja este bit
                    localparam integer COL  = (INV_BITS != 0) ? b : (7 - b);
                    // Patrón de calibración: "Γ" con esquina arriba a la izquierda
                    localparam PATRON = ((FILA == 0) && (COL <= m + 1)) || ((COL == 0) && (FILA <= 2));

                    wire punto = C[m] & F[FILA] & B[b];
                    assign bytes[(m*8 + d)*8 + b] = modo_prueba ? (PATRON != 0) : punto;
                end
            end
        end
    endgenerate

endmodule
