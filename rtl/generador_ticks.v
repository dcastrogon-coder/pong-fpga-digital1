// ============================================================================
//  generador_ticks.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Aquí generamos todas las bases de tiempo del juego a partir del reloj de
//  50 MHz. Decidimos no usar relojes derivados (nada de clk/2, clk/4...) porque
//  en FPGA eso trae problemas de sesgo y de temporización; en su lugar sacamos
//  pulsos de habilitación de un solo ciclo que todos los bloques muestrean con
//  el mismo CLK_SYS.
//
//  Salidas:
//   - tick_1ms : un pulso cada milisegundo. Es nuestra "regla" de tiempo para
//                el antirrebote, la autorrepetición de las paletas y las pausas.
//   - tick_bola: un pulso cada vez que la pelota debe avanzar una casilla. Su
//                periodo depende del nivel de velocidad (0 a 3).
//   - parpadeo : onda cuadrada de ~2 Hz que usamos para hacer titilar cosas.
// ============================================================================

`timescale 1ns / 1ps

module generador_ticks #(
    parameter integer CLK_HZ      = 50_000_000, // frecuencia del oscilador de la tarjeta
    parameter integer T_BOLA_0_MS = 260,        // periodo de la pelota en el nivel 0 (más lento)
    parameter integer T_BOLA_1_MS = 200,
    parameter integer T_BOLA_2_MS = 150,
    parameter integer T_BOLA_3_MS = 110,        // nivel 3, el más rápido que dejamos
    parameter integer T_PARPADEO_MS = 250       // medio periodo del parpadeo (2 Hz)
)(
    input  wire       clk,
    input  wire       rst,          // reinicio síncrono, activo en alto
    input  wire [1:0] nivel,        // nivel de velocidad que entrega el control del juego
    input  wire       sincronizar,  // al sacar reiniciamos la cuenta para que el primer paso sea completo
    output reg        tick_1ms,
    output reg        tick_bola,
    output reg        parpadeo
);

    // Cuántos ciclos de reloj caben en un milisegundo. Con 50 MHz son 50 000,
    // así que 16 bits alcanzan; dejamos 32 para poder simular con otros valores.
    localparam integer CICLOS_MS = CLK_HZ / 1000;

    reg [31:0] cuenta_ciclos;
    reg [15:0] cuenta_bola;      // cuenta milisegundos, de sobra para 260 ms
    reg [15:0] cuenta_parpadeo;
    // ------------------------------------------------------------------
    // Selección del periodo según el nivel. Es un multiplexor 4 a 1 puro,
    // lo dejamos combinacional para que el cambio de nivel aplique de una.
    // Lo escribimos con "assign" y no con un always @(*) con case porque
    // en el simulador el always no se evaluaba en t = 0 cuando el nivel ya
    // nacía en cero, y el periodo quedaba en X. En hardware da lo mismo,
    // pero así la simulación y la síntesis cuentan la misma historia.
    // ------------------------------------------------------------------
    wire [15:0] periodo_bola = (nivel == 2'd0) ? T_BOLA_0_MS[15:0] :
                               (nivel == 2'd1) ? T_BOLA_1_MS[15:0] :
                               (nivel == 2'd2) ? T_BOLA_2_MS[15:0] :
                                                 T_BOLA_3_MS[15:0];

    // ------------------------------------------------------------------
    // Divisor principal: de CLK_SYS a un pulso por milisegundo.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            cuenta_ciclos <= 32'd0;
            tick_1ms      <= 1'b0;
        end else if (cuenta_ciclos >= CICLOS_MS - 1) begin
            cuenta_ciclos <= 32'd0;
            tick_1ms      <= 1'b1;
        end else begin
            cuenta_ciclos <= cuenta_ciclos + 32'd1;
            tick_1ms      <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Pulso de avance de la pelota. Contamos milisegundos y comparamos con
    // ">=" y no con "==" a propósito: si el nivel sube y el periodo nuevo
    // queda por debajo de la cuenta actual, igual se genera el pulso en
    // lugar de esperar a que el contador dé la vuelta completa.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst || sincronizar) begin
            cuenta_bola <= 16'd0;
            tick_bola   <= 1'b0;
        end else if (tick_1ms) begin
            if (cuenta_bola >= periodo_bola - 16'd1) begin
                cuenta_bola <= 16'd0;
                tick_bola   <= 1'b1;
            end else begin
                cuenta_bola <= cuenta_bola + 16'd1;
                tick_bola   <= 1'b0;
            end
        end else begin
            tick_bola <= 1'b0;   // nos aseguramos de que el pulso dure un solo ciclo
        end
    end

    // ------------------------------------------------------------------
    // Onda de parpadeo, la usamos para la pelota en espera y para el
    // ganador al final de la partida.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            cuenta_parpadeo <= 16'd0;
            parpadeo        <= 1'b0;
        end else if (tick_1ms) begin
            if (cuenta_parpadeo >= T_PARPADEO_MS - 1) begin
                cuenta_parpadeo <= 16'd0;
                parpadeo        <= ~parpadeo;
            end else begin
                cuenta_parpadeo <= cuenta_parpadeo + 16'd1;
            end
        end
    end

endmodule
