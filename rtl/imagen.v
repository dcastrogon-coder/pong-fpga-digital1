// ============================================================================
//  imagen.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Generador de la imagen 8 x ANCHO (requisito R07). Con el módulo de cuatro
//  matrices (MAX7219 x4) que compramos ANCHO = 32; con dos matrices sueltas
//  sería 16. Es lógica 100 % combinacional en dos partes:
//
//  (a) Imagen lógica: la función pixel(fila, columna) que vale 1 donde debe
//      encenderse un LED. La guardamos en un vector plano:
//          img[fila*ANCHO + columna]
//      pixel = paleta_J1 + paleta_J2 + pelota + efecto_fin
//        paleta_J1 = (col == 0)       · (YP1 <= fila <= YP1+LP-1)
//        paleta_J2 = (col == ANCHO-1) · (YP2 <= fila <= YP2+LP-1)
//        pelota    = (col == X)       · (fila == Y) · mostrar_pelota
//        efecto_fin= fin · parpadeo · (columna en la mitad del ganador)
//
//      Si modo_prueba = 1 la imagen del juego se reemplaza por un patrón de
//      calibración: en cada matriz 8x8 dibujamos una "Γ" con la esquina
//      arriba a la izquierda. El brazo vertical mide 3 LEDs y el horizontal
//      mide (número de matriz + 2) LEDs. Así, con solo mirar la pantalla,
//      sabemos si una matriz quedó girada o en espejo y en qué orden están.
//
//  (b) Mapeo físico hacia los MAX7219: cada matriz tiene 8 registros de
//      dígito (0x01..0x08) de 8 bits. Cómo se relaciona "dígito/bit" con
//      "fila/columna" depende de cómo esté soldada la matriz en el módulo.
//      Lo resolvemos con tres parámetros, sin tocar la lógica:
//        TRANSPONER  : 0 -> cada dígito es una fila;  1 -> cada dígito es una columna
//        INV_BITS    : invierte el orden de los bits dentro del byte
//        INV_DIGITOS : invierte el orden de los dígitos (pantalla al revés)
//      La salida "bytes" queda organizada como bytes[(modulo*8 + digito)*8 +: 8],
//      donde el módulo 0 es la matriz de la izquierda (columnas 0-7). El orden
//      de los chips en la cadena lo resuelve max7219_tx.
// ============================================================================

`timescale 1ns / 1ps

module imagen #(
    parameter integer LP          = 3,
    parameter integer ANCHO       = 32,
    parameter integer XB          = (ANCHO > 16) ? 5 : 4,
    parameter         TRANSPONER  = 0,
    parameter         INV_BITS    = 0,
    parameter         INV_DIGITOS = 0
)(
    input  wire [XB-1:0]      x,
    input  wire [2:0]         y,
    input  wire [2:0]         yp1,
    input  wire [2:0]         yp2,
    input  wire               mostrar_pelota,
    input  wire               modo_fin,
    input  wire               ganador,        // 0 = J1 (izquierda), 1 = J2 (derecha)
    input  wire               parpadeo,
    input  wire               modo_prueba,    // patrón de calibración de orientación
    output wire [8*ANCHO-1:0] img,            // imagen lógica, img[fila*ANCHO+col]
    output wire [8*ANCHO-1:0] bytes           // datos listos para los registros de dígito
);

    localparam integer N_MOD = ANCHO / 8;

    // ------------------------------------------------------------------
    // (a) Imagen lógica
    // ------------------------------------------------------------------
    genvar f, c;
    generate
        for (f = 0; f < 8; f = f + 1) begin : g_fila
            for (c = 0; c < ANCHO; c = c + 1) begin : g_col
                wire en_pal1  = (c == 0)         && (f >= yp1) && (f <= yp1 + LP - 1);
                wire en_pal2  = (c == ANCHO - 1) && (f >= yp2) && (f <= yp2 + LP - 1);
                wire en_bola  = mostrar_pelota && (x == c) && (y == f);
                wire en_final = modo_fin && parpadeo &&
                                (ganador ? (c >= ANCHO/2) : (c < ANCHO/2));
                wire juego    = en_pal1 | en_pal2 | en_bola | en_final;

                // Patrón de calibración (constante para cada LED)
                localparam integer LC = c % 8;      // columna dentro de la matriz
                localparam integer M  = c / 8;      // número de matriz
                localparam         PRUEBA = ((f == 0) && (LC <= M + 1)) || ((LC == 0) && (f <= 2));

                assign img[f*ANCHO + c] = modo_prueba ? (PRUEBA != 0) : juego;
            end
        end
    endgenerate

    // ------------------------------------------------------------------
    // (b) Mapeo a registros del MAX7219
    //     Para cada módulo m, dígito d (0..7) y bit b (0..7) buscamos qué
    //     pixel le corresponde. Por defecto (todo en 0): el dígito d es la
    //     fila d y el bit 7 es la columna más a la izquierda del módulo.
    // ------------------------------------------------------------------
    genvar m, d, b;
    generate
        for (m = 0; m < N_MOD; m = m + 1) begin : g_mod
            for (d = 0; d < 8; d = d + 1) begin : g_dig
                for (b = 0; b < 8; b = b + 1) begin : g_bit
                    localparam integer DD = (INV_DIGITOS != 0) ? (7 - d) : d;
                    localparam integer BB = (INV_BITS    != 0) ? b : (7 - b);
                    localparam integer FILA = (TRANSPONER != 0) ? BB : DD;
                    localparam integer COLM = (TRANSPONER != 0) ? DD : BB;
                    assign bytes[(m*8 + d)*8 + b] = img[FILA*ANCHO + m*8 + COLM];
                end
            end
        end
    endgenerate

endmodule
