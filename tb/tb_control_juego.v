// ============================================================================
//  tb_control_juego.v  -  FSM general del juego (T05, T06, T09)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Recorremos la tabla de transición fila por fila. Además probamos las
//  prioridades que definimos (gol por encima de la pérdida de enlace) y que
//  la máquina se recupera si el registro de estado cae en un código que no
//  usamos (101, 110, 111). Para eso forzamos el registro desde el testbench.
// ============================================================================

`timescale 1ns / 1ps

module tb_control_juego;

    `include "tb_comun.vh"

    localparam [2:0] ESPERA = 3'b000, JUEGO = 3'b001, PUNTO = 3'b010,
                     PAUSA  = 3'b011, FIN   = 3'b100;
    localparam integer PAUSA_MS = 20;   // pausa corta para la simulación

    reg clk = 0, rst = 1, tick_1ms = 0;
    reg start = 0, enlace = 1, g1 = 0, g2 = 0, gana1 = 0, gana2 = 0, rpal = 0;

    wire [2:0] estado, saque_y;
    wire [1:0] nivel;
    wire mover, contar, pal_hab, saque, saque_dx, saque_dy, limpiar, ganador;

    always #10 clk = ~clk;

    // 1 ms simulado = 10 ciclos
    integer c = 0;
    always @(posedge clk) begin
        c <= (c == 9) ? 0 : c + 1;
        tick_1ms <= (c == 9);
    end

    control_juego #(.PAUSA_PUNTO_MS(PAUSA_MS), .GOLPES_POR_NIVEL(3)) dut (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms),
        .start(start), .enlace_ok(enlace),
        .gol_j1(g1), .gol_j2(g2), .gana_j1(gana1), .gana_j2(gana2),
        .rebote_paleta(rpal),
        .estado(estado), .mover_pelota(mover), .contar(contar), .paletas_hab(pal_hab),
        .saque(saque), .saque_dx(saque_dx), .saque_dy(saque_dy), .saque_y(saque_y),
        .limpiar(limpiar), .nivel(nivel), .ganador(ganador)
    );

    // Contamos cuántos pulsos de saque y limpiar salen
    integer n_saques = 0, n_limpiar = 0;
    reg ultimo_dx;
    always @(posedge clk) begin
        if (saque)   begin n_saques  = n_saques + 1; ultimo_dx = saque_dx; end
        if (limpiar) n_limpiar = n_limpiar + 1;
    end

    task pulso_start;
        begin @(negedge clk) start = 1; @(negedge clk) start = 0; @(negedge clk); end
    endtask
    task pulso_gol;
        input jugador;
        begin
            @(negedge clk) begin g1 = (jugador == 0); g2 = (jugador == 1); end
            @(negedge clk) begin g1 = 0; g2 = 0; end
            @(negedge clk);
        end
    endtask
    task pulso_rebote;
        begin @(negedge clk) rpal = 1; @(negedge clk) rpal = 0; end
    endtask
    task esperar_ms;
        input integer ms;
        begin repeat (ms * 10) @(negedge clk); end
    endtask

    integer i, s0;

    initial begin
        $dumpfile("sim/tb_control_juego.vcd");
        $dumpvars(0, tb_control_juego);
        $display("== tb_control_juego ==");

        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        `VERIFICAR(estado == ESPERA && !mover && !contar && pal_hab, "estado inicial ESPERA")

        // ESPERA + START sin enlace -> se queda
        enlace = 0; pulso_start;
        `VERIFICAR(estado == ESPERA, "arranco sin enlace")
        enlace = 1;

        // ESPERA + START -> JUEGO
        pulso_start;
        `VERIFICAR(estado == JUEGO && mover && contar, "ESPERA -> JUEGO")

        // Nivel de velocidad: 3 rebotes por nivel
        for (i = 0; i < 3; i = i + 1) pulso_rebote;
        @(negedge clk);
        `VERIFICAR(nivel == 1, $sformatf("nivel tras 3 rebotes = %0d", nivel))
        for (i = 0; i < 10; i = i + 1) pulso_rebote;
        @(negedge clk);
        `VERIFICAR(nivel == 3, $sformatf("nivel maximo = %0d", nivel))

        // JUEGO + START -> PAUSA -> JUEGO
        pulso_start;
        `VERIFICAR(estado == PAUSA && !mover && !pal_hab, "JUEGO -> PAUSA por START")
        enlace = 0; pulso_start;
        `VERIFICAR(estado == PAUSA, "salio de PAUSA sin enlace")
        enlace = 1; pulso_start;
        `VERIFICAR(estado == JUEGO, "PAUSA -> JUEGO")

        // JUEGO + pérdida de enlace -> PAUSA  (T09)
        @(negedge clk) enlace = 0;
        @(negedge clk);
        @(negedge clk);
        `VERIFICAR(estado == PAUSA, "T09 perdida de enlace pausa el juego")
        enlace = 1; pulso_start;

        // JUEGO + gol J1 -> PUNTO, luego saque hacia J2 (el que perdió)
        s0 = n_saques;
        pulso_gol(0);
        `VERIFICAR(estado == PUNTO && !mover && !contar, "JUEGO -> PUNTO")
        esperar_ms(PAUSA_MS / 2);
        `VERIFICAR(estado == PUNTO, "salio de PUNTO antes de tiempo")
        esperar_ms(PAUSA_MS);
        `VERIFICAR(estado == JUEGO && n_saques == s0 + 1 && ultimo_dx == 1,
                   "PUNTO -> JUEGO con saque hacia J2")
        `VERIFICAR(nivel == 0, "el nivel no se reinicio con el saque")

        // Gol de J2 -> saque hacia J1
        pulso_gol(1);
        esperar_ms(PAUSA_MS + 2);
        `VERIFICAR(estado == JUEGO && ultimo_dx == 0, "saque hacia J1 despues de gol de J2")

        // Prioridad: gol y pérdida de enlace en el mismo ciclo -> PUNTO
        @(negedge clk) begin g1 = 1; enlace = 0; end
        @(negedge clk) begin g1 = 0; end
        `VERIFICAR(estado == PUNTO, "prioridad del gol sobre la perdida de enlace")
        enlace = 1;
        esperar_ms(PAUSA_MS + 2);

        // PUNTO con victoria -> FIN
        pulso_gol(1);
        gana2 = 1;
        esperar_ms(PAUSA_MS + 2);
        `VERIFICAR(estado == FIN && ganador == 1 && !pal_hab, "PUNTO -> FIN, gana J2")

        // En FIN los goles ya no importan y START lleva a ESPERA limpiando
        s0 = n_limpiar;
        pulso_start;
        gana2 = 0;
        `VERIFICAR(estado == ESPERA && n_limpiar == s0 + 1 && ultimo_dx == 0,
                   "FIN -> ESPERA con marcador limpio y saque hacia J1")

        // Recuperación de estados no usados
        for (i = 5; i < 8; i = i + 1) begin
            @(negedge clk) force dut.estado = i;
            @(negedge clk) release dut.estado;
            @(negedge clk);
            `VERIFICAR(estado == ESPERA, $sformatf("recuperacion desde el codigo %0d", i))
        end

        // RESET en medio del juego
        pulso_start;
        `VERIFICAR(estado == JUEGO, "volvio a JUEGO")
        @(negedge clk) rst = 1;
        @(negedge clk) rst = 0;
        `VERIFICAR(estado == ESPERA, "T06 RESET lleva a ESPERA")

        reporte_final("tb_control_juego");
        $finish;
    end

endmodule
