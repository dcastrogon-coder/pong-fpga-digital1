// ============================================================================
//  tb_entradas.v  -  Prueba T09 (entradas seguras) y antirrebote
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Aquí tratamos de "romper" el bloque de entradas con lo que nos podemos
//  encontrar en el montaje real:
//   - rebotes de pulsador más cortos que la ventana de antirrebote;
//   - un receptor RF que pierde la señal y deja los datos enclavados en 1;
//   - huecos cortos en VT que no deberían pausar la partida;
//   - un START con rebotes que debe generar UN solo pulso.
//  También probamos la variante USAR_VT = 0 (controles cableados).
// ============================================================================

`timescale 1ns / 1ps

module tb_entradas;

    `include "tb_comun.vh"

    localparam integer N = 8;

    reg clk = 0, rst = 1, tick_1ms = 0;
    reg j1u = 0, j1d = 0, j2u = 0, j2d = 0, vt1 = 0, vt2 = 0;
    reg start_n = 1, reset_n = 1;     // botones de la tarjeta: activos en bajo

    wire s1u, s1d, s2u, s2d, e1, e2, st, rs;
    wire c1u, c1d, c2u, c2d, ce1, ce2, cst, crs;

    always #10 clk = ~clk;

    integer c = 0;
    always @(posedge clk) begin
        c <= (c == 9) ? 0 : c + 1;
        tick_1ms <= (c == 9);
    end

    // Versión con receptores RF (usa VT)
    entradas #(.N_MUESTRAS(N), .CTRL_ACTIVO_BAJO(0), .BOTON_ACTIVO_BAJO(1), .USAR_VT(1)) dut (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms),
        .j1_up_pin(j1u), .j1_down_pin(j1d), .j2_up_pin(j2u), .j2_down_pin(j2d),
        .j1_vt_pin(vt1), .j2_vt_pin(vt2), .start_pin(start_n), .reset_pin(reset_n),
        .j1_subir(s1u), .j1_bajar(s1d), .j2_subir(s2u), .j2_bajar(s2d),
        .enlace_j1(e1), .enlace_j2(e2), .start_pulso(st), .reset_juego(rs)
    );

    // Versión cableada (ignora VT)
    entradas #(.N_MUESTRAS(N), .CTRL_ACTIVO_BAJO(0), .BOTON_ACTIVO_BAJO(1), .USAR_VT(0)) dut_cable (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms),
        .j1_up_pin(j1u), .j1_down_pin(j1d), .j2_up_pin(j2u), .j2_down_pin(j2d),
        .j1_vt_pin(1'b0), .j2_vt_pin(1'b0), .start_pin(start_n), .reset_pin(reset_n),
        .j1_subir(c1u), .j1_bajar(c1d), .j2_subir(c2u), .j2_bajar(c2d),
        .enlace_j1(ce1), .enlace_j2(ce2), .start_pulso(cst), .reset_juego(crs)
    );

    integer n_start = 0;
    always @(posedge clk) if (st) n_start = n_start + 1;

    // Bandera que se levanta si j1_subir aparece en una ventana donde no debería
    reg vigilar_j1u = 0, j1u_indebido = 0;
    always @(posedge clk) if (vigilar_j1u && s1u) j1u_indebido = 1;

    task esperar_ms;
        input integer ms;
        begin repeat (ms * 10) @(negedge clk); end
    endtask

    integer i;

    initial begin
        $dumpfile("sim/tb_entradas.vcd");
        $dumpvars(0, tb_entradas);
        $display("== tb_entradas ==");

        repeat (5) @(negedge clk);
        rst = 0;
        esperar_ms(2);
        `VERIFICAR(!e1 && !e2, "hay enlace sin VT")
        `VERIFICAR(ce1 && ce2, "version cableada sin enlace forzado")

        // Los receptores se enganchan
        vt1 = 1; vt2 = 1;
        esperar_ms(N + 2);
        `VERIFICAR(e1 && e2, "no aparecio el enlace con VT = 1")

        // ---- Rebotes cortos: no deben pasar ----
        vigilar_j1u = 1;
        for (i = 0; i < 10; i = i + 1) begin
            j1u = 1; esperar_ms(3);
            j1u = 0; esperar_ms(2);
        end
        esperar_ms(N + 2);
        vigilar_j1u = 0;
        `VERIFICAR(!j1u_indebido, "un rebote corto paso como pulsacion")

        // ---- Pulsación estable: pasa después de ~N ms ----
        j1u = 1;
        esperar_ms(N - 3);
        `VERIFICAR(!s1u, "la orden paso antes de la ventana de antirrebote")
        esperar_ms(5);
        `VERIFICAR(s1u && !s1d && !s2u && !s2d, "pulsacion estable de J1 arriba")
        `VERIFICAR(c1u, "version cableada no paso la orden")

        // ---- Hueco corto en VT (3 ms): el enlace se mantiene ----
        vt1 = 0; esperar_ms(3); vt1 = 1;
        esperar_ms(1);
        `VERIFICAR(e1 && s1u, "un hueco corto de VT corto el enlace")

        // ---- Pérdida real de enlace con el dato enclavado en 1 (T09) ----
        vt1 = 0;           // j1u sigue en 1, como haría el HT12D
        esperar_ms(N + 3);
        `VERIFICAR(!e1 && !s1u, "T09 sin enlace la orden sigue activa")
        `VERIFICAR(e2, "la caida de J1 afecto el enlace de J2")
        `VERIFICAR(c1u, "la version cableada no deberia mirar VT")
        esperar_ms(50);
        `VERIFICAR(!s1u, "T09 movimiento permanente sin enlace")

        // Vuelve el enlace
        vt1 = 1; esperar_ms(N + 2);
        `VERIFICAR(e1 && s1u, "no se recupero el enlace")
        j1u = 0; esperar_ms(N + 2);
        `VERIFICAR(!s1u, "la orden no se solto")

        // ---- START con rebotes en ambos flancos: un solo pulso ----
        n_start = 0;
        for (i = 0; i < 4; i = i + 1) begin start_n = 0; esperar_ms(1); start_n = 1; esperar_ms(1); end
        start_n = 0; esperar_ms(40);
        for (i = 0; i < 4; i = i + 1) begin start_n = 1; esperar_ms(1); start_n = 0; esperar_ms(1); end
        start_n = 1; esperar_ms(40);
        `VERIFICAR(n_start == 1, $sformatf("START genero %0d pulsos", n_start))

        // ---- RESET por nivel ----
        reset_n = 0; esperar_ms(N + 2);
        `VERIFICAR(rs && crs, "RESET no se detecto")
        reset_n = 1; esperar_ms(N + 2);
        `VERIFICAR(!rs, "RESET no se libero")

        // ---- Órdenes de J2 en paralelo con J1 ----
        j1d = 1; j2u = 1; esperar_ms(N + 2);
        `VERIFICAR(s1d && s2u && !s1u && !s2d, "ordenes simultaneas de jugadores distintos")
        j1d = 0; j2u = 0;

        reporte_final("tb_entradas");
        $finish;
    end

endmodule
