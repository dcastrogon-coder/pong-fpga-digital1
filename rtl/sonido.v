// ============================================================================
//  sonido.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Pitidos del juego en el buzzer de la tarjeta (pin 141). En la propuesta
//  dejamos por fuera los "efectos sonoros complejos"; esto no lo es: son
//  tonos cuadrados fijos, uno por evento, y se pueden apagar con un
//  interruptor del DIP. Pero le da mucha vida al Pong.
//
//  Cada sonido es una onda cuadrada de frecuencia f durante d milisegundos.
//  El medio periodo en ciclos de reloj es CLK_HZ / (2 f).
//
//   evento          | prioridad | tono(s)                 | duración
//   ----------------+-----------+-------------------------+-----------
//   fin de partida  |     4     | 523, 659, 784, 1047 Hz  | 4 x 120 ms
//   gol             |     3     | 220 Hz                  | 400 ms
//   rebote paleta   |     2     | 880 Hz                  | 50 ms
//   rebote pared    |     1     | 1760 Hz                 | 25 ms
//
//  Si llega un evento mientras suena otro, lo reemplaza solo si tiene igual
//  o mayor prioridad. Así el pitido de un rebote no tapa el sonido del gol.
//
//  No sabemos todavía si el buzzer de la tarjeta es activo o pasivo. Con una
//  onda cuadrada suenan los dos (el pasivo da el tono exacto; el activo suena
//  más "raspado"). La polaridad depende del transistor que lo maneja, por
//  eso es un parámetro.
// ============================================================================

`timescale 1ns / 1ps

module sonido #(
    parameter integer CLK_HZ           = 50_000_000,
    parameter         BUZZER_ACTIVO_BAJO = 1
)(
    input  wire clk,
    input  wire rst,
    input  wire tick_1ms,
    input  wire habilitar,       // interruptor del DIP
    input  wire ev_pared,
    input  wire ev_paleta,
    input  wire ev_gol,
    input  wire ev_fin,
    output wire buzzer,
    output wire sonando          // para las pruebas
);

    // Medios periodos en ciclos de reloj
    localparam integer MP_PARED  = CLK_HZ / (2 * 1760);
    localparam integer MP_PALETA = CLK_HZ / (2 * 880);
    localparam integer MP_GOL    = CLK_HZ / (2 * 220);
    localparam integer MP_DO     = CLK_HZ / (2 * 523);
    localparam integer MP_MI     = CLK_HZ / (2 * 659);
    localparam integer MP_SOL    = CLK_HZ / (2 * 784);
    localparam integer MP_DO2    = CLK_HZ / (2 * 1047);

    reg [2:0]  prioridad;       // 0 = silencio
    reg [1:0]  nota;            // posición en la melodía de fin
    reg [15:0] restante_ms;     // milisegundos que le quedan a la nota actual
    reg [31:0] medio_periodo;
    reg [31:0] cuenta;
    reg        onda;

    // Medio periodo de cada nota de la melodía final
    function [31:0] mp_melodia;
        input [1:0] n;
        begin
            case (n)
                2'd0: mp_melodia = MP_DO;
                2'd1: mp_melodia = MP_MI;
                2'd2: mp_melodia = MP_SOL;
                default: mp_melodia = MP_DO2;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            prioridad     <= 3'd0;
            nota          <= 2'd0;
            restante_ms   <= 16'd0;
            medio_periodo <= 32'd1;
            cuenta        <= 32'd0;
            onda          <= 1'b0;
        end else begin
            // --- Arranque de un sonido nuevo (respetando prioridades) ---
            if (ev_fin && prioridad <= 3'd4) begin
                prioridad <= 3'd4; nota <= 2'd0; restante_ms <= 16'd120; medio_periodo <= MP_DO;
                cuenta <= 32'd0;
            end else if (ev_gol && prioridad <= 3'd3) begin
                prioridad <= 3'd3; restante_ms <= 16'd400; medio_periodo <= MP_GOL;
                cuenta <= 32'd0;
            end else if (ev_paleta && prioridad <= 3'd2) begin
                prioridad <= 3'd2; restante_ms <= 16'd50; medio_periodo <= MP_PALETA;
                cuenta <= 32'd0;
            end else if (ev_pared && prioridad <= 3'd1) begin
                prioridad <= 3'd1; restante_ms <= 16'd25; medio_periodo <= MP_PARED;
                cuenta <= 32'd0;
            end else if (prioridad != 3'd0) begin
                // --- Generación de la onda ---
                if (cuenta >= medio_periodo - 1) begin
                    cuenta <= 32'd0;
                    onda   <= ~onda;
                end else begin
                    cuenta <= cuenta + 32'd1;
                end
                // --- Duración ---
                if (tick_1ms) begin
                    if (restante_ms <= 16'd1) begin
                        if (prioridad == 3'd4 && nota != 2'd3) begin
                            // siguiente nota de la melodía
                            nota          <= nota + 2'd1;
                            restante_ms   <= 16'd120;
                            medio_periodo <= mp_melodia(nota + 2'd1);
                        end else begin
                            prioridad <= 3'd0;   // se acabó
                            onda      <= 1'b0;
                        end
                    end else begin
                        restante_ms <= restante_ms - 16'd1;
                    end
                end
            end
        end
    end

    assign sonando = (prioridad != 3'd0);
    wire   salida  = habilitar & sonando & onda;
    assign buzzer  = (BUZZER_ACTIVO_BAJO != 0) ? ~salida : salida;

endmodule
