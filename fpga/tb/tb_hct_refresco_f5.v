`timescale 1ns/1ps

// FASE 5: inicializacion MAX7219 y refresco continuo de tres cuadros.
// Entradas sin pulsar: la imagen inicial debe permanecer fija.
module tb_hct_refresco_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;  // 50 MHz

    wire DIN, CLK_LED, LOAD, HCT_EN;

    pong_f5_controles_top #(
        .HCT_WAIT_CYCLES(12),
        .NDB_RESET_TOP(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_N(1'b1),
        .RESET_N(1'b1),
        .PAUSE_N(1'b1),
        .J1_UP_N(1'b1),
        .J1_DOWN_N(1'b1),
        .J1_DETECT_N(1'b1),
        .J2_UP_N(1'b1),
        .J2_DOWN_N(1'b1),
        .J2_DETECT_N(1'b1),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .HCT_EN(HCT_EN)
    );

    reg [31:0] RX = 32'd0;
    reg [31:0] EXPECTED;
    reg [15:0] CMD;
    integer BITS = 0;
    integer TRAMAS = 0;
    integer CUADRO;
    integer FILA;

    function [15:0] comando_init;
        input integer idx;
        begin
            case (idx)
                 0: comando_init = 16'h0F00;
                 1: comando_init = 16'h0C00;
                 2: comando_init = 16'h0900;
                 3: comando_init = 16'h0B07;
                 4: comando_init = 16'h0A08;
                 5: comando_init = 16'h0100;
                 6: comando_init = 16'h0200;
                 7: comando_init = 16'h0300;
                 8: comando_init = 16'h0400;
                 9: comando_init = 16'h0500;
                10: comando_init = 16'h0600;
                11: comando_init = 16'h0700;
                12: comando_init = 16'h0800;
                13: comando_init = 16'h0C01;
                default: comando_init = 16'hFFFF;
            endcase
        end
    endfunction

    // Direcciones fisicas: 8, 7, ..., 1.
    // Trama: primero MAX7219 B (lejano), despues A (cercano).
    // Estado inicial: J1 y J2 en filas 3 y 4, pelota en (7,3).
    function [31:0] fila_esperada;
        input integer idx;
        reg [3:0] direccion;
        reg [7:0] a;
        reg [7:0] b;
        begin
            direccion = 4'd8 - idx;
            a = 8'h00;
            b = 8'h00;
            if ((idx == 3) || (idx == 4)) begin
                a[0] = 1'b1;
                b[7] = 1'b1;
            end
            if (idx == 3)
                a[7] = 1'b1;
            fila_esperada = {4'b0000, direccion, b,
                             4'b0000, direccion, a};
        end
    endfunction

    // Muestreo del dato en el flanco ascendente del reloj serial.
    always @(posedge CLK_LED) begin
        if (HCT_EN !== 1'b1)
            $fatal(1, "CLK_LED antes de habilitar HCT");
        RX = {RX[30:0], DIN};
        BITS = BITS + 1;
        if (BITS > 32)
            $fatal(1, "Demasiados bits sin LOAD");
    end

    always @(posedge LOAD) begin
        if (HCT_EN !== 1'b1)
            $fatal(1, "LOAD antes de habilitar HCT");
        if (BITS != 32)
            $fatal(1, "Trama %0d: %0d bits en lugar de 32",
                   TRAMAS + 1, BITS);

        if (TRAMAS < 14) begin
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b1)
                $fatal(1, "INIT_MODE bajo durante inicializacion");
            CMD = comando_init(TRAMAS);
            EXPECTED = {CMD, CMD};
            if (RX !== EXPECTED)
                $fatal(1, "INIT %0d: RX=%h ESP=%h",
                       TRAMAS + 1, RX, EXPECTED);
            $display("PASS: init %0d/14 = %h", TRAMAS + 1, CMD);
        end
        else if (TRAMAS < 38) begin
            CUADRO = (TRAMAS - 14) / 8;
            FILA = (TRAMAS - 14) % 8;

            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "INIT_MODE activo durante refresco");
            if (dut.u_pong_f5.u_transmisor_max7219.ROW_IDX !== FILA[2:0])
                $fatal(1, "Cuadro %0d: ROW_IDX incorrecto en fila %0d",
                       CUADRO + 1, FILA + 1);
            if (FILA == 0 &&
                dut.u_pong_f5.SNAPSHOT !== {3'd3, 3'd3, 4'd7, 3'd3})
                $fatal(1, "Cuadro %0d: SNAPSHOT inesperado", CUADRO + 1);

            EXPECTED = fila_esperada(FILA);
            if (RX !== EXPECTED)
                $fatal(1, "Cuadro %0d, fila %0d: RX=%h ESP=%h",
                       CUADRO + 1, FILA + 1, RX, EXPECTED);

            $display("PASS: cuadro %0d/3, fila %0d/8, trama %h",
                     CUADRO + 1, FILA + 1, RX);
            if (FILA == 7)
                $display("PASS: cuadro %0d/3 completo", CUADRO + 1);
        end
        else begin
            $fatal(1, "Se recibio una trama fuera de la prueba");
        end

        TRAMAS = TRAMAS + 1;
        BITS = 0;
        RX = 32'd0;

        if (TRAMAS == 38) begin
            // La FSM debe conservar el modo de refresco.
            #2000;
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "INIT_MODE volvio a activarse");
            if (HCT_EN !== 1'b1)
                $fatal(1, "HCT_EN se deshabilito durante el refresco");
            $display("PASS: 14/14 comandos de inicializacion");
            $display("PASS: 3/3 cuadros consecutivos completos");
            $display("PASS: 24/24 filas de refresco correctas");
            $display("PASS: 38/38 tramas de 32 bits correctas");
            $finish;
        end
    end

    initial begin
        #1;
        if (HCT_EN !== 1'b0)
            $fatal(1, "HCT_EN no inicia deshabilitado");
        // Se conserva margen para el reinicio nominal ~20 ms.
        #30000000;
        $fatal(1, "TIMEOUT: refresco incompleto");
    end

endmodule