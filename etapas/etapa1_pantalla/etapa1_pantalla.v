// ============================================================================
//  etapa1_pantalla.v  -  Etapa 1 del paso a paso: que la pantalla funcione
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
//  Tarjeta: A-C4E6E10 (EP4CE10E22C8N) + módulo MAX7219 x4
// ----------------------------------------------------------------------------
//  Antes de meternos con paletas, pelota y reglas, queremos estar seguros de
//  que sabemos manejar la pantalla. Esta etapa hace solo eso:
//
//    - Un punto recorre toda la pantalla de 8 x 32, de izquierda a derecha y
//      fila por fila, dando un paso cada PASO_MS milisegundos.
//    - Con el DIP SW2 en ON se ve el patrón de calibración (para revisar que
//      las cuatro matrices estén bien orientadas y en orden).
//    - Con K3 (RESET) el punto vuelve a la esquina de arriba a la izquierda.
//    - El LED D3 de la tarjeta cambia en cada paso (un "latido" para saber
//      que la FPGA está viva aunque la pantalla no prenda).
//
//  Estructura (es la parte azul, E1, de la Figura 1):
//
//    CLK_SYS -> generador_ticks -> tick_paso -> contador de posición (8 bits)
//                                                   | X[4:0], Y[2:0]
//                                                   v
//                                    imagen_punto (decodificadores + AND)
//                                                   | bytes[255:0]
//                                                   v
//                                    max7219_tx (FSM serial) -> DIN, CLK_LED, LOAD
//
//  Reutilizamos generador_ticks.v, antirrebote.v y max7219_tx.v de la
//  carpeta rtl/, que son los mismos que va a usar el juego completo. Así, lo
//  que probemos aquí ya queda probado para el final.
// ============================================================================

`timescale 1ns / 1ps

module etapa1_pantalla #(
    parameter integer CLK_HZ         = 50_000_000,
    parameter integer PASO_MS        = 60,    // 256 pasos x 60 ms = 15 s por vuelta completa
    parameter integer DIV_CLK_LED    = 25,    // 50 MHz / (2 x 25) = 1 MHz hacia los MAX7219
    parameter integer N_MUESTRAS     = 8,
    parameter         MODULO_CERCANO = 0,
    parameter         INV_BITS       = 0,
    parameter         INV_DIGITOS    = 0,
    parameter         SW_ACTIVO_BAJO = 1,
    parameter         LED_ACTIVO_BAJO = 1
)(
    input  wire CLK_SYS,
    input  wire RESET_PIN,     // K3, activo en bajo
    input  wire SW_PRUEBA,     // DIP SW2
    output wire DIN,
    output wire CLK_LED,
    output wire LOAD,
    output wire LED_LATIDO     // D3
);

    // ------------------------------------------------------------------
    // Reinicio de encendido: 255 ciclos con todo quieto
    // ------------------------------------------------------------------
    reg [7:0] por_cuenta = 8'd0;
    wire      por = (por_cuenta != 8'hFF);
    always @(posedge CLK_SYS) if (por) por_cuenta <= por_cuenta + 8'd1;

    // ------------------------------------------------------------------
    // Bases de tiempo. Usamos el mismo generador del juego, con el nivel 0
    // fijo: su "tick_bola" aquí es el paso del punto.
    // ------------------------------------------------------------------
    wire tick_1ms, tick_paso;

    generador_ticks #(
        .CLK_HZ(CLK_HZ),
        .T_BOLA_0_MS(PASO_MS), .T_BOLA_1_MS(PASO_MS), .T_BOLA_2_MS(PASO_MS), .T_BOLA_3_MS(PASO_MS)
    ) u_ticks (
        .clk(CLK_SYS), .rst(por), .nivel(2'd0), .sincronizar(1'b0),
        .tick_1ms(tick_1ms), .tick_bola(tick_paso), .parpadeo()
    );

    // ------------------------------------------------------------------
    // RESET y DIP. El pulsador lleva antirrebote; el DIP no lo necesita
    // porque no lo vamos a estar moviendo rápido, basta sincronizarlo.
    // ------------------------------------------------------------------
    wire reset_btn;
    antirrebote #(.N_MUESTRAS(N_MUESTRAS), .ACTIVO_BAJO(1)) u_ar_reset (
        .clk(CLK_SYS), .rst(por), .muestrear(tick_1ms),
        .entrada(RESET_PIN), .salida(reset_btn), .flanco_subida()
    );
    wire rst = por | reset_btn;

    reg sw_s1 = 1'b0, sw_s2 = 1'b0;
    always @(posedge CLK_SYS) begin
        sw_s1 <= SW_PRUEBA;
        sw_s2 <= sw_s1;
    end
    wire modo_prueba = (SW_ACTIVO_BAJO != 0) ? ~sw_s2 : sw_s2;

    // ------------------------------------------------------------------
    // Contador de posición de 8 bits: pos = {Y[2:0], X[4:0]}
    // Al sumarle 1, X avanza; cuando X pasa de 31 a 0, el acarreo sube a Y.
    // O sea, el recorrido fila por fila sale "gratis" de un contador normal.
    // ------------------------------------------------------------------
    reg  [7:0] pos;
    reg        latido;

    always @(posedge CLK_SYS) begin
        if (rst) begin
            pos    <= 8'd0;
            latido <= 1'b0;
        end else if (tick_paso) begin
            pos    <= pos + 8'd1;
            latido <= ~latido;
        end
    end

    wire [4:0] x = pos[4:0];
    wire [2:0] y = pos[7:5];

    // ------------------------------------------------------------------
    // Imagen y transmisor
    // ------------------------------------------------------------------
    wire [255:0] bytes;

    imagen_punto #(.INV_BITS(INV_BITS), .INV_DIGITOS(INV_DIGITOS)) u_imagen (
        .x(x), .y(y), .modo_prueba(modo_prueba), .bytes(bytes)
    );

    max7219_tx #(
        .DIV_CLK(DIV_CLK_LED), .N_CHIPS(4), .MODULO_CERCANO(MODULO_CERCANO)
    ) u_tx (
        .clk(CLK_SYS), .rst(por), .bytes(bytes),
        .din(DIN), .clk_led(CLK_LED), .load(LOAD),
        .trama_fin(), .config_fin()
    );

    assign LED_LATIDO = (LED_ACTIVO_BAJO != 0) ? ~latido : latido;

endmodule
