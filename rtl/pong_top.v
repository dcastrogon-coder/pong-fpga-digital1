// ============================================================================
//  pong_top.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
//  FPGA:    Intel/Altera Cyclone IV E EP4CE10E22C8N - Quartus II - Verilog
//  Tarjeta: A-C4E6E10 (oscilador de 50 MHz, display de 8 dígitos, buzzer,
//           DIP de 8 interruptores, 12 LEDs, pulsadores K1-K5)
// ----------------------------------------------------------------------------
//  Módulo superior. Aquí no hay lógica del juego: solo conectamos los bloques
//  siguiendo la arquitectura de la Figura 1 de nuestra guía metodológica:
//
//   pines RF/botones -> entradas -> paletas, pelota(+colisiones), puntaje,
//                                    control_juego
//                                         |
//                     imagen 8xANCHO <----+----> display_multiplexado (8 dígitos)
//                         |               |
//                    max7219_tx           +----> sonido (buzzer)
//                         |
//                DIN / CLK_LED / LOAD -> 4 x MAX7219 (módulo x4)
//
//  Todos los parámetros de tiempo se pueden sobrescribir desde el testbench.
//  Eso fue clave para simular: con CLK_HZ = 50 MHz una partida completa son
//  miles de millones de ciclos, así que en simulación bajamos CLK_HZ y
//  dejamos todo lo demás expresado en milisegundos.
// ============================================================================

`timescale 1ns / 1ps

module pong_top #(
    // Ancho de la cancha en columnas. 32 = módulo "MAX7219 x4" (cuatro
    // matrices 8x8 en una sola placa, que es el que compramos). 16 = dos
    // matrices sueltas, como en la propuesta original. Solo se admiten 16 y 32.
    parameter integer ANCHO           = 32,
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
    // Display de 8 dígitos de la tarjeta: ánodo común con transistores PNP,
    // así que suponemos segmentos y dígitos activos en bajo.
    parameter         SEG_ACTIVO_BAJO   = 1,
    parameter         DIG_ACTIVO_BAJO   = 1,
    parameter         LED_ACTIVO_BAJO   = 1,
    parameter         BUZZER_ACTIVO_BAJO = 1,
    parameter         SW_ACTIVO_BAJO    = 1,   // los DIP suelen leer 0 en la posición ON
    parameter         TRANSPONER        = 0,
    parameter         INV_BITS          = 0,
    parameter         INV_DIGITOS       = 0,
    parameter         MODULO_CERCANO    = 0,
    // 1 = mostrar siempre el patrón de calibración. Con 0 el patrón igual
    // aparece mientras se mantenga presionado RESET (ver imagen.v).
    parameter         PATRON_PRUEBA     = 0
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
    input  wire       SW_SONIDO,   // DIP 1: sonido encendido
    input  wire       SW_PRUEBA,   // DIP 2: patrón de calibración en la matriz

    output wire       DIN,
    output wire       CLK_LED,
    output wire       LOAD,
    output wire [7:0] SEG,         // segmentos del display de la tarjeta {H,G,F,E,D,C,B,A}
    output wire [7:0] DIG,         // habilitación de dígitos BIT7..BIT0 (BIT0 = derecha)
    output wire       BUZZER,
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

    // Con 32 columnas la pelota tiene que recorrer el doble, así que la
    // hacemos más rápida para que cruzar la cancha tome un tiempo parecido
    // (unos 5 s al empezar la jugada en vez de casi 8 s).
    localparam integer XB      = (ANCHO > 16) ? 5 : 4;
    localparam integer N_CHIPS = ANCHO / 8;
    localparam integer T_B0 = (ANCHO > 16) ? 170 : 260;
    localparam integer T_B1 = (ANCHO > 16) ? 130 : 200;
    localparam integer T_B2 = (ANCHO > 16) ? 100 : 150;
    localparam integer T_B3 = (ANCHO > 16) ?  75 : 110;

    generador_ticks #(
        .CLK_HZ(CLK_HZ),
        .T_BOLA_0_MS(T_B0), .T_BOLA_1_MS(T_B1), .T_BOLA_2_MS(T_B2), .T_BOLA_3_MS(T_B3)
    ) u_ticks (
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
    wire [XB-1:0] bx;
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

    pelota #(.LP(LP), .ANCHO(ANCHO)) u_pelota (
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

    wire [8*ANCHO-1:0] img, bytes;

    // Interruptores del DIP: son niveles estáticos, así que basta con
    // sincronizarlos (no necesitan antirrebote).
    reg [1:0] sw_s1 = 2'b00, sw_s2 = 2'b00;
    always @(posedge CLK_SYS) begin
        sw_s1 <= {SW_PRUEBA, SW_SONIDO};
        sw_s2 <= sw_s1;
    end
    wire sw_sonido = (SW_ACTIVO_BAJO != 0) ? ~sw_s2[0] : sw_s2[0];
    wire sw_prueba = (SW_ACTIVO_BAJO != 0) ? ~sw_s2[1] : sw_s2[1];

    // Patrón de calibración: fijo por parámetro, con el DIP 2 o mientras
    // RESET esté presionado. Así, en el laboratorio, basta con sostener RESET
    // para ver si alguna matriz quedó girada o en otro orden.
    wire modo_prueba = (PATRON_PRUEBA != 0) | sw_prueba | reset_juego;

    imagen #(
        .LP(LP), .ANCHO(ANCHO),
        .TRANSPONER(TRANSPONER), .INV_BITS(INV_BITS), .INV_DIGITOS(INV_DIGITOS)
    ) u_imagen (
        .x(bx), .y(by), .yp1(yp1), .yp2(yp2),
        .mostrar_pelota(mostrar_pelota), .modo_fin(en_fin),
        .ganador(ganador), .parpadeo(parpadeo), .modo_prueba(modo_prueba),
        .img(img), .bytes(bytes)
    );

    max7219_tx #(
        .DIV_CLK(DIV_CLK_LED), .N_CHIPS(N_CHIPS), .MODULO_CERCANO(MODULO_CERCANO)
    ) u_max7219 (
        .clk(CLK_SYS), .rst(por),          // la pantalla no se reinicia con RESET, solo al encender
        .bytes(bytes),
        .din(DIN), .clk_led(CLK_LED), .load(LOAD),
        .trama_fin(), .config_fin()
    );

    // ------------------------------------------------------------------
    // Marcador en el display de 8 dígitos de la tarjeta
    //
    //    BIT7  BIT6  BIT5 BIT4 BIT3 BIT2  BIT1  BIT0
    //    [P1]  [  ]  [ mensaje de 4 letras ] [  ]  [P2]
    //
    //   ESPERA "HOLA"   JUEGO "-n1-" (nivel de velocidad 1 a 4)
    //   PUNTO  "-GOL"   PAUSA "PAUS"   FIN "GAnA" y titila el puntaje del ganador
    //   Con el patrón de calibración se encienden todos los segmentos ("8.8.8.8.")
    //   para revisar de paso que no haya ninguno dañado.
    // ------------------------------------------------------------------
    localparam [2:0] PUNTO_E = 3'b010;
    localparam [4:0] C_H = 5'd10, C_L = 5'd11, C_A = 5'd12, C_P = 5'd13, C_U = 5'd14,
                     C_G = 5'd15, C_N = 5'd16, C_GUION = 5'd17, C_VACIO = 5'd18;

    // Mensaje de 4 caracteres {car5, car4, car3, car2}, de izquierda a derecha
    wire [19:0] mensaje =
        (estado == ESPERA)  ? {C_H, 5'd0, C_L, C_A} :                          // HOLA
        (estado == JUEGO)   ? {C_GUION, C_N, {3'b000, nivel} + 5'd1, C_GUION} : // -n1-
        (estado == PUNTO_E) ? {C_GUION, C_G, 5'd0, C_L} :                      // -GOL
        (estado == PAUSA)   ? {C_P, C_A, C_U, 5'd5} :                          // PAUS
        (estado == FIN)     ? {C_G, C_A, C_N, C_A} :                           // GAnA
                              {4{C_GUION}};

    wire [39:0] caracteres = modo_prueba ? {8{5'd8}} :
                             {{1'b0, p1}, C_VACIO, mensaje, C_VACIO, {1'b0, p2}};
    wire [7:0]  apagar_dig = modo_prueba ? 8'h00 :
                             {en_fin & ~ganador & ~parpadeo, 6'b000000, en_fin & ganador & ~parpadeo};
    wire [7:0]  puntos     = modo_prueba ? 8'hFF : 8'h00;

    display_multiplexado #(
        .CLK_HZ(CLK_HZ), .SEG_ACTIVO_BAJO(SEG_ACTIVO_BAJO), .DIG_ACTIVO_BAJO(DIG_ACTIVO_BAJO)
    ) u_display (
        .clk(CLK_SYS), .rst(por),
        .caracteres(caracteres), .apagar(apagar_dig), .punto(puntos),
        .seg(SEG), .dig(DIG)
    );

    // ------------------------------------------------------------------
    // Sonido
    // ------------------------------------------------------------------
    reg en_fin_ant = 1'b0;
    always @(posedge CLK_SYS) en_fin_ant <= en_fin;

    sonido #(.CLK_HZ(CLK_HZ), .BUZZER_ACTIVO_BAJO(BUZZER_ACTIVO_BAJO)) u_sonido (
        .clk(CLK_SYS), .rst(rst), .tick_1ms(tick_1ms), .habilitar(sw_sonido),
        .ev_pared(rebote_pared), .ev_paleta(rebote_paleta),
        .ev_gol(contar & (gol_j1 | gol_j2)), .ev_fin(en_fin & ~en_fin_ant),
        .buzzer(BUZZER), .sonando()
    );

    // LEDs de estado: [0] jugando, [1] pausa, [2] enlace J1, [3] enlace J2
    wire [3:0] led_pos = {enlace_j2, enlace_j1, (estado == PAUSA), (estado == JUEGO)};
    assign LED = (LED_ACTIVO_BAJO != 0) ? ~led_pos : led_pos;

endmodule
