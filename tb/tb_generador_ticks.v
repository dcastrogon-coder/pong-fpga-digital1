// ============================================================================
//  tb_generador_ticks.v  -  Bases de tiempo (apoya T03)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Medimos los periodos reales de los pulsos. Para que la simulación sea
//  rápida le decimos al módulo que el reloj es de 10 kHz (10 ciclos por ms);
//  como todo está escrito en función de CLK_HZ, si funciona aquí funciona a
//  50 MHz con la misma lógica.
// ============================================================================

`timescale 1ns / 1ps

module tb_generador_ticks;

    `include "tb_comun.vh"

    localparam integer CLK_HZ = 10_000;
    localparam integer CMS    = CLK_HZ / 1000;

    reg clk = 0, rst = 1, sinc = 0;
    reg [1:0] nivel = 0;
    wire t1, t_bola, parp;

    always #50 clk = ~clk;   // el periodo de simulación no importa, contamos ciclos

    generador_ticks #(.CLK_HZ(CLK_HZ)) dut (
        .clk(clk), .rst(rst), .nivel(nivel), .sincronizar(sinc),
        .tick_1ms(t1), .tick_bola(t_bola), .parpadeo(parp)
    );

    integer ciclo = 0;
    always @(posedge clk) ciclo <= ciclo + 1;

    // Esperan el siguiente pulso (Icarus no soporta "iff" en el evento)
    task esperar_t1; begin @(posedge clk); while (!t1) @(posedge clk); end endtask
    task esperar_tb; begin @(posedge clk); while (!t_bola) @(posedge clk); end endtask

    // Mide el periodo entre dos pulsos de la señal indicada
    task medir;
        input integer cual;     // 0 = tick_1ms, 1 = tick_bola
        output integer periodo;
        integer c0;
        begin
            if (cual == 0) begin esperar_t1; c0 = ciclo; esperar_t1; end
            else           begin esperar_tb; c0 = ciclo; esperar_tb; end
            periodo = ciclo - c0;
        end
    endtask

    // Ancho de los pulsos: siempre un solo ciclo
    reg t1_ant = 0, tbola_ant = 0;
    always @(posedge clk) begin
        if (t1 && t1_ant) begin errores = errores + 1; $display("  [FALLA] tick_1ms de dos ciclos"); end
        if (t_bola && tbola_ant) begin errores = errores + 1; $display("  [FALLA] tick_bola de dos ciclos"); end
        t1_ant <= t1; tbola_ant <= t_bola;
    end

    integer p, n, esperado;
    integer periodos [0:3];
    integer c_a, c_b;

    initial begin
        $dumpfile("sim/tb_generador_ticks.vcd");
        $dumpvars(0, tb_generador_ticks);
        $display("== tb_generador_ticks ==");
        periodos[0] = 260; periodos[1] = 200; periodos[2] = 150; periodos[3] = 110;

        repeat (3) @(negedge clk);
        rst = 0;

        medir(0, p);
        `VERIFICAR(p == CMS, $sformatf("periodo de tick_1ms = %0d ciclos", p))

        for (n = 0; n < 4; n = n + 1) begin
            nivel = n;
            medir(1, p);      // el primero puede venir de la configuración anterior
            medir(1, p);
            esperado = periodos[n] * CMS;
            $display("  nivel %0d: tick_bola cada %0d ms", n, p / CMS);
            `VERIFICAR(p == esperado, $sformatf("nivel %0d: %0d ciclos, se esperaban %0d", n, p, esperado))
        end

        // sincronizar mantiene el contador en cero: no sale ningún tick_bola
        nivel = 3;
        @(negedge clk) sinc = 1;
        begin : sin_ticks
            integer hubo;
            hubo = 0;
            repeat (200 * CMS) @(posedge clk) if (t_bola) hubo = 1;
            `VERIFICAR(!hubo, "salio tick_bola con sincronizar = 1")
        end
        // Al soltar, el primer tick llega exactamente un periodo después
        @(negedge clk) sinc = 0;
        c_a = ciclo;
        esperar_tb;
        c_b = ciclo;
        `VERIFICAR((c_b - c_a) >= 110 * CMS - CMS && (c_b - c_a) <= 110 * CMS + CMS,
                   $sformatf("primer paso tras sincronizar a los %0d ciclos", c_b - c_a))

        // Parpadeo: medio periodo de 250 ms
        @(posedge parp); c_a = ciclo;
        @(negedge parp); c_b = ciclo;
        `VERIFICAR((c_b - c_a) == 250 * CMS, $sformatf("medio periodo de parpadeo = %0d ms", (c_b - c_a) / CMS))

        reporte_final("tb_generador_ticks");
        $finish;
    end

endmodule
