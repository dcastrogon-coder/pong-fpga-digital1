// ============================================================================
//  tb_etapa1.v  -  Simulación de la etapa 1 (pantalla)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Le colgamos a la FPGA simulada cuatro modelos de MAX7219 en cadena, igual
//  que el módulo x4, y "miramos" la pantalla leyendo los registros de los
//  cuatro chips. Revisamos:
//
//   1. que los cuatro chips queden configurados (test apagado, 8 filas,
//      sin decodificación BCD, brillo 4, encendidos);
//   2. que en cada paso se vea UN solo LED y justo donde debe estar, durante
//      una vuelta completa a la pantalla (256 pasos) y un poco más, para ver
//      que al final vuelve a la esquina;
//   3. que cada transferencia tenga exactamente 64 bits (4 chips x 16);
//   4. que el RESET devuelva el punto a la esquina;
//   5. que con el DIP SW2 se vea el patrón de calibración;
//   6. que no se viole ningún tiempo de la hoja de datos del MAX7219;
//   7. que las ecuaciones de estado siguiente que sacamos a mano para la
//      FSM del transmisor den, ciclo a ciclo, lo mismo que el circuito.
//
//  Truco para que corra rápido: le decimos al diseño que el reloj es de
//  2 MHz y ponemos DIV_CLK_LED = 1. Así CLK_LED queda en 1 MHz, igualito que
//  en la tarjeta (50 MHz / 50), y los tiempos de las ondas son los reales.
//  El script corre_etapa1.sh lo corre dos veces: con DIV_PRUEBA = 1 y 2.
// ============================================================================

`timescale 1ns / 1ps

module tb_etapa1;

    // DIV_PRUEBA = 1: reloj de 2 MHz y DIV_CLK_LED = 1 (corrida rápida).
    // DIV_PRUEBA = 2: reloj de 4 MHz y DIV_CLK_LED = 2. CLK_LED sigue en
    // 1 MHz, pero ahora la FSM sí se queda varios ciclos en cada estado, así
    // que también se prueban los lazos T' de las ecuaciones.
    `ifndef DIV_PRUEBA
      `define DIV_PRUEBA 1
    `endif
    localparam integer DIV     = `DIV_PRUEBA;
    localparam integer CLK_HZ  = 2_000_000 * DIV;
    localparam integer PASO_MS = 5;

    integer errores = 0, pruebas = 0;
    `define VERIFICAR(cond, msg) \
        begin pruebas = pruebas + 1; \
            if ((cond) !== 1'b1) begin errores = errores + 1; \
                if (errores <= 20) $display("  [FALLA] t=%0t : %0s", $time, msg); end end

    reg clk = 0;
    always #(250.0 / DIV) clk = ~clk;    // 2 MHz x DIV

    reg reset_n = 1, sw_prueba_n = 1;    // pulsador y DIP: 1 = suelto / OFF
    wire din, sclk, load, latido;

    etapa1_pantalla #(.CLK_HZ(CLK_HZ), .PASO_MS(PASO_MS), .DIV_CLK_LED(DIV)) dut (
        .CLK_SYS(clk), .RESET_PIN(reset_n), .SW_PRUEBA(sw_prueba_n),
        .DIN(din), .CLK_LED(sclk), .LOAD(load), .LED_LATIDO(latido)
    );

    // ---------------- Cuatro MAX7219 en cadena (módulo x4) ----------------
    wire [3:0]   dout;
    wire [255:0] dig;
    wire [159:0] conf;
    wire [127:0] viol, clks;
    genvar k;
    generate
        for (k = 0; k < 4; k = k + 1) begin : g_chip
            modelo_max7219 u (
                .din((k == 0) ? din : dout[(k == 0) ? 0 : k - 1]),
                .clk(sclk), .load(load), .dout(dout[k]),
                .digitos(dig[64*k +: 64]), .config_regs(conf[40*k +: 40]),
                .n_violaciones(viol[32*k +: 32]), .n_clks_ultima(clks[32*k +: 32])
            );
        end
    endgenerate

    // Pantalla 8 x 32 armada con los registros de los 4 chips
    function [255:0] pantalla;
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 32; c = c + 1)
                    pantalla[f*32 + c] = dig[64*(c / 8) + 8*f + (7 - (c % 8))];
        end
    endfunction

    function [255:0] un_punto;
        input integer x, y;
        begin
            un_punto = 256'd0;
            un_punto[y*32 + x] = 1'b1;
        end
    endfunction

    function [255:0] patron_calibracion;
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 32; c = c + 1)
                    patron_calibracion[f*32 + c] = (f == 0 && (c % 8) <= (c / 8) + 1) || ((c % 8) == 0 && f <= 2);
        end
    endfunction

    task imprimir;
        input [255:0] im;
        integer f, c;
        reg [8*32-1:0] linea;
        begin
            $display("   +--------+--------+--------+--------+");
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < 32; c = c + 1) linea[(31 - c)*8 +: 8] = im[f*32 + c] ? "O" : ".";
                $display("   |%s|%s|%s|%s|", linea[255:192], linea[191:128], linea[127:64], linea[63:0]);
            end
            $display("   +--------+--------+--------+--------+");
        end
    endtask

    // Guardamos algunas pantallas para dibujarlas después en Python
    integer archivo;
    task guardar;
        input [255:0] im;
        input [8*40-1:0] titulo;
        integer i;
        begin
            $fwrite(archivo, "%0s;", titulo);
            for (i = 0; i < 256; i = i + 1) $fwrite(archivo, "%0d", im[i]);
            $fwrite(archivo, "\n");
        end
    endtask

    // Longitud de cada transferencia (CLK entre dos LOAD)
    integer cargas = 0, cargas_malas = 0;
    always @(posedge load) begin
        #1;
        cargas = cargas + 1;
        if (cargas > 1 && clks[31:0] != 64) cargas_malas = cargas_malas + 1;
    end

    // ------------------------------------------------------------------
    // Comprobación de las ecuaciones de la FSM del transmisor.
    // En cada flanco calculamos T y U igual que en la tabla de la guía,
    // aplicamos las ecuaciones de estado siguiente que sacamos por mapas de
    // Karnaugh y, en el flanco siguiente, miramos si el estado real del
    // circuito es el mismo. Si coinciden siempre, la tabla y las ecuaciones
    // describen exactamente lo que hace el Verilog.
    // ------------------------------------------------------------------
    function [2:0] siguiente_por_ecuaciones;
        input [2:0] q;
        input t, u;
        reg q2, q1, q0;
        begin
            {q2, q1, q0} = q;
            siguiente_por_ecuaciones[2] = (q2 & ~q1 & ~q0) | (q2 & ~q1 & ~t) | (~q2 & q1 & q0 & t);
            siguiente_por_ecuaciones[1] = (~q2 & q1 & ~t) | (~q2 & ~q1 & q0 & t) | (~q2 & q1 & ~q0 & u);
            siguiente_por_ecuaciones[0] = (~q1 & q0 & ~t) | (~q2 & q0 & ~t) | (~q1 & ~q0 & t)
                                        | (~q2 & ~q0 & t) | (~q2 & ~q1 & ~q0);
        end
    endfunction

    reg  [2:0] predicho;
    reg        hay_prediccion = 0;
    integer    fsm_revisados = 0, fsm_distintos = 0;
    wire       t_actual = (dut.u_tx.estado == 3'd4) ? (dut.u_tx.div >= 2*DIV - 1) : (dut.u_tx.div >= DIV - 1);
    wire       u_actual = (dut.u_tx.bits == 8'd1);

    always @(posedge clk) begin
        if (hay_prediccion && !dut.por) begin
            fsm_revisados = fsm_revisados + 1;
            if (dut.u_tx.estado !== predicho) fsm_distintos = fsm_distintos + 1;
        end
        predicho       = siguiente_por_ecuaciones(dut.u_tx.estado, t_actual, u_actual);
        hay_prediccion = !dut.por;
    end

    task esperar_pantallas;   // espera n pantallas completas
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk); while (dut.u_tx.trama_fin !== 1'b1) @(posedge clk);
            end
            #1;
        end
    endtask

    task esperar_paso;
        begin
            @(posedge clk); while (dut.tick_paso !== 1'b1) @(posedge clk);
        end
    endtask

    task esperar_ms;
        input integer ms;
        begin repeat (ms * (CLK_HZ / 1000)) @(posedge clk); end
    endtask

    integer paso, x_esp, y_esp, i, malos;
    reg [39:0] cfg;
    reg [255:0] scr;
    reg [8*40-1:0] titulo;

    initial begin
        $display("== tb_etapa1: punto que recorre la pantalla 8 x 32 ==");
        archivo = $fopen((DIV == 1) ? "sim/pantallas_etapa1.txt" : "sim/pantallas_etapa1_div2.txt", "w");

        // Guardamos en el VCD solo una ventana corta (una pantalla completa)
        if (DIV == 1) $dumpfile("sim/tb_etapa1.vcd");
        else          $dumpfile("sim/tb_etapa1_div2.vcd");
        $dumpvars(0, dut.u_tx.estado, dut.u_tx.idx, dut.u_tx.bits,
                     dut.u_tx.din, dut.u_tx.clk_led, dut.u_tx.load, dut.pos);
        $dumpoff;

        // ---- 1. Configuración ----
        // Ojo: comparamos con !== 1 porque al arrancar la simulación las
        // señales valen X, y un while (!senal) con X se sale de una vez.
        // Prendemos la grabación desde la última palabra de configuración
        // (idx = 4, salir de shutdown) para que se vea completa la CARGA de la
        // primera palabra de imagen. Grabamos hasta terminar esa pantalla.
        @(posedge clk); while (dut.u_tx.idx !== 4'd4) @(posedge clk);
        $dumpon;
        @(posedge clk); while (dut.u_tx.config_fin !== 1'b1) @(posedge clk);
        #1;
        for (i = 0; i < 4; i = i + 1) begin
            cfg = conf[40*i +: 40];
            `VERIFICAR(cfg == {8'h00, 8'h07, 8'h00, 8'h04, 8'h01},
                       $sformatf("configuracion del chip %0d = %h", i, cfg))
        end
        $display("  los 4 chips quedaron configurados (test=00 scan=07 decode=00 brillo=04 shutdown=01)");
        esperar_pantallas(1);
        $dumpoff;

        // ---- 2. Recorrido completo ----
        malos = 0;
        for (paso = 0; paso < 260; paso = paso + 1) begin
            esperar_pantallas(2);
            x_esp = paso % 32;
            y_esp = (paso / 32) % 8;
            scr = pantalla(0);
            if (scr !== un_punto(x_esp, y_esp)) begin
                malos = malos + 1;
                if (malos <= 5) begin
                    $display("  [FALLA] paso %0d: se esperaba el punto en (X=%0d, Y=%0d) y se ve:", paso, x_esp, y_esp);
                    imprimir(scr);
                end
            end
            pruebas = pruebas + 1;
            if (paso == 0 || paso == 9 || paso == 45 || paso == 255) begin
                $sformat(titulo, "Paso %0d: X=%0d, Y=%0d", paso, x_esp, y_esp);
                guardar(scr, titulo);
            end
            if (paso == 45) begin
                $display("  Pantalla en el paso 45 (X=13, Y=1), leída de los registros de los 4 chips:");
                imprimir(scr);
            end
            esperar_paso;
        end
        errores = errores + malos;
        $display("  recorrido: %0d pasos revisados, %0d con la pantalla equivocada", paso, malos);

        // ---- 4. RESET a mitad de camino ----
        esperar_ms(3 * PASO_MS);
        reset_n = 0; esperar_ms(15); reset_n = 1;
        esperar_ms(1);
        `VERIFICAR(dut.pos == 8'd0 || dut.pos == 8'd1, $sformatf("RESET no devolvio el punto a la esquina (pos=%0d)", dut.pos))

        // ---- 5. Patrón de calibración con el DIP ----
        sw_prueba_n = 0;
        esperar_pantallas(3);
        scr = pantalla(0);
        `VERIFICAR(scr == patron_calibracion(0), "el DIP SW2 no muestra el patron de calibracion")
        $display("  Patrón de calibración (DIP SW2 en ON):");
        imprimir(scr);
        guardar(scr, "Calibracion (SW2 en ON)");   // sin tildes: el archivo lo lee Python
        sw_prueba_n = 1;

        // ---- 7. Ecuaciones de la FSM contra el circuito ----
        `VERIFICAR(fsm_distintos == 0, "las ecuaciones de la FSM no coinciden con el circuito")
        $display("  ecuaciones de la FSM: %0d ciclos revisados, %0d diferencias con el circuito",
                 fsm_revisados, fsm_distintos);

        // ---- 3 y 6. Longitud de tramas y tiempos ----
        `VERIFICAR(cargas_malas == 0, "hubo transferencias de longitud distinta a 64 bits")
        `VERIFICAR(viol == 128'd0, "el modelo detecto violaciones de tiempo")
        $display("  transferencias revisadas: %0d (todas de 64 bits: %s)", cargas, cargas_malas == 0 ? "si" : "no");
        $display("  violaciones de tiempo del MAX7219: %0d", viol[31:0] + viol[63:32] + viol[95:64] + viol[127:96]);

        $fclose(archivo);
        $display("------------------------------------------------------------");
        if (errores == 0) $display("RESULTADO tb_etapa1: PASA (%0d verificaciones)", pruebas);
        else              $display("RESULTADO tb_etapa1: FALLA (%0d errores en %0d verificaciones)", errores, pruebas);
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule
