// ============================================================================
//  max7219_tx.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Transmisor serial para dos MAX7219 en cascada (requisito R08).
//
//  Lo que sacamos de la hoja de datos y que este módulo respeta:
//   - Cada MAX7219 recibe palabras de 16 bits: D15-D12 no importan,
//     D11-D8 son la dirección del registro y D7-D0 el dato. Se envía
//     primero el MSB (D15).
//   - DIN se lee en el flanco de SUBIDA de CLK, así que cambiamos DIN
//     cuando CLK está en bajo y le damos medio periodo para estabilizarse.
//   - Con dos chips en cascada desplazamos 32 bits antes de subir LOAD. Los
//     primeros 16 bits terminan en el chip MÁS LEJANO de la FPGA (pasan por
//     DOUT del primero) y los últimos 16 se quedan en el más cercano.
//   - El dato se enclava en el flanco de subida de LOAD, que debe llegar
//     después del último flanco de subida de CLK.
//   - CLK admite hasta 10 MHz; nosotros vamos a 1 MHz (DIV_CLK = 25 con
//     50 MHz) porque los cables a la matriz van a ser largos y con eso
//     tenemos margen de sobra. Una pantalla completa son 8 x 32 = 256
//     ciclos de CLK, unos 0,3 ms contando el LOAD: más de 3000 refrescos por
//     segundo, mucho más rápido de lo que se mueve la pelota.
//
//  Secuencia de palabras que enviamos (misma palabra a los dos chips en la
//  configuración):
//     idx 0 : 0x0F00  display test apagado
//     idx 1 : 0x0B07  scan limit = 8 dígitos (las 8 filas)
//     idx 2 : 0x0900  sin decodificación BCD (queremos LEDs sueltos)
//     idx 3 : 0x0Axx  brillo
//     idx 4 : 0x0C01  salir de shutdown, operación normal
//     idx 5..12 : dígitos 1..8 con la imagen
//  Después de idx 12 volvemos a idx 5. Cada REINIT_TRAMAS pantallas repetimos
//  la configuración: si algún chip se reinicia por ruido en la alimentación,
//  se recupera solo en unos milisegundos.
//
//  FSM del transmisor:
//     CARGA -> BAJO <-> ALTO (32 veces) -> CIERRE -> LATCH -> SEPARA -> CARGA
// ============================================================================

`timescale 1ns / 1ps

module max7219_tx #(
    parameter integer DIV_CLK        = 25,   // ciclos de CLK_SYS por medio periodo de CLK_LED
    parameter [3:0]   INTENSIDAD     = 4'h4, // brillo 0x0..0xF (con fuente USB mejor no subirlo mucho)
    parameter         MODULO_CERCANO = 0,    // qué mitad lógica está conectada directo a DIN (0 = izquierda)
    parameter integer REINIT_TRAMAS  = 256
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [127:0] bytes,        // bytes[(modulo*8 + digito)*8 +: 8]
    output reg          din,
    output reg          clk_led,
    output reg          load,
    output reg          trama_fin,    // pulso al terminar una pantalla completa (para pruebas)
    output reg          config_fin    // pulso al terminar la secuencia de configuración
);

    localparam [2:0] S_CARGA  = 3'd0,
                     S_BAJO   = 3'd1,
                     S_ALTO   = 3'd2,
                     S_CIERRE = 3'd3,
                     S_LATCH  = 3'd4,
                     S_SEPARA = 3'd5;

    localparam integer MOD_LEJANO = (MODULO_CERCANO != 0) ? 0 : 1;

    reg [2:0]   estado;
    reg [3:0]   idx;           // posición en la secuencia (0..12)
    reg [31:0]  sr;            // registro de desplazamiento de la trama
    reg [5:0]   bits;          // bits que faltan por enviar
    reg [15:0]  div;           // contador de medio periodo
    reg [15:0]  tramas;        // pantallas desde la última configuración
    reg [127:0] buffer;        // copia de la imagen tomada al inicio de cada pantalla

    // ------------------------------------------------------------------
    // Palabra de 16 bits para un chip, según la posición en la secuencia.
    // ------------------------------------------------------------------
    function [15:0] palabra;
        input [3:0]   i;
        input integer modulo;
        input [127:0] buf_img;
        reg   [2:0]   dig;
        begin
            dig = i - 4'd5;   // solo se usa cuando i >= 5
            case (i)
                4'd0: palabra = 16'h0F00;
                4'd1: palabra = 16'h0B07;
                4'd2: palabra = 16'h0900;
                // Ojo con este: en la primera versión escribimos {12'h00A, INTENSIDAD},
                // que da 0x00A4 y cae en la dirección 0x0 (no-op). El modelo del
                // MAX7219 en tb_max7219 nos mostró que el brillo nunca llegaba.
                4'd3: palabra = {8'h0A, 4'h0, INTENSIDAD};
                4'd4: palabra = 16'h0C01;
                default: palabra = {4'h0, {1'b0, dig} + 4'd1, buf_img[(modulo*8 + dig)*8 +: 8]};
            endcase
        end
    endfunction

    // Imagen que se va a usar para armar la trama actual. Cuando arrancamos
    // una pantalla nueva (idx = 5) tomamos la imagen directamente de la
    // entrada para no enviar una pantalla vieja.
    wire [127:0] img_trama = (idx == 4'd5) ? bytes : buffer;

    // Trama de 32 bits: primero la palabra del chip lejano
    wire [31:0] trama = {palabra(idx, MOD_LEJANO, img_trama),
                         palabra(idx, MODULO_CERCANO, img_trama)};

    always @(posedge clk) begin
        if (rst) begin
            estado     <= S_CARGA;
            idx        <= 4'd0;
            sr         <= 32'd0;
            bits       <= 6'd0;
            div        <= 16'd0;
            tramas     <= 16'd0;
            buffer     <= 128'd0;
            din        <= 1'b0;
            clk_led    <= 1'b0;
            load       <= 1'b0;
            trama_fin  <= 1'b0;
            config_fin <= 1'b0;
        end else begin
            trama_fin  <= 1'b0;
            config_fin <= 1'b0;

            case (estado)
                // Cargamos la trama en el registro de desplazamiento
                S_CARGA: begin
                    if (idx == 4'd5) buffer <= bytes;
                    sr      <= trama;
                    din     <= trama[31];        // el primer bit queda listo desde ya
                    bits    <= 6'd32;
                    clk_led <= 1'b0;
                    load    <= 1'b0;
                    div     <= 16'd0;
                    estado  <= S_BAJO;
                end

                // CLK en bajo: DIN ya tiene su bit, solo esperamos medio periodo.
                // En una versión anterior asignábamos DIN aquí mismo y con
                // DIV_CLK = 1 cambiaba en el MISMO flanco en que subía CLK; el
                // modelo del MAX7219 lo marcó como violación de setup en la
                // simulación de integración. Ahora DIN cambia cuando CLK baja,
                // así que siempre tiene medio periodo completo de setup.
                S_BAJO: begin
                    clk_led <= 1'b0;
                    if (div >= DIV_CLK - 1) begin
                        div     <= 16'd0;
                        clk_led <= 1'b1;          // flanco de subida: el MAX7219 lee DIN
                        estado  <= S_ALTO;
                    end else begin
                        div <= div + 16'd1;
                    end
                end

                // CLK en alto: medio periodo y pasamos al siguiente bit
                S_ALTO: begin
                    if (div >= DIV_CLK - 1) begin
                        div     <= 16'd0;
                        clk_led <= 1'b0;
                        sr      <= {sr[30:0], 1'b0};
                        din     <= sr[30];        // siguiente bit, junto con la bajada de CLK
                        bits    <= bits - 6'd1;
                        estado  <= (bits == 6'd1) ? S_CIERRE : S_BAJO;
                    end else begin
                        div <= div + 16'd1;
                    end
                end

                // Dejamos CLK abajo un rato antes de subir LOAD
                S_CIERRE: begin
                    if (div >= DIV_CLK - 1) begin
                        div    <= 16'd0;
                        load   <= 1'b1;           // flanco de subida: se enclavan los 16 bits en cada chip
                        estado <= S_LATCH;
                    end else begin
                        div <= div + 16'd1;
                    end
                end

                // LOAD en alto durante dos medios periodos (la hoja pide mínimo 50 ns)
                S_LATCH: begin
                    if (div >= 2*DIV_CLK - 1) begin
                        div    <= 16'd0;
                        load   <= 1'b0;
                        estado <= S_SEPARA;
                    end else begin
                        div <= div + 16'd1;
                    end
                end

                // Pequeña separación entre tramas y avance en la secuencia
                S_SEPARA: begin
                    if (div >= DIV_CLK - 1) begin
                        div    <= 16'd0;
                        estado <= S_CARGA;
                        if (idx == 4'd4) begin
                            config_fin <= 1'b1;
                            idx        <= 4'd5;
                        end else if (idx == 4'd12) begin
                            trama_fin <= 1'b1;
                            if (tramas >= REINIT_TRAMAS - 1) begin
                                tramas <= 16'd0;
                                idx    <= 4'd0;     // toca repetir la configuración
                            end else begin
                                tramas <= tramas + 16'd1;
                                idx    <= 4'd5;
                            end
                        end else begin
                            idx <= idx + 4'd1;
                        end
                    end else begin
                        div <= div + 16'd1;
                    end
                end

                default: estado <= S_CARGA;
            endcase
        end
    end

endmodule
