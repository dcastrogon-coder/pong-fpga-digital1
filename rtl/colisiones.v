// ============================================================================
//  colisiones.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Lógica COMBINACIONAL que decide el siguiente estado de la pelota
//  (requisitos R04 y R05). No tiene registros: recibe el estado actual
//  (X, Y, DX, DY) y la posición de las dos paletas, y entrega el estado
//  siguiente junto con las banderas de evento. El registro vive en pelota.v.
//
//  Convenciones que acordamos:
//    - Coordenadas: 0 <= X <= ANCHO-1 (columna), 0 <= Y <= 7 (fila, 0 arriba).
//      ANCHO = 16 con dos matrices 8x8 y ANCHO = 32 con el módulo de cuatro
//      matrices (MAX7219 x4) que terminamos comprando. Aquí lo escribimos
//      con U = ANCHO - 1 (última columna).
//    - Paleta J1 en la columna 0, paleta J2 en la columna U.
//    - DX = 1 -> la pelota va a la derecha (hacia J2); DX = 0 -> a la izquierda.
//    - DY = 1 -> la pelota baja (Y crece);           DY = 0 -> sube.
//
//  Condiciones booleanas principales:
//    cubre1    = (YP1 <= Y <= YP1 + LP - 1)
//    impacto_i = (X == 1)  · DX'  · cubre1     -> rebote con la paleta de J1
//    impacto_d = (X == U-1)· DX   · cubre2     -> rebote con la paleta de J2
//    gol_j2    = (X == 1)  · DX'  · cubre1'    -> J1 falló, punto para J2
//    gol_j1    = (X == U-1)· DX   · cubre2'    -> J2 falló, punto para J1
//
//  Prioridades cuando dos cosas pasan en el mismo paso:
//    1. Primero se decide lo horizontal (impacto o gol), porque eso define
//       si la pelota sigue en juego.
//    2. Si hubo impacto con paleta, el "efecto" puede cambiar DY: golpe con
//       la fila de arriba manda la pelota hacia arriba, con la de abajo la
//       manda hacia abajo, y con la del centro conserva su DY.
//    3. Al final se aplica el rebote con la pared superior o inferior sobre
//       ese DY ya corregido. Así nunca calculamos una Y fuera de 0..7.
//    Un gol y un rebote de pared SÍ pueden coincidir (la pelota se escapa por
//    una esquina); en ese caso se marcan ambos y la pelota termina en X = 0
//    o X = U con la Y ya reflejada.
// ============================================================================

`timescale 1ns / 1ps

module colisiones #(
    parameter integer LP    = 3,
    parameter integer ANCHO = 32,                      // columnas de la pantalla (16 o 32)
    parameter integer XB    = (ANCHO > 16) ? 5 : 4     // bits de X; se calcula solo, no tocar
)(
    input  wire [XB-1:0] x,
    input  wire [2:0] y,
    input  wire       dx,
    input  wire       dy,
    input  wire [2:0] yp1,       // fila superior de la paleta de J1 (izquierda)
    input  wire [2:0] yp2,       // fila superior de la paleta de J2 (derecha)

    output reg  [XB-1:0] x_sig,
    output reg  [2:0] y_sig,
    output reg        dx_sig,
    output reg        dy_sig,

    output wire       impacto_izq,
    output wire       impacto_der,
    output wire       gol_j1,       // punto para J1 (la pelota pasó a J2)
    output wire       gol_j2,       // punto para J2 (la pelota pasó a J1)
    output wire       rebote_pared,
    output wire       fuera         // pelota ya en la columna de una paleta (estado de gol)
);

    // Trabajamos la comparación de cobertura en 4 bits para que YP+LP-1
    // no se desborde (con YP=5 da 7, pero preferimos no arriesgarnos).
    wire [3:0] y4      = {1'b0, y};
    wire [3:0] p1_ini  = {1'b0, yp1};
    wire [3:0] p1_fin  = {1'b0, yp1} + (LP - 1);
    wire [3:0] p2_ini  = {1'b0, yp2};
    wire [3:0] p2_fin  = {1'b0, yp2} + (LP - 1);

    wire cubre1 = (y4 >= p1_ini) && (y4 <= p1_fin);
    wire cubre2 = (y4 >= p2_ini) && (y4 <= p2_fin);

    localparam [XB-1:0] ULTIMA = ANCHO - 1;      // columna de la paleta de J2

    wire en_borde_izq = (x == 1)          && !dx;   // a punto de llegar a la columna de J1
    wire en_borde_der = (x == ULTIMA - 1) &&  dx;   // a punto de llegar a la columna de J2

    assign impacto_izq = en_borde_izq &&  cubre1;
    assign impacto_der = en_borde_der &&  cubre2;
    assign gol_j2      = en_borde_izq && !cubre1;
    assign gol_j1      = en_borde_der && !cubre2;

    // Si la pelota ya está en la columna 0 o en la última es porque hubo gol.
    // Ahí la dejamos congelada; el control del juego se encarga de volver a
    // sacar. Con ANCHO = 16 los valores de X mayores a 15 no existen; con
    // ANCHO = 32 tampoco, porque X tiene justo 5 bits.
    assign fuera = (x == 0) || (x >= ULTIMA);

    // ---------- Efecto según la zona de la paleta que golpea ----------
    wire golpe_arriba_i = (y4 == p1_ini);
    wire golpe_abajo_i  = (y4 == p1_fin);
    wire golpe_arriba_d = (y4 == p2_ini);
    wire golpe_abajo_d  = (y4 == p2_fin);

    reg dy_efecto;
    always @(*) begin
        dy_efecto = dy;
        if (impacto_izq) begin
            if (golpe_arriba_i)      dy_efecto = 1'b0;
            else if (golpe_abajo_i)  dy_efecto = 1'b1;
        end else if (impacto_der) begin
            if (golpe_arriba_d)      dy_efecto = 1'b0;
            else if (golpe_abajo_d)  dy_efecto = 1'b1;
        end
    end

    // ---------- Rebote con paredes superior e inferior ----------
    wire choca_techo = (y == 3'd0) && (dy_efecto == 1'b0);
    wire choca_piso  = (y == 3'd7) && (dy_efecto == 1'b1);
    assign rebote_pared = !fuera && (choca_techo || choca_piso);

    // ---------- Estado siguiente ----------
    always @(*) begin
        // Valores por defecto para no inferir latches
        x_sig  = x;
        y_sig  = y;
        dx_sig = dx;
        dy_sig = dy;

        if (fuera) begin
            // Congelada: no cambiamos nada
            x_sig  = x;
            y_sig  = y;
            dx_sig = dx;
            dy_sig = dy;
        end else begin
            // Vertical
            if (choca_techo)      dy_sig = 1'b1;
            else if (choca_piso)  dy_sig = 1'b0;
            else                  dy_sig = dy_efecto;

            y_sig = dy_sig ? (y + 3'd1) : (y - 3'd1);

            // Horizontal
            if (impacto_izq) begin
                dx_sig = 1'b1;
                x_sig  = x + 1'b1;     // de 1 pasa a 2
            end else if (impacto_der) begin
                dx_sig = 1'b0;
                x_sig  = x - 1'b1;     // de U-1 pasa a U-2
            end else begin
                dx_sig = dx;
                x_sig  = dx ? (x + 1'b1) : (x - 1'b1);   // incluye el caso de gol
            end
        end
    end

endmodule
