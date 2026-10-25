// ============================================================================
//  puntaje.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Marcador de los dos jugadores (requisitos R05 y R06).
//
//  Cada jugador tiene un contador de 4 bits porque el marcador se muestra en
//  un solo display de siete segmentos, así que el máximo útil es 9. La regla
//  que congelamos es: gana el primero que llegue a PUNTOS_VICTORIA (9 por
//  defecto). Al llegar, el contador se satura y no vuelve a sumar.
//
//  Tabla de transición (para cada jugador i):
//     rst/limpiar | contar · gol_i | P_i < PV | P_i+
//          1      |       x        |    x     |  0
//          0      |       1        |    1     |  P_i + 1
//          0      |       1        |    0     |  P_i      (saturado)
//          0      |       0        |    x     |  P_i
//
//  "contar" lo entrega el control del juego y solo vale 1 en el estado
//  JUEGO. Así un gol que llegue en pausa o en el punto anotado no se cuenta.
//  Además el gol viene como pulso de un ciclo desde pelota.v, por lo que es
//  imposible sumar dos veces por el mismo evento.
// ============================================================================

`timescale 1ns / 1ps

module puntaje #(
    parameter integer PUNTOS_VICTORIA = 9
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       limpiar,     // nueva partida
    input  wire       contar,      // habilitación desde el control del juego
    input  wire       gol_j1,
    input  wire       gol_j2,
    output reg  [3:0] p1,
    output reg  [3:0] p2,
    output wire       gana_j1,
    output wire       gana_j2
);

    localparam [3:0] PV = PUNTOS_VICTORIA[3:0];

    assign gana_j1 = (p1 >= PV);
    assign gana_j2 = (p2 >= PV);

    always @(posedge clk) begin
        if (rst || limpiar) begin
            p1 <= 4'd0;
            p2 <= 4'd0;
        end else begin
            // Los dos goles no pueden llegar juntos (la pelota está en un solo
            // lado), pero igual los tratamos por separado: no hay prioridad
            // que definir y el circuito queda más simple.
            if (contar && gol_j1 && (p1 < PV)) p1 <= p1 + 4'd1;
            if (contar && gol_j2 && (p2 < PV)) p2 <= p2 + 4'd1;

            // Protección: si por ruido el registro tomara un valor mayor
            // que el tope, lo devolvemos al tope en vez de mostrar basura.
            if (p1 > PV) p1 <= PV;
            if (p2 > PV) p2 <= PV;
        end
    end

endmodule
