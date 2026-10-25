// ============================================================================
//  tb_max7219.v  -  Prueba T08
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Conectamos nuestro transmisor a DOS modelos de MAX7219 en cadena, igual
//  que en el montaje:
//
//      FPGA DIN --> [U1 cercano] DOUT --> DIN [U2 lejano]
//      CLK_LED y LOAD van en paralelo a los dos chips
//
//  y comprobamos que:
//   1. la configuración (test, scan limit, decode, brillo, shutdown) llega
//      igual a los dos chips;
//   2. entre dos flancos de LOAD hay exactamente 32 flancos de CLK;
//   3. con varios patrones conocidos, los registros reconstruidos de U1 y U2
//      forman exactamente la imagen de 128 LEDs que pedimos;
//   4. no se viola ningún tiempo mínimo de la hoja de datos;
//   5. si un chip "se reinicia" por ruido, la reconfiguración periódica lo
//      recupera;
//   6. el parámetro MODULO_CERCANO realmente intercambia los módulos.
//  Usamos el reloj real de 50 MHz y DIV_CLK = 25 (CLK_LED de 1 MHz).
// ============================================================================

`timescale 1ns / 1ps

module tb_max7219;

    `include "tb_comun.vh"

    reg clk = 0, rst = 1;
    always #10 clk = ~clk;   // 50 MHz

    reg  [127:0] img_prueba;
    wire [127:0] bytes_prueba;

    // Los bytes los armamos con el mismo módulo imagen.v (orientación por
    // defecto) para que la prueba recorra el camino real img -> bytes -> serie.
    // Como imagen.v pinta escenas del juego, aquí metemos el patrón por la
    // función "mapa" que replica el mapeo por defecto, ya verificado en tb_imagen.
    function [127:0] mapa;
        input [127:0] im;
        integer m, d, b;
        begin
            for (m = 0; m < 2; m = m + 1)
                for (d = 0; d < 8; d = d + 1)
                    for (b = 0; b < 8; b = b + 1)
                        mapa[(m*8 + d)*8 + b] = im[d*16 + m*8 + (7 - b)];
        end
    endfunction
    assign bytes_prueba = mapa(img_prueba);

    // ---------------- Cadena A: módulo izquierdo cercano ----------------
    wire din_a, clk_a, load_a, trama_a, conf_a, dout_a1, dout_a2;

    max7219_tx #(.DIV_CLK(25), .MODULO_CERCANO(0), .REINIT_TRAMAS(4)) dut_a (
        .clk(clk), .rst(rst), .bytes(bytes_prueba),
        .din(din_a), .clk_led(clk_a), .load(load_a),
        .trama_fin(trama_a), .config_fin(conf_a)
    );
    modelo_max7219 u1 (.din(din_a),   .clk(clk_a), .load(load_a), .dout(dout_a1));
    modelo_max7219 u2 (.din(dout_a1), .clk(clk_a), .load(load_a), .dout(dout_a2));

    // ---------------- Cadena B: módulo derecho cercano ----------------
    wire din_b, clk_b, load_b, trama_b, conf_b, dout_b1, dout_b2;

    max7219_tx #(.DIV_CLK(25), .MODULO_CERCANO(1), .REINIT_TRAMAS(4)) dut_b (
        .clk(clk), .rst(rst), .bytes(bytes_prueba),
        .din(din_b), .clk_led(clk_b), .load(load_b),
        .trama_fin(trama_b), .config_fin(conf_b)
    );
    modelo_max7219 v1 (.din(din_b),   .clk(clk_b), .load(load_b), .dout(dout_b1));
    modelo_max7219 v2 (.din(dout_b1), .clk(clk_b), .load(load_b), .dout(dout_b2));

    // Vigilamos que cada transferencia tenga exactamente 32 bits
    integer cargas_malas = 0, cargas = 0;
    always @(posedge load_a) begin
        #1;
        cargas = cargas + 1;
        if (u1.clks_ultima != 32 && cargas > 1) cargas_malas = cargas_malas + 1;
    end

    // ------------------------------------------------------------------
    // Reconstrucción de la pantalla a partir de los registros de los chips
    // ------------------------------------------------------------------
    function [127:0] pantalla_a;   // U1 = mitad izquierda, U2 = mitad derecha
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 16; c = c + 1)
                    pantalla_a[f*16 + c] = (c < 8) ? u1.digito[f+1][7 - c] : u2.digito[f+1][7 - (c - 8)];
        end
    endfunction

    function [127:0] pantalla_b;   // V1 = mitad derecha, V2 = mitad izquierda
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 16; c = c + 1)
                    pantalla_b[f*16 + c] = (c < 8) ? v2.digito[f+1][7 - c] : v1.digito[f+1][7 - (c - 8)];
        end
    endfunction

    task imprimir;
        input [127:0] im;
        integer f, c;
        reg [8*16-1:0] linea;
        begin
            $display("   +----------------+");
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < 16; c = c + 1) linea[(15 - c)*8 +: 8] = im[f*16 + c] ? "O" : ".";
                $display("   |%s|", linea);
            end
            $display("   +----------------+");
        end
    endtask

    task esperar_tramas;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(posedge clk); while (!trama_a) @(posedge clk);
            end
            // damos tiempo a que la cadena B también termine su pantalla
            @(posedge clk); while (!trama_b) @(posedge clk);
            @(posedge clk); while (!trama_b) @(posedge clk);
        end
    endtask

    task probar_patron;
        input [127:0] patron;
        input [8*24-1:0] nombre;
        begin
            img_prueba = patron;
            esperar_tramas(2);
            `VERIFICAR(pantalla_a(0) == patron, $sformatf("cadena A, patron %0s", nombre))
            `VERIFICAR(pantalla_b(0) == patron, $sformatf("cadena B, patron %0s", nombre))
        end
    endtask

    integer f, c, c0, ciclos_trama;
    reg [127:0] p;

    initial begin
        $dumpfile("sim/tb_max7219.vcd");
        $dumpvars(0, tb_max7219);
        $display("== tb_max7219 ==");

        img_prueba = 128'd0;
        repeat (5) @(posedge clk);
        rst = 0;

        // 1. Configuración
        @(posedge clk); while (!conf_a) @(posedge clk);
        #1;
        `VERIFICAR(u1.reg_test == 8'h00 && u2.reg_test == 8'h00, "display test apagado")
        `VERIFICAR(u1.reg_scan == 8'h07 && u2.reg_scan == 8'h07, "scan limit = 7")
        `VERIFICAR(u1.reg_decode == 8'h00 && u2.reg_decode == 8'h00, "sin decodificacion BCD")
        `VERIFICAR(u1.reg_brillo == 8'h04 && u2.reg_brillo == 8'h04, "brillo")
        `VERIFICAR(u1.operando && u2.operando, "los chips no salieron de shutdown")
        $display("  configuracion recibida por U1 y U2: test=%h scan=%h decode=%h brillo=%h shutdown=%h",
                 u1.reg_test, u1.reg_scan, u1.reg_decode, u1.reg_brillo, u1.reg_shutdown);

        // Duración de una pantalla
        @(posedge clk); while (!trama_a) @(posedge clk);
        c0 = $time;
        @(posedge clk); while (!trama_a) @(posedge clk);
        ciclos_trama = ($time - c0);
        $display("  una pantalla completa tarda %0d us (%0d refrescos por segundo)",
                 ciclos_trama / 1000, 1_000_000_000 / ciclos_trama);

        // 3. Patrones conocidos
        probar_patron({128{1'b1}}, "todo encendido");
        for (f = 0; f < 8; f = f + 1) for (c = 0; c < 16; c = c + 1) p[f*16 + c] = (f + c) % 2;
        probar_patron(p, "ajedrez");
        p = 0;
        for (f = 0; f < 8; f = f + 1) begin p[f*16 + 2*f] = 1; p[f*16 + 2*f + 1] = 1; end
        for (c = 0; c < 16; c = c + 1) begin p[c] = 1; p[7*16 + c] = 1; end
        probar_patron(p, "diagonal y bordes");
        $display("  Patron 'diagonal y bordes' reconstruido desde los registros de U1/U2:");
        imprimir(pantalla_a(0));
        p = 0; p[0] = 1; p[15] = 1; p[7*16] = 1; p[7*16 + 15] = 1; p[3*16 + 7] = 1; p[4*16 + 8] = 1;
        probar_patron(p, "esquinas y centro");
        for (f = 0; f < 4; f = f + 1) p = {$random, $random, $random, $random};
        probar_patron(p, "aleatorio");

        // 5. Simulamos que U2 se reinicia por un pico en la alimentación
        u2.reg_shutdown = 8'h00;
        u2.reg_scan     = 8'h00;
        #1;
        `VERIFICAR(!u2.operando, "no logramos simular el reinicio de U2")
        esperar_tramas(6);   // con REINIT_TRAMAS = 4 ya debió reconfigurarse
        `VERIFICAR(u2.operando && u2.reg_scan == 8'h07, "U2 no se recupero con la reconfiguracion")
        `VERIFICAR(pantalla_a(0) == p, "la imagen no volvio despues de la reconfiguracion")

        // 2 y 4. Resumen de tiempos y longitudes
        $display("  transferencias revisadas: %0d, con longitud distinta de 32 bits: %0d", cargas, cargas_malas);
        `VERIFICAR(cargas_malas == 0, "hubo transferencias de longitud distinta a 32 bits")
        `VERIFICAR(u1.violaciones + u2.violaciones + v1.violaciones + v2.violaciones == 0,
                   "se violaron tiempos de la hoja de datos")
        $display("  violaciones de tiempo detectadas por los modelos: %0d",
                 u1.violaciones + u2.violaciones + v1.violaciones + v2.violaciones);

        reporte_final("tb_max7219");
        $finish;
    end

endmodule
