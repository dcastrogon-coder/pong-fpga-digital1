// ============================================================================
//  tb_max7219.v  -  Prueba T08
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Conectamos nuestro transmisor a N_CHIPS modelos de MAX7219 en cadena,
//  igual que en el módulo x4 (cuatro chips en la misma placa):
//
//      FPGA DIN --> [chip 0, cercano] DOUT --> [chip 1] --> ... --> [chip N-1]
//      CLK_LED y LOAD van en paralelo a todos los chips
//
//  y comprobamos que:
//   1. la configuración (test, scan limit, decode, brillo, shutdown) llega
//      igual a todos los chips;
//   2. entre dos flancos de LOAD hay exactamente 16·N flancos de CLK;
//   3. con varios patrones conocidos, los registros reconstruidos de todos
//      los chips forman exactamente la imagen que pedimos;
//   4. no se viola ningún tiempo mínimo de la hoja de datos;
//   5. si un chip "se reinicia" por ruido, la reconfiguración periódica lo
//      recupera;
//   6. el parámetro MODULO_CERCANO realmente invierte el orden de la cadena.
//  Usamos el reloj real de 50 MHz y DIV_CLK = 25 (CLK_LED de 1 MHz).
// ============================================================================

`timescale 1ns / 1ps

module tb_max7219;

    `include "tb_comun.vh"

    localparam integer NB = 8 * ANCHO;     // bits de imagen

    reg clk = 0, rst = 1;
    always #10 clk = ~clk;   // 50 MHz

    reg  [NB-1:0] img_prueba;
    wire [NB-1:0] bytes_prueba;

    // Armamos los bytes con el mismo mapeo por defecto de imagen.v (ya
    // verificado en tb_imagen): dígito d = fila d, bit 7 = columna izquierda.
    function [NB-1:0] mapa;
        input [NB-1:0] im;
        integer m, d, b;
        begin
            for (m = 0; m < N_CHIPS; m = m + 1)
                for (d = 0; d < 8; d = d + 1)
                    for (b = 0; b < 8; b = b + 1)
                        mapa[(m*8 + d)*8 + b] = im[d*ANCHO + m*8 + (7 - b)];
        end
    endfunction
    assign bytes_prueba = mapa(img_prueba);

    // ---------------- Cadena A: la matriz izquierda es la cercana ----------------
    wire din_a, clk_a, load_a, trama_a, conf_a;
    max7219_tx #(.DIV_CLK(25), .N_CHIPS(N_CHIPS), .MODULO_CERCANO(0), .REINIT_TRAMAS(4)) dut_a (
        .clk(clk), .rst(rst), .bytes(bytes_prueba),
        .din(din_a), .clk_led(clk_a), .load(load_a),
        .trama_fin(trama_a), .config_fin(conf_a)
    );

    // ---------------- Cadena B: la matriz derecha es la cercana ----------------
    wire din_b, clk_b, load_b, trama_b, conf_b;
    max7219_tx #(.DIV_CLK(25), .N_CHIPS(N_CHIPS), .MODULO_CERCANO(1), .REINIT_TRAMAS(4)) dut_b (
        .clk(clk), .rst(rst), .bytes(bytes_prueba),
        .din(din_b), .clk_led(clk_b), .load(load_b),
        .trama_fin(trama_b), .config_fin(conf_b)
    );

    // Estado de todos los chips, aplanado por posición en la cadena
    wire [N_CHIPS-1:0]    dout_a, dout_b;
    wire [64*N_CHIPS-1:0] dig_a, dig_b;
    wire [40*N_CHIPS-1:0] conf_regs_a, conf_regs_b;
    wire [32*N_CHIPS-1:0] viol_a, viol_b, clks_a;

    genvar k;
    generate
        for (k = 0; k < N_CHIPS; k = k + 1) begin : g_chip
            modelo_max7219 ua (
                .din((k == 0) ? din_a : dout_a[(k == 0) ? 0 : k - 1]),
                .clk(clk_a), .load(load_a), .dout(dout_a[k]),
                .digitos(dig_a[64*k +: 64]), .config_regs(conf_regs_a[40*k +: 40]),
                .n_violaciones(viol_a[32*k +: 32]), .n_clks_ultima(clks_a[32*k +: 32])
            );
            modelo_max7219 ub (
                .din((k == 0) ? din_b : dout_b[(k == 0) ? 0 : k - 1]),
                .clk(clk_b), .load(load_b), .dout(dout_b[k]),
                .digitos(dig_b[64*k +: 64]), .config_regs(conf_regs_b[40*k +: 40]),
                .n_violaciones(viol_b[32*k +: 32]), .n_clks_ultima()
            );
        end
    endgenerate

    // Vigilamos que cada transferencia tenga exactamente 16·N bits
    integer cargas_malas = 0, cargas = 0;
    always @(posedge load_a) begin
        #1;
        cargas = cargas + 1;
        if (clks_a[31:0] != 16 * N_CHIPS && cargas > 1) cargas_malas = cargas_malas + 1;
    end

    // ------------------------------------------------------------------
    // Reconstrucción de la pantalla a partir de los registros de los chips
    // ------------------------------------------------------------------
    function [NB-1:0] pantalla;
        input [64*N_CHIPS-1:0] dig;
        input                  cercano_derecha;
        integer f, c, m, p;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < ANCHO; c = c + 1) begin
                    m = c / 8;
                    p = cercano_derecha ? (N_CHIPS - 1 - m) : m;   // posición en la cadena
                    pantalla[f*ANCHO + c] = dig[64*p + 8*f + (7 - (c % 8))];
                end
        end
    endfunction

    function integer suma32;
        input [32*N_CHIPS-1:0] v;
        integer i;
        begin
            suma32 = 0;
            for (i = 0; i < N_CHIPS; i = i + 1) suma32 = suma32 + v[32*i +: 32];
        end
    endfunction

    task imprimir;
        input [NB-1:0] im;
        integer f, c;
        reg [8*ANCHO-1:0] linea;
        begin
            for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = "-";
            $display("   +%s+", linea);
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = im[f*ANCHO + c] ? "O" : ".";
                $display("   |%s|", linea);
            end
            for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = "-";
            $display("   +%s+", linea);
        end
    endtask

    task esperar_tramas;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk); while (!trama_a) @(posedge clk);
            end
            // damos tiempo a que la cadena B también termine su pantalla
            @(posedge clk); while (!trama_b) @(posedge clk);
            @(posedge clk); while (!trama_b) @(posedge clk);
        end
    endtask

    task probar_patron;
        input [NB-1:0] patron;
        input [8*24-1:0] nombre;
        begin
            img_prueba = patron;
            esperar_tramas(2);
            `VERIFICAR(pantalla(dig_a, 0) == patron, $sformatf("cadena A, patron %0s", nombre))
            `VERIFICAR(pantalla(dig_b, 1) == patron, $sformatf("cadena B, patron %0s", nombre))
        end
    endtask

    integer f, c, i, t0, t_trama;
    reg [NB-1:0] p;
    reg [39:0]   cfg;

    initial begin
        $dumpfile("sim/tb_max7219.vcd");
        $dumpvars(0, tb_max7219);
        $display("== tb_max7219: %0d chips en cascada ==", N_CHIPS);

        img_prueba = {NB{1'b0}};
        repeat (5) @(posedge clk);
        rst = 0;

        // 1. Configuración en todos los chips de las dos cadenas
        @(posedge clk); while (!conf_a) @(posedge clk);
        @(posedge clk); while (!conf_b) @(posedge clk);
        #1;
        for (i = 0; i < N_CHIPS; i = i + 1) begin
            cfg = conf_regs_a[40*i +: 40];
            `VERIFICAR(cfg == {8'h00, 8'h07, 8'h00, 8'h04, 8'h01},
                       $sformatf("configuracion del chip %0d (cadena A) = %h", i, cfg))
            `VERIFICAR(conf_regs_b[40*i +: 40] == {8'h00, 8'h07, 8'h00, 8'h04, 8'h01},
                       $sformatf("configuracion del chip %0d (cadena B)", i))
        end
        cfg = conf_regs_a[40*(N_CHIPS-1) +: 40];
        $display("  configuracion recibida por el chip mas lejano: test=%h scan=%h decode=%h brillo=%h shutdown=%h",
                 cfg[39:32], cfg[31:24], cfg[23:16], cfg[15:8], cfg[7:0]);

        // Duración de una pantalla
        @(posedge clk); while (!trama_a) @(posedge clk);
        t0 = $time;
        @(posedge clk); while (!trama_a) @(posedge clk);
        t_trama = $time - t0;
        $display("  una pantalla completa tarda %0d us (%0d refrescos por segundo)",
                 t_trama / 1000, 1_000_000_000 / t_trama);

        // 3. Patrones conocidos
        probar_patron({NB{1'b1}}, "todo encendido");
        for (f = 0; f < 8; f = f + 1) for (c = 0; c < ANCHO; c = c + 1) p[f*ANCHO + c] = (f + c) % 2;
        probar_patron(p, "ajedrez");
        p = 0;
        for (f = 0; f < 8; f = f + 1) for (c = 0; c < ANCHO; c = c + 1)
            if (c / (ANCHO / 8) == f) p[f*ANCHO + c] = 1;
        for (c = 0; c < ANCHO; c = c + 1) begin p[c] = 1; p[7*ANCHO + c] = 1; end
        probar_patron(p, "diagonal y bordes");
        $display("  Patron 'diagonal y bordes' reconstruido desde los registros de los %0d chips:", N_CHIPS);
        imprimir(pantalla(dig_a, 0));
        // Un LED distinto por matriz: si el orden de la cadena estuviera mal, aquí se nota
        p = 0;
        for (i = 0; i < N_CHIPS; i = i + 1) p[i*ANCHO + i*8 + i] = 1;
        probar_patron(p, "un LED por matriz");
        for (i = 0; i < N_CHIPS * 2; i = i + 1) p[32*i +: 32] = $random;
        probar_patron(p, "aleatorio");

        // 5. Simulamos que el chip más lejano se reinicia por un pico en la alimentación
        g_chip[N_CHIPS-1].ua.reg_shutdown = 8'h00;
        g_chip[N_CHIPS-1].ua.reg_scan     = 8'h00;
        #1;
        `VERIFICAR(conf_regs_a[40*(N_CHIPS-1) +: 8] == 8'h00, "no logramos simular el reinicio del chip")
        esperar_tramas(6);   // con REINIT_TRAMAS = 4 ya debió reconfigurarse
        `VERIFICAR(conf_regs_a[40*(N_CHIPS-1) +: 40] == {8'h00, 8'h07, 8'h00, 8'h04, 8'h01},
                   "el chip no se recupero con la reconfiguracion")
        `VERIFICAR(pantalla(dig_a, 0) == p, "la imagen no volvio despues de la reconfiguracion")

        // 2 y 4. Resumen de tiempos y longitudes
        $display("  transferencias revisadas: %0d, con longitud distinta de %0d bits: %0d",
                 cargas, 16 * N_CHIPS, cargas_malas);
        `VERIFICAR(cargas_malas == 0, "hubo transferencias con una longitud incorrecta")
        `VERIFICAR(suma32(viol_a) + suma32(viol_b) == 0, "se violaron tiempos de la hoja de datos")
        $display("  violaciones de tiempo detectadas por los modelos: %0d", suma32(viol_a) + suma32(viol_b));

        reporte_final("tb_max7219");
        $finish;
    end

endmodule
