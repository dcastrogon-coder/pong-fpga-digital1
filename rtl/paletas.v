// ============================================================================
//  paletas.v  (módulo: paleta)
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Posición vertical de UNA paleta (requisitos R01 y R02). En el top lo
//  instanciamos dos veces, una por jugador.
//
//  La paleta se describe con su fila superior YP y su longitud LP = 3, de modo
//  que ocupa las filas YP, YP+1 y YP+2. Para que nunca se salga de la pantalla
//  exigimos 0 <= YP <= 8 - LP = 5.
//
//  1) Petición de movimiento (combinacional, Tabla V de la guía):
//         U D | M1 M0 | acción
//         0 0 |  0  0 | mantener
//         0 1 |  0  1 | bajar
//         1 0 |  1  0 | subir
//         1 1 |  0  0 | mantener (conflicto: no le damos prioridad a nadie)
//     => solicitar_subir = U·D'    solicitar_bajar = U'·D
//
//  2) ¿Cuándo se aplica el paso? Al principio pensamos en mover la paleta con
//     un TICK_PADDLE fijo, pero así un toque rápido que cae entre dos ticks
//     se pierde. Lo resolvimos como el teclado de un computador:
//       - apenas cambia la petición, damos un paso inmediato;
//       - si el jugador mantiene presionado, esperamos RETARDO_MS y luego
//         repetimos cada REPETICION_MS.
//     El pulso "paso" que resulta hace las veces de TICK_PADDLE.
//
//  3) Transición de posición (ecuación 4 de la guía):
//         YP+ = YP - 1   si subir y YP > 0
//         YP+ = YP + 1   si bajar y YP < 8 - LP
//         YP+ = YP       en otro caso
//     Recordemos que la fila 0 es la de arriba, por eso "subir" resta.
// ============================================================================

`timescale 1ns / 1ps

module paleta #(
    parameter integer LP            = 3,    // longitud de la paleta en LEDs
    parameter integer YP_INICIAL    = 2,    // fila superior al reiniciar (filas 2,3,4)
    parameter integer RETARDO_MS    = 180,  // tiempo antes de empezar la autorrepetición
    parameter integer REPETICION_MS = 90    // periodo de la autorrepetición
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_1ms,
    input  wire       habilitar,   // en pausa o al final de la partida no dejamos mover
    input  wire       subir,       // U, ya limpia y validada por el enlace
    input  wire       bajar,       // D
    output reg  [2:0] yp           // fila superior de la paleta
);

    localparam [2:0] YP_MAX = 8 - LP;   // con LP=3 vale 5

    // ---------------- Petición (tabla de verdad) ----------------
    wire solicitar_subir = subir & ~bajar;
    wire solicitar_bajar = bajar & ~subir;
    wire [1:0] m = {solicitar_subir, solicitar_bajar};   // M1 M0

    // ---------------- Generación del paso ----------------
    reg  [1:0]  m_anterior;
    reg  [15:0] cuenta_rep;
    reg         paso;

    always @(posedge clk) begin
        if (rst) begin
            m_anterior <= 2'b00;
            cuenta_rep <= 16'd0;
            paso       <= 1'b0;
        end else begin
            m_anterior <= m;
            paso       <= 1'b0;
            if (m == 2'b00) begin
                cuenta_rep <= 16'd0;                  // soltó los botones
            end else if (m != m_anterior) begin
                paso       <= 1'b1;                   // toque nuevo: paso inmediato
                cuenta_rep <= RETARDO_MS;
            end else if (tick_1ms) begin
                if (cuenta_rep <= 16'd1) begin
                    paso       <= 1'b1;               // sigue presionado: autorrepetición
                    cuenta_rep <= REPETICION_MS;
                end else begin
                    cuenta_rep <= cuenta_rep - 16'd1;
                end
            end
        end
    end

    // Guardamos qué dirección pidió el paso, porque "paso" sale un ciclo
    // después de que se evaluó m.
    reg [1:0] m_paso;
    always @(posedge clk) begin
        if (rst) m_paso <= 2'b00;
        else     m_paso <= m;
    end

    // ---------------- Transición de posición ----------------
    always @(posedge clk) begin
        if (rst) begin
            yp <= YP_INICIAL[2:0];
        end else if (yp > YP_MAX) begin
            // Estado inválido (no debería ocurrir nunca). Si por algún motivo
            // aparece, lo devolvemos al límite inferior en vez de dejarlo así.
            yp <= YP_MAX;
        end else if (paso && habilitar) begin
            if (m_paso == 2'b10 && yp > 3'd0)
                yp <= yp - 3'd1;          // subir
            else if (m_paso == 2'b01 && yp < YP_MAX)
                yp <= yp + 3'd1;          // bajar
            // en cualquier otro caso se mantiene
        end
    end

endmodule
