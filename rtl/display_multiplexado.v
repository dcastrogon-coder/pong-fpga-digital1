// ============================================================================
//  display_multiplexado.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Manejo del display de 8 dígitos que trae la tarjeta A-C4E6E10 (requisito
//  R06). Los ocho dígitos comparten las líneas de segmentos A..H (H es el
//  punto) y cada uno tiene su propia línea de habilitación BIT0..BIT7, a
//  través de los transistores Q50..Q57. Por eso solo podemos encender un
//  dígito a la vez: los recorremos uno por uno lo bastante rápido para que el
//  ojo los vea todos encendidos (multiplexado por división de tiempo).
//
//  Cómo lo hicimos:
//   - Cada dígito queda encendido T_DIGITO_US microsegundos (500 us por
//     defecto). Una vuelta completa son 8 x 0,5 ms = 4 ms, o sea 250 Hz:
//     muy por encima de los ~60 Hz a partir de los cuales deja de notarse
//     el parpadeo.
//   - Al cambiar de dígito apagamos todo durante T_APAGADO_US. Sin ese
//     pequeño hueco, mientras los transistores conmutan se alcanza a ver un
//     "fantasma" del número vecino.
//   - BIT0 es el dígito de la DERECHA (así lo muestra la serigrafía y la
//     prueba de fábrica "76543210").
//
//  Tabla del barrido (pos = contador de 3 bits):
//      pos | dígito activo | segmentos
//       0  | BIT0 (der.)   | car[0]
//       1  | BIT1          | car[1]
//      ... | ...           | ...
//       7  | BIT7 (izq.)   | car[7]
//
//  Polaridades: en esta tarjeta los dígitos se habilitan con transistores PNP
//  y el display es de ánodo común, así que suponemos segmentos y dígitos
//  activos en bajo. Si al probar se ve al revés, se cambia el parámetro.
// ============================================================================

`timescale 1ns / 1ps

module display_multiplexado #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer T_DIGITO_US     = 500,
    parameter integer T_APAGADO_US    = 20,
    parameter         SEG_ACTIVO_BAJO = 1,
    parameter         DIG_ACTIVO_BAJO = 1
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [39:0] caracteres,   // 8 códigos de 5 bits; car[i] = caracteres[5i +: 5], i = 0 es BIT0
    input  wire [7:0]  apagar,       // 1 = ese dígito no se muestra (para titilar)
    input  wire [7:0]  punto,        // segmento H de cada dígito
    output wire [7:0]  seg,          // {H, G, F, E, D, C, B, A}
    output wire [7:0]  dig           // BIT7..BIT0
);

    localparam integer CICLOS_DIGITO  = (CLK_HZ / 1000) * T_DIGITO_US / 1000;
    localparam integer CICLOS_APAGADO = (CLK_HZ / 1000) * T_APAGADO_US / 1000;

    reg [2:0]  pos;
    reg [31:0] cuenta;

    always @(posedge clk) begin
        if (rst) begin
            pos    <= 3'd0;
            cuenta <= 32'd0;
        end else if (cuenta >= CICLOS_DIGITO - 1) begin
            cuenta <= 32'd0;
            pos    <= pos + 3'd1;      // de 7 vuelve solo a 0
        end else begin
            cuenta <= cuenta + 32'd1;
        end
    end

    // Carácter del dígito que toca ahora
    wire [4:0] codigo_actual = caracteres[5*pos +: 5];
    wire [6:0] seg_car;

    caracter_7seg u_car (.codigo(codigo_actual), .seg(seg_car));

    // Hueco de apagado al inicio de cada turno
    wire en_hueco = (cuenta < CICLOS_APAGADO);
    wire visible  = !en_hueco && !apagar[pos];

    wire [7:0] seg_pos = visible ? {punto[pos], seg_car} : 8'h00;
    wire [7:0] dig_pos = visible ? (8'b0000_0001 << pos) : 8'h00;

    // Registramos las salidas para que lleguen a los pines sin glitches de
    // la lógica combinacional (un poco de cuidado no sobra con 16 líneas
    // conmutando a la vez).
    reg [7:0] seg_r, dig_r;
    always @(posedge clk) begin
        if (rst) begin
            seg_r <= 8'h00;
            dig_r <= 8'h00;
        end else begin
            seg_r <= seg_pos;
            dig_r <= dig_pos;
        end
    end

    assign seg = (SEG_ACTIVO_BAJO != 0) ? ~seg_r : seg_r;
    assign dig = (DIG_ACTIVO_BAJO != 0) ? ~dig_r : dig_r;

endmodule
