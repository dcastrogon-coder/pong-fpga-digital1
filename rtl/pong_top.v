// ============================================================================
//  pong_top.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
//  FPGA:    Intel/Altera Cyclone IV E EP4CE10E22C8N - Quartus II - Verilog
// ----------------------------------------------------------------------------
//  Módulo superior. Aquí no hay lógica del juego: solo conectamos los bloques
//  siguiendo la arquitectura de la Figura 1 de nuestra guía metodológica:
//
//   pines RF/botones -> entradas -> paletas, pelota(+colisiones), puntaje,
//                                    control_juego
//                                         |
//                     imagen 8x16 <-------+-------> siete_segmentos (x2)
//                         |
//                    max7219_tx -> DIN / CLK_LED / LOAD -> 2 x MAX7219
//
//  Todos los parámetros de tiempo se pueden sobrescribir desde el testbench.
//  Eso fue clave para simular: con CLK_HZ = 50 MHz una partida completa son
//  miles de millones de ciclos, así que en simulación bajamos CLK_HZ y
//  dejamos todo lo demás expresado en milisegundos.
// ============================================================================

`timescale 1ns / 1ps

module pong_top #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer N_MUESTRAS      = 8,
    parameter integer DIV_CLK_LED     = 25,
    parameter integer PAUSA_PUNTO_MS  = 1000,
    parameter integer PUNTOS_VICTORIA = 9,
    parameter integer LP              = 3,
    // Polaridades y opciones de hardware (ver docs/decisiones.md)
    parameter         CTRL_ACTIVO_BAJO  = 0,
    parameter         BOTON_ACTIVO_BAJO = 1,
    parameter         USAR_VT           = 1,
    // 1: si se pierde el enlace de algún jugador el juego entra en PAUSA.
    //    Sirve cuando los transmisores HT12E transmiten todo el tiempo (TE a
    //    tierra), porque ahí VT = 0 de verdad significa "se perdió la señal".
    // 0: para transmisores que solo emiten mientras se presiona un botón; en
    //    ese caso VT = 0 es lo normal en reposo y no queremos pausar.
    //    En ambos casos las órdenes se siguen validando con VT.
    parameter         PAUSAR_SIN_ENLACE = 1,
    parameter         SEG_ACTIVO_BAJO   = 1,
    parameter         LED_ACTIVO_BAJO   = 1,
    parameter         TRANSPONER        = 0,
    parameter         INV_BITS          = 0,
    parameter         INV_DIGITOS       = 0,
    parameter         MODULO_CERCANO    = 0
)(
    input  wire       CLK_SYS,
    input  wire       RESET_PIN,
    input  wire       START_PIN,
    input  wire       J1_UP,
    input  wire       J1_DOWN,
    input  wire       J2_UP,
    input  wire       J2_DOWN,
    input  wire       J1_VT,
    input  wire       J2_VT,

    output wire       DIN,
    output wire       CLK_LED,
    output wire       LOAD,
    output wire [6:0] SEG_J1,      // {g,f,e,d,c,b,a}
    output wire [6:0] SEG_J2,
    output wire [3:0] LED          // indicadores de la tarjeta
);

    // ------------------------------------------------------------------
    // Reinicio de encendido (POR). Las FPGA Cyclone arrancan con los
    // registros en el valor que les demos aquí, así que este contador
    // empieza en 0 y mantiene el reinicio unos cientos de ciclos.
    // ------------------------------------------------------------------
    reg [7:0] por_cuenta = 8'd0;
    wire      por = (por_cuenta != 8'hFF);

    always @(posedge CLK_SYS) begin
        if (por) por_cuenta <= por_cuenta + 8'd1;
    end

    // ------------------------------------------------------------------
    // Bases de tiempo
    // ------------------------------------------------------------------
    wire       tick_1ms, tick_bola, parpadeo;
    wire [1:0] nivel;
    wire       mover_pelota;
    wire       rst;            // reinicio general del juego (POR o botón RESET)

    generador_ticks #(.CLK_HZ(CLK_HZ)) u_ticks (
        .clk(CLK_SYS), .rst(por),
        .nivel(nivel),
        .sincronizar(~mover_pelota | rst),   // fuera de JUEGO el contador espera en cero
        .tick_1ms(tick_1ms), .tick_bola(tick_bola), .parpadeo(parpadeo)
    );

    // ------------------------------------------------------------------
    // Entradas
    // ------------------------------------------------------------------
    wire j1_subir, j1_bajar, j2_subir, j2_bajar;
    wire enlace_j1, enlace_j2, start_pulso, reset_juego;

    entradas #(
        .N_MUESTRAS(N_MUESTRAS),
        .CTRL_ACTIVO_BAJO(CTRL_ACTIVO_BAJO),
        .BOTON_ACTIVO_BAJO(BOTON_ACTIVO_BAJO),
        .USAR_VT(USAR_VT)
    ) u_entradas (
        .clk(CLK_SYS), .rst(por), .tick_1ms(tick_1ms),
        .j1_up_pin(J1_UP), .j1_down_pin(J1_DOWN),
        .j2_up_pin(J2_UP), .j2_down_pin(J2_DOWN),
        .j1_vt_pin(J1_VT), .j2_vt_pin(J2_VT),
        .start_pin(START_PIN), .reset_pin(RESET_PIN),
        .j1_subir(j1_subir), .j1_bajar(j1_bajar),
        .j2_subir(j2_subir), .j2_bajar(j2_bajar),
        .enlace_j1(enlace_j1), .enlace_j2(enlace_j2),
        .start_pulso(start_pulso), .reset_juego(reset_juego)
    );

    assign rst = por | reset_juego;

    // ------------------------------------------------------------------
    // Motor del Pong
    // ------------------------------------------------------------------
    wire [2:0] yp1, yp2;
    wire [3:0] bx;
    wire [2:0] by;
    wire       bdx, bdy;
    wire       gol_j1, gol_j2, rebote_paleta, rebote_pared;
    wire [3:0] p1, p2;
    wire       gana_j1, gana_j2;
    wire [2:0] estado;
    wire       contar, paletas_hab, saque, saque_dx, saque_dy, limpiar, ganador;
    wire [2:0] saque_y;

    paleta #(.LP(LP)) u_paleta_j1 (
        .clk(CLK_SYS), .rst(rst), .tick_1ms(tick_1ms), .habilitar(paletas_hab),
        .subir(j1_subir), .bajar(j1_bajar), .yp(yp1)
    );

    paleta #(.LP(LP)) u_paleta_j2 (
        .clk(CLK_SYS), .rst(rst), .tick_1ms(tick_1ms), .habilitar(paletas_hab),
        .subir(j2_subir), .bajar(j2_bajar), .yp(yp2)
    );

    pelota #(.LP(LP)) u_pelota (
        .clk(CLK_SYS), .rst(rst),
        .tick(tick_bola), .habilitar(mover_pelota),
        .saque(saque), .saque_dx(saque_dx), .saque_dy(saque_dy), .saque_y(saque_y),
        .yp1(yp1), .yp2(yp2),
        .x(bx), .y(by), .dx(bdx), .dy(bdy),
        .gol_j1(gol_j1), .gol_j2(gol_j2),
        .rebote_paleta(rebote_paleta), .rebote_pared(rebote_pared)
    );

    puntaje #(.PUNTOS_VICTORIA(PUNTOS_VICTORIA)) u_puntaje (
        .clk(CLK_SYS), .rst(rst), .limpiar(limpiar), .contar(contar),
        .gol_j1(gol_j1), .gol_j2(gol_j2),
        .p1(p1), .p2(p2), .gana_j1(gana_j1), .gana_j2(gana_j2)
    );

    wire enlace_ok = (PAUSAR_SIN_ENLACE != 0) ? (enlace_j1 & enlace_j2) : 1'b1;

    control_juego #(.PAUSA_PUNTO_MS(PAUSA_PUNTO_MS)) u_control (
        .clk(CLK_SYS), .rst(rst), .tick_1ms(tick_1ms),
        .start(start_pulso), .enlace_ok(enlace_ok),
        .gol_j1(gol_j1), .gol_j2(gol_j2),
        .gana_j1(gana_j1), .gana_j2(gana_j2),
        .rebote_paleta(rebote_paleta),
        .estado(estado), .mover_pelota(mover_pelota), .contar(contar),
        .paletas_hab(paletas_hab),
        .saque(saque), .saque_dx(saque_dx), .saque_dy(saque_dy), .saque_y(saque_y),
        .limpiar(limpiar), .nivel(nivel), .ganador(ganador)
    );

    // ------------------------------------------------------------------
    // Visualización
    // ------------------------------------------------------------------
    localparam [2:0] ESPERA = 3'b000, JUEGO = 3'b001, PAUSA = 3'b011, FIN = 3'b100;

    wire en_fin = (estado == FIN);
    // En ESPERA la pelota titila para invitar a presionar START
    wire mostrar_pelota = (estado != ESPERA) | parpadeo;

    wire [127:0] img, bytes;

    imagen #(
        .LP(LP), .TRANSPONER(TRANSPONER), .INV_BITS(INV_BITS), .INV_DIGITOS(INV_DIGITOS)
    ) u_imagen (
        .x(bx), .y(by), .yp1(yp1), .yp2(yp2),
        .mostrar_pelota(mostrar_pelota), .modo_fin(en_fin),
        .ganador(ganador), .parpadeo(parpadeo),
        .img(img), .bytes(bytes)
    );

    max7219_tx #(
        .DIV_CLK(DIV_CLK_LED), .MODULO_CERCANO(MODULO_CERCANO)
    ) u_max7219 (
        .clk(CLK_SYS), .rst(por),          // la pantalla no se reinicia con RESET, solo al encender
        .bytes(bytes),
        .din(DIN), .clk_led(CLK_LED), .load(LOAD),
        .trama_fin(), .config_fin()
    );

    // Marcador: al final de la partida titila el display del ganador
    siete_segmentos #(.ACTIVO_BAJO(SEG_ACTIVO_BAJO)) u_seg_j1 (
        .valor(p1), .apagar(en_fin & ~ganador & ~parpadeo), .seg(SEG_J1)
    );

    siete_segmentos #(.ACTIVO_BAJO(SEG_ACTIVO_BAJO)) u_seg_j2 (
        .valor(p2), .apagar(en_fin & ganador & ~parpadeo), .seg(SEG_J2)
    );

    // LEDs de estado: [0] jugando, [1] pausa, [2] enlace J1, [3] enlace J2
    wire [3:0] led_pos = {enlace_j2, enlace_j1, (estado == PAUSA), (estado == JUEGO)};
    assign LED = (LED_ACTIVO_BAJO != 0) ? ~led_pos : led_pos;

endmodule
