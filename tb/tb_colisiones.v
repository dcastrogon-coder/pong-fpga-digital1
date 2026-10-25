// ============================================================================
//  tb_colisiones.v  -  Prueba T04 (y parte de T05)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Como colisiones.v es puramente combinacional, nos pudimos dar el lujo de
//  probarlo de forma EXHAUSTIVA: todas las combinaciones de
//      X (16) x Y (8) x DX (2) x DY (2) x YP1 (6) x YP2 (6) = 18 432 casos.
//  En cada caso comparamos contra el modelo de referencia y además revisamos
//  invariantes que tienen que cumplirse siempre:
//    - nunca hay gol de los dos lados a la vez;
//    - nunca hay impacto y gol del mismo lado a la vez;
//    - la pelota nunca "salta" más de una casilla por paso.
// ============================================================================

`timescale 1ns / 1ps

module tb_colisiones;

    `include "tb_comun.vh"
    `include "modelo_referencia.vh"

    localparam integer LP = 3;

    reg  [3:0] x;
    reg  [2:0] y, yp1, yp2;
    reg        dx, dy;
    wire [3:0] x_sig;
    wire [2:0] y_sig;
    wire       dx_sig, dy_sig, imp_i, imp_d, g1, g2, pared, fuera;

    colisiones #(.LP(LP)) dut (
        .x(x), .y(y), .dx(dx), .dy(dy), .yp1(yp1), .yp2(yp2),
        .x_sig(x_sig), .y_sig(y_sig), .dx_sig(dx_sig), .dy_sig(dy_sig),
        .impacto_izq(imp_i), .impacto_der(imp_d),
        .gol_j1(g1), .gol_j2(g2), .rebote_pared(pared), .fuera(fuera)
    );

    integer ix, iy, idx, idy, ip1, ip2;
    integer rnx, rny, rdx, rdy, ri, rd, rg1, rg2, rp, rf;
    integer casos, n_imp, n_gol, n_pared;

    initial begin
        $display("== tb_colisiones: barrido exhaustivo ==");
        casos = 0; n_imp = 0; n_gol = 0; n_pared = 0;

        for (ix = 0; ix < 16; ix = ix + 1)
        for (iy = 0; iy < 8;  iy = iy + 1)
        for (idx = 0; idx < 2; idx = idx + 1)
        for (idy = 0; idy < 2; idy = idy + 1)
        for (ip1 = 0; ip1 <= 8 - LP; ip1 = ip1 + 1)
        for (ip2 = 0; ip2 <= 8 - LP; ip2 = ip2 + 1) begin
            x = ix; y = iy; dx = idx; dy = idy; yp1 = ip1; yp2 = ip2;
            #1;
            ref_paso(ix, iy, idx, idy, ip1, ip2, LP,
                     rnx, rny, rdx, rdy, ri, rd, rg1, rg2, rp, rf);

            `VERIFICAR(x_sig == rnx && y_sig == rny && dx_sig == rdx && dy_sig == rdy,
                $sformatf("estado: X=%0d Y=%0d DX=%0d DY=%0d YP1=%0d YP2=%0d -> RTL (%0d,%0d,%0d,%0d) ref (%0d,%0d,%0d,%0d)",
                          ix, iy, idx, idy, ip1, ip2, x_sig, y_sig, dx_sig, dy_sig, rnx, rny, rdx, rdy))
            `VERIFICAR(imp_i == ri && imp_d == rd && g1 == rg1 && g2 == rg2 && pared == rp && fuera == rf,
                $sformatf("eventos: X=%0d Y=%0d DX=%0d DY=%0d YP1=%0d YP2=%0d", ix, iy, idx, idy, ip1, ip2))

            // Invariantes
            `VERIFICAR(!(g1 && g2), "dos goles simultaneos")
            `VERIFICAR(!(imp_i && g2) && !(imp_d && g1), "impacto y gol del mismo lado")
            `VERIFICAR(fuera || ((x_sig == x + 1 || x_sig == x - 1) && (y_sig == y + 1 || y_sig == y - 1)),
                $sformatf("salto de mas de una casilla en X=%0d Y=%0d", ix, iy))

            casos   = casos + 1;
            n_imp   = n_imp + imp_i + imp_d;
            n_gol   = n_gol + g1 + g2;
            n_pared = n_pared + pared;
        end

        $display("  casos evaluados : %0d", casos);
        $display("  con impacto     : %0d", n_imp);
        $display("  con gol         : %0d", n_gol);
        $display("  rebote en pared : %0d", n_pared);
        reporte_final("tb_colisiones");
        $finish;
    end

endmodule
