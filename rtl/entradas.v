// ============================================================================
//  entradas.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Bloque de acondicionamiento de entradas (requisitos R01 y R09).
//
//  Pensamos este módulo como la "frontera" entre el mundo físico y el motor
//  del juego. El motor solo ve cuatro órdenes limpias (subir/bajar de cada
//  jugador), un pulso de START, un nivel de RESET y dos banderas de enlace.
//  Así podemos cambiar el tipo de control (botones cableados, HT12E/HT12D,
//  otro receptor) sin tocar nada de la lógica del Pong.
//
//  Sobre la seguridad del enlace RF: el HT12D deja sus salidas de datos
//  enclavadas con el último valor recibido cuando se pierde la señal. Si no
//  hiciéramos nada, una paleta podría quedar subiendo para siempre. Por eso
//  multiplicamos (AND) cada orden por la señal VT del receptor correspondiente:
//  sin transmisión válida, la orden efectiva es "no moverse".
//
//  Tabla de validez (por jugador):
//      enlace | U_rx D_rx | subir bajar
//        0    |  x    x   |   0     0      <- sin enlace nunca hay movimiento
//        1    |  U    D   |   U     D      <- el conflicto U=D=1 se resuelve en paleta.v
// ============================================================================

`timescale 1ns / 1ps

module entradas #(
    parameter integer N_MUESTRAS      = 8,
    parameter         CTRL_ACTIVO_BAJO = 0,  // polaridad de las 4 órdenes de juego
    parameter         BOTON_ACTIVO_BAJO = 1, // START y RESET de la tarjeta (pulsadores a tierra)
    parameter         VT_ACTIVO_BAJO   = 0,  // VT del HT12D es activa en alto
    parameter         USAR_VT          = 1   // 0 = controles cableados, se ignora VT
)(
    input  wire clk,
    input  wire rst,          // solo el reinicio de encendido (POR)
    input  wire tick_1ms,

    // Pines crudos
    input  wire j1_up_pin,
    input  wire j1_down_pin,
    input  wire j2_up_pin,
    input  wire j2_down_pin,
    input  wire j1_vt_pin,
    input  wire j2_vt_pin,
    input  wire start_pin,
    input  wire reset_pin,

    // Señales limpias hacia el juego
    output wire j1_subir,
    output wire j1_bajar,
    output wire j2_subir,
    output wire j2_bajar,
    output wire enlace_j1,
    output wire enlace_j2,
    output wire start_pulso,
    output wire reset_juego
);

    wire u1, d1, u2, d2, vt1, vt2, st, rs;

    // Una instancia de antirrebote por cada línea. Preferimos repetir la
    // instancia y no meter un vector para que en el RTL Viewer de Quartus
    // se vea clarito qué señal es cuál.
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(CTRL_ACTIVO_BAJO)) ar_j1u
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j1_up_pin),   .salida(u1), .flanco_subida());
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(CTRL_ACTIVO_BAJO)) ar_j1d
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j1_down_pin), .salida(d1), .flanco_subida());
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(CTRL_ACTIVO_BAJO)) ar_j2u
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j2_up_pin),   .salida(u2), .flanco_subida());
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(CTRL_ACTIVO_BAJO)) ar_j2d
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j2_down_pin), .salida(d2), .flanco_subida());

    // Para VT también filtramos: un hueco cortito en la transmisión no
    // debería pausar la partida, pero si el enlace se cae de verdad, sí.
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(VT_ACTIVO_BAJO)) ar_vt1
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j1_vt_pin), .salida(vt1), .flanco_subida());
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(VT_ACTIVO_BAJO)) ar_vt2
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(j2_vt_pin), .salida(vt2), .flanco_subida());

    // De START solo nos interesa el instante en que se presiona
    wire st_flanco;
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(BOTON_ACTIVO_BAJO)) ar_start
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(start_pin), .salida(st), .flanco_subida(st_flanco));

    // RESET lo usamos por nivel: mientras esté presionado el juego queda quieto
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(BOTON_ACTIVO_BAJO)) ar_reset
        (.clk(clk), .rst(rst), .muestrear(tick_1ms), .entrada(reset_pin), .salida(rs), .flanco_subida());

    // Si estamos probando con botones cableados no hay VT, así que forzamos
    // el enlace a 1 desde aquí y el resto del diseño ni se entera.
    assign enlace_j1 = (USAR_VT != 0) ? vt1 : 1'b1;
    assign enlace_j2 = (USAR_VT != 0) ? vt2 : 1'b1;

    assign j1_subir = u1 & enlace_j1;
    assign j1_bajar = d1 & enlace_j1;
    assign j2_subir = u2 & enlace_j2;
    assign j2_bajar = d2 & enlace_j2;

    assign start_pulso = st_flanco;
    assign reset_juego = rs;

endmodule
