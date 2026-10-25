// ============================================================================
//  modelo_referencia.vh
//  Modelo de referencia del movimiento de la pelota, escrito a propósito de
//  una forma DISTINTA a colisiones.v. Si los dos coinciden en todos los casos
//  ganamos confianza de verdad; si lo hubiéramos copiado, cualquier error
//  estaría repetido en ambos lados y la prueba no serviría.
//
//  Aquí pensamos en términos de velocidades con signo (vx, vy = +1 / -1) y de
//  la "columna destino" a la que la pelota quiere llegar, en vez de las
//  condiciones X == 1 / X == 14 que usa el RTL.
// ============================================================================

task ref_paso;
    input  integer x, y, dx, dy, yp1, yp2, lp;
    output integer nx, ny, ndx, ndy;
    output integer imp_i, imp_d, g1, g2, pared, fuera;
    integer vx, vy, destino, cuy;
    begin
        imp_i = 0; imp_d = 0; g1 = 0; g2 = 0; pared = 0;
        fuera = (x == 0 || x == 15);
        vx = dx ? 1 : -1;
        vy = dy ? 1 : -1;

        if (fuera) begin
            nx = x; ny = y; ndx = dx; ndy = dy;
        end else begin
            destino = x + vx;
            if (destino == 0) begin
                if (y >= yp1 && y <= yp1 + lp - 1) begin
                    imp_i = 1;
                    vx = 1;
                    if (y == yp1)               vy = -1;
                    else if (y == yp1 + lp - 1) vy = 1;
                end else begin
                    g2 = 1;
                end
            end else if (destino == 15) begin
                if (y >= yp2 && y <= yp2 + lp - 1) begin
                    imp_d = 1;
                    vx = -1;
                    if (y == yp2)               vy = -1;
                    else if (y == yp2 + lp - 1) vy = 1;
                end else begin
                    g1 = 1;
                end
            end

            cuy = y + vy;
            if (cuy < 0) begin cuy = 1; vy = 1;  pared = 1; end
            if (cuy > 7) begin cuy = 6; vy = -1; pared = 1; end

            ny  = cuy;
            nx  = (imp_i || imp_d) ? (x + vx) : destino;
            ndx = (vx > 0);
            ndy = (vy > 0);
        end
    end
endtask
