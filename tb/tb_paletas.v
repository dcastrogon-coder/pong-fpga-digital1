// ============================================================================
//  tb_paletas.v  -  Pruebas T01 y T02 (y el caso de botones simultáneos de T09)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Instanciamos las dos paletas tal como quedan en el top y les mandamos
//  órdenes. Para no esperar 50 000 ciclos por milisegundo, aquí generamos
//  tick_1ms cada 10 ciclos: la lógica es la misma, solo cambia la escala.
//
//  Qué revisamos:
//   T01: una orden a un jugador solo mueve SU paleta.
//   T02: en los límites (YP = 0 y YP = 5) la paleta no se desborda.
//   T09: subir y bajar a la vez no mueve la paleta.
//   Extra: tiempos de autorrepetición y que con habilitar = 0 no se mueva.
//   Y en TODO momento: YP <= 5 y nunca cambia más de una fila de golpe.
// ============================================================================

`timescale 1ns / 1ps

module tb_paletas;

    `include "tb_comun.vh"

    localparam integer CICLOS_MS  = 10;
    localparam integer RETARDO    = 180;
    localparam integer REPETICION = 90;

    reg clk = 0, rst = 1, tick_1ms = 0, hab = 1;
    reg u1 = 0, d1 = 0, u2 = 0, d2 = 0;
    wire [2:0] yp1, yp2;

    always #5 clk = ~clk;

    // tick de 1 "ms" simulado
    integer c_tick = 0;
    always @(posedge clk) begin
        c_tick   <= (c_tick == CICLOS_MS - 1) ? 0 : c_tick + 1;
        tick_1ms <= (c_tick == CICLOS_MS - 1);
    end

    paleta #(.LP(3), .YP_INICIAL(2), .RETARDO_MS(RETARDO), .REPETICION_MS(REPETICION)) dut1
        (.clk(clk), .rst(rst), .tick_1ms(tick_1ms), .habilitar(hab), .subir(u1), .bajar(d1), .yp(yp1));
    paleta #(.LP(3), .YP_INICIAL(2), .RETARDO_MS(RETARDO), .REPETICION_MS(REPETICION)) dut2
        (.clk(clk), .rst(rst), .tick_1ms(tick_1ms), .habilitar(hab), .subir(u2), .bajar(d2), .yp(yp2));

    // ------------------------------------------------------------------
    // Monitor permanente de invariantes
    // ------------------------------------------------------------------
    reg [2:0] yp1_ant, yp2_ant;
    always @(posedge clk) begin
        yp1_ant <= yp1;
        yp2_ant <= yp2;
        if (!rst) begin
            if (yp1 > 5 || yp2 > 5) begin
                errores = errores + 1;
                $display("  [FALLA] t=%0t : paleta fuera de rango yp1=%0d yp2=%0d", $time, yp1, yp2);
            end
            if ((yp1 > yp1_ant + 1) || (yp1_ant > yp1 + 1) || (yp2 > yp2_ant + 1) || (yp2_ant > yp2 + 1)) begin
                errores = errores + 1;
                $display("  [FALLA] t=%0t : la paleta salto mas de una fila", $time);
            end
        end
    end

    // Guardamos los instantes (en ms simulados) en que cambia la paleta 2
    integer t_cambio [0:15];
    integer n_cambios = 0;
    reg     registrar = 0;
    always @(posedge clk) begin
        if (registrar && yp2 != yp2_ant && n_cambios < 16) begin
            t_cambio[n_cambios] = $time / (10 * CICLOS_MS);
            n_cambios = n_cambios + 1;
        end
    end

    task esperar_ms;
        input integer ms;
        begin
            repeat (ms * CICLOS_MS) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("sim/tb_paletas.vcd");
        $dumpvars(0, tb_paletas);
        $display("== tb_paletas ==");

        repeat (5) @(posedge clk);
        rst = 0;
        @(posedge clk);
        `VERIFICAR(yp1 == 2 && yp2 == 2, "valores de reinicio")

        // ---- T01: cada jugador mueve solo su paleta ----
        u1 = 1; esperar_ms(5); u1 = 0; esperar_ms(5);
        `VERIFICAR(yp1 == 1 && yp2 == 2, $sformatf("T01a J1 sube: yp1=%0d yp2=%0d", yp1, yp2))

        d2 = 1; esperar_ms(5); d2 = 0; esperar_ms(5);
        `VERIFICAR(yp1 == 1 && yp2 == 3, $sformatf("T01b J2 baja: yp1=%0d yp2=%0d", yp1, yp2))

        // Los dos jugadores a la vez, en sentidos contrarios
        d1 = 1; u2 = 1; esperar_ms(5); d1 = 0; u2 = 0; esperar_ms(5);
        `VERIFICAR(yp1 == 2 && yp2 == 2, $sformatf("T01c simultaneo: yp1=%0d yp2=%0d", yp1, yp2))

        // ---- T09 (parte): subir y bajar al mismo tiempo ----
        u1 = 1; d1 = 1; esperar_ms(400); u1 = 0; d1 = 0; esperar_ms(5);
        `VERIFICAR(yp1 == 2, $sformatf("conflicto U=D=1 movio la paleta: yp1=%0d", yp1))

        // ---- T02: límite superior ----
        u1 = 1; esperar_ms(1500);
        `VERIFICAR(yp1 == 0, $sformatf("T02a limite superior: yp1=%0d", yp1))
        esperar_ms(500);
        `VERIFICAR(yp1 == 0, "T02a la paleta se desbordo arriba")
        u1 = 0; esperar_ms(5);

        // ---- T02: límite inferior ----
        d1 = 1; esperar_ms(2000);
        `VERIFICAR(yp1 == 5, $sformatf("T02b limite inferior: yp1=%0d", yp1))
        u1 = 0; d1 = 0; esperar_ms(5);
        `VERIFICAR(yp2 == 2, "T02 la paleta de J2 se movio sola")

        // ---- Autorrepetición: medimos los tiempos entre pasos ----
        // Primero bajamos la paleta 2 hasta el fondo para tener espacio
        d2 = 1; esperar_ms(1000); d2 = 0; esperar_ms(5);
        `VERIFICAR(yp2 == 5, "no llego al fondo antes de medir")
        registrar = 1;
        u2 = 1; esperar_ms(RETARDO + REPETICION + 30); u2 = 0; esperar_ms(5);
        registrar = 0;
        `VERIFICAR(n_cambios == 2 || n_cambios == 3, $sformatf("pasos de autorrepeticion = %0d", n_cambios))
        if (n_cambios >= 2) begin
            $display("  pasos registrados: %0d (retardo inicial %0d ms, repeticion %0d ms)",
                     n_cambios, t_cambio[1] - t_cambio[0], (n_cambios >= 3) ? t_cambio[2] - t_cambio[1] : 0);
            `VERIFICAR((t_cambio[1] - t_cambio[0]) >= RETARDO - 3 && (t_cambio[1] - t_cambio[0]) <= RETARDO + 1,
                $sformatf("retardo inicial %0d ms", t_cambio[1] - t_cambio[0]))
        end
        if (n_cambios >= 3)
            `VERIFICAR((t_cambio[2] - t_cambio[1]) >= REPETICION - 2 && (t_cambio[2] - t_cambio[1]) <= REPETICION + 2,
                $sformatf("periodo de repeticion %0d ms", t_cambio[2] - t_cambio[1]))

        // ---- Con habilitar = 0 no hay movimiento ----
        hab = 0;
        begin : sin_hab
            reg [2:0] antes;
            antes = yp2;
            d2 = 1; esperar_ms(400); d2 = 0; esperar_ms(5);
            `VERIFICAR(yp2 == antes, "se movio con habilitar = 0")
        end
        hab = 1;

        // ---- Reinicio en medio de una pulsación ----
        d1 = 1; esperar_ms(3); rst = 1; esperar_ms(2); rst = 0; d1 = 0; esperar_ms(2);
        `VERIFICAR(yp1 == 2 && yp2 == 2, "T06 reinicio de paletas")

        reporte_final("tb_paletas");
        $finish;
    end

endmodule
