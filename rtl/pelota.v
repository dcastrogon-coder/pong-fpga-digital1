// ============================================================================
//  pelota.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Registro de estado de la pelota (requisitos R03, R04 y R05).
//
//  Aquí solo guardamos (X, Y, DX, DY) y decidimos CUÁNDO cambian; el QUÉ
//  lo calcula colisiones.v. Separarlo así nos ayudó bastante: la tabla de
//  eventos la probamos de forma exhaustiva en tb_colisiones sin tener que
//  esperar pulsos de reloj.
//
//  Tabla de transición resumida:
//     rst | saque | tick·habilitar | siguiente estado
//      1  |   x   |       x        | posición de reposo (centro, X = ANCHO/2 - 1)
//      0  |   1   |       x        | posición de saque (centro, hacia quien perdió)
//      0  |   0   |       1        | (X,Y,DX,DY) <- salida de colisiones
//      0  |   0   |       0        | se mantiene
//
//  El saque tiene prioridad sobre el tick: si llegan juntos, gana el saque,
//  porque significa que el control del juego acaba de reiniciar la jugada.
//
//  Las banderas de evento (gol, rebotes) salen REGISTRADAS y duran un solo
//  ciclo de reloj. Eso es lo que garantiza que un gol sume exactamente un
//  punto (R05).
// ============================================================================

`timescale 1ns / 1ps

module pelota #(
    parameter integer LP    = 3,
    parameter integer ANCHO = 32,
    parameter integer XB    = (ANCHO > 16) ? 5 : 4
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,          // tick_bola
    input  wire       habilitar,     // solo avanza en el estado JUEGO
    input  wire       saque,         // pulso: llevar la pelota al centro
    input  wire       saque_dx,      // hacia dónde sale (1 = hacia J2)
    input  wire       saque_dy,      // si sale bajando (1) o subiendo (0)
    input  wire [2:0] saque_y,       // fila de salida
    input  wire [2:0] yp1,
    input  wire [2:0] yp2,

    output reg  [XB-1:0] x,
    output reg  [2:0] y,
    output reg        dx,
    output reg        dy,

    output reg        gol_j1,
    output reg        gol_j2,
    output reg        rebote_paleta,
    output reg        rebote_pared
);

    wire [XB-1:0] x_sig;
    wire [2:0] y_sig;
    wire       dx_sig, dy_sig;
    wire       imp_i, imp_d, g1, g2, rp, fuera;

    // Las dos columnas del centro: con 16 son la 7 y la 8, con 32 la 15 y la 16
    localparam [XB-1:0] CENTRO_IZQ = ANCHO/2 - 1;
    localparam [XB-1:0] CENTRO_DER = ANCHO/2;

    colisiones #(.LP(LP), .ANCHO(ANCHO)) u_colisiones (
        .x(x), .y(y), .dx(dx), .dy(dy),
        .yp1(yp1), .yp2(yp2),
        .x_sig(x_sig), .y_sig(y_sig), .dx_sig(dx_sig), .dy_sig(dy_sig),
        .impacto_izq(imp_i), .impacto_der(imp_d),
        .gol_j1(g1), .gol_j2(g2),
        .rebote_pared(rp), .fuera(fuera)
    );

    always @(posedge clk) begin
        if (rst) begin
            // Al encender la dejamos en el centro, lista para salir hacia J2
            x  <= CENTRO_IZQ;
            y  <= 3'd3;
            dx <= 1'b1;
            dy <= 1'b1;
            gol_j1 <= 1'b0; gol_j2 <= 1'b0;
            rebote_paleta <= 1'b0; rebote_pared <= 1'b0;
        end else begin
            // Por defecto los eventos se apagan; así duran un ciclo
            gol_j1 <= 1'b0; gol_j2 <= 1'b0;
            rebote_paleta <= 1'b0; rebote_pared <= 1'b0;

            if (saque) begin
                // Si sale hacia la derecha arranca en la columna central de la
                // izquierda y si sale hacia la izquierda en la de la derecha,
                // para que ambos jugadores tengan exactamente el mismo tiempo
                // de reacción.
                x  <= saque_dx ? CENTRO_IZQ : CENTRO_DER;
                y  <= saque_y;
                dx <= saque_dx;
                dy <= saque_dy;
            end else if (tick && habilitar) begin
                x  <= x_sig;
                y  <= y_sig;
                dx <= dx_sig;
                dy <= dy_sig;
                gol_j1        <= g1;
                gol_j2        <= g2;
                rebote_paleta <= imp_i | imp_d;
                rebote_pared  <= rp;
            end
        end
    end

endmodule
