// ============================================================================
//  tb_sonido.v  -  Pitidos del buzzer
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Medimos la frecuencia y la duración de cada sonido directamente sobre la
//  salida del buzzer, y revisamos las prioridades: un rebote no debe
//  interrumpir el sonido del gol, pero el fin de partida sí lo interrumpe.
//  Usamos un reloj de 1 MHz para leer los tiempos en microsegundos.
// ============================================================================

`timescale 1ns / 1ps

module tb_sonido;

    `include "tb_comun.vh"

    localparam integer CLK_HZ = 1_000_000;

    reg clk = 0, rst = 1, tick_1ms = 0, hab = 1;
    reg ev_pared = 0, ev_paleta = 0, ev_gol = 0, ev_fin = 0;
    wire buzzer, sonando;

    always #500 clk = ~clk;

    integer c = 0;
    always @(posedge clk) begin
        c <= (c == 999) ? 0 : c + 1;
        tick_1ms <= (c == 999);
    end

    sonido #(.CLK_HZ(CLK_HZ), .BUZZER_ACTIVO_BAJO(1)) dut (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms), .habilitar(hab),
        .ev_pared(ev_pared), .ev_paleta(ev_paleta), .ev_gol(ev_gol), .ev_fin(ev_fin),
        .buzzer(buzzer), .sonando(sonando)
    );

    wire activo = ~buzzer;   // el buzzer es activo en bajo

    // Mide: frecuencia promedio (por los flancos de subida) y duración del sonido
    integer flancos, t_ini, t_fin, t_primero, t_ultimo, ciclo = 0;
    reg     activo_ant = 0;
    always @(posedge clk) begin
        ciclo = ciclo + 1;
        if (activo && !activo_ant) begin
            if (flancos == 0) t_primero = ciclo;
            t_ultimo = ciclo;
            flancos = flancos + 1;
        end
        activo_ant <= activo;
    end

    task pulso;
        input integer cual;   // 0 pared, 1 paleta, 2 gol, 3 fin
        begin
            @(negedge clk);
            case (cual) 0: ev_pared = 1; 1: ev_paleta = 1; 2: ev_gol = 1; default: ev_fin = 1; endcase
            @(negedge clk);
            ev_pared = 0; ev_paleta = 0; ev_gol = 0; ev_fin = 0;
        end
    endtask

    task medir_sonido;
        input integer cual;
        input integer f_esperada;
        input integer ms_esperados;
        input [8*12-1:0] nombre;
        integer f_medida, ms_medidos;
        begin
            flancos = 0;
            pulso(cual);
            t_ini = ciclo;
            @(posedge clk); while (sonando) @(posedge clk);
            t_fin = ciclo;
            ms_medidos = (t_fin - t_ini) / 1000;
            f_medida = (flancos > 1) ? ((flancos - 1) * 1_000_000) / (t_ultimo - t_primero) : 0;
            $display("  %0s: %0d Hz durante %0d ms (esperado %0d Hz, %0d ms)",
                     nombre, f_medida, ms_medidos, f_esperada, ms_esperados);
            `VERIFICAR(f_medida >= f_esperada * 98 / 100 && f_medida <= f_esperada * 102 / 100,
                       $sformatf("%0s: frecuencia %0d Hz", nombre, f_medida))
            `VERIFICAR(ms_medidos >= ms_esperados - 1 && ms_medidos <= ms_esperados + 1,
                       $sformatf("%0s: duracion %0d ms", nombre, ms_medidos))
            repeat (2000) @(posedge clk);
        end
    endtask

    integer f_primera;

    initial begin
        $display("== tb_sonido ==");
        repeat (5) @(negedge clk);
        rst = 0;
        repeat (100) @(negedge clk);
        `VERIFICAR(buzzer === 1'b1, "el buzzer no esta en reposo (1 con activo en bajo)")

        medir_sonido(0, 1760, 25,  "pared");
        medir_sonido(1, 880,  50,  "paleta");
        medir_sonido(2, 220,  400, "gol");

        // Melodía de fin: 4 notas de 120 ms. Medimos la duración total
        // y la frecuencia de la primera nota.
        flancos = 0;
        pulso(3);
        t_ini = ciclo;
        repeat (110_000) @(posedge clk);
        f_primera = ((flancos - 1) * 1_000_000) / (t_ultimo - t_primero);
        @(posedge clk); while (sonando) @(posedge clk);
        $display("  fin: primera nota de %0d Hz, melodia de %0d ms", f_primera, (ciclo - t_ini) / 1000);
        `VERIFICAR(f_primera >= 512 && f_primera <= 534, $sformatf("primera nota %0d Hz", f_primera))
        `VERIFICAR((ciclo - t_ini) / 1000 >= 479 && (ciclo - t_ini) / 1000 <= 481, "duracion de la melodia")
        repeat (2000) @(posedge clk);

        // Prioridades: un rebote durante el gol no lo corta
        pulso(2);
        repeat (100_000) @(posedge clk);
        pulso(1);
        repeat (10) @(posedge clk);
        `VERIFICAR(dut.prioridad == 3, "un rebote interrumpio el sonido del gol")
        // ...pero el fin de partida sí
        pulso(3);
        repeat (10) @(posedge clk);
        `VERIFICAR(dut.prioridad == 4, "el fin de partida no interrumpio el gol")
        @(posedge clk); while (sonando) @(posedge clk);

        // Con el interruptor apagado no sale nada
        hab = 0;
        flancos = 0;
        pulso(2);
        repeat (450_000) @(posedge clk);
        `VERIFICAR(flancos == 0 && buzzer === 1'b1, "el buzzer sono con el interruptor apagado")

        reporte_final("tb_sonido");
        $finish;
    end

endmodule
