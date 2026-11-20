`timescale 1ns/1ps

// F5: verifica inicializacion de dos MAX7219 y primer cuadro
// de 8 filas (16 columnas) con el Pong en estado inicial.
module tb_hct_filas_f5;

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
    reg [15:0] INIT_WORD;
    integer BITS = 0;
    integer FRAMES = 0;
    integer ROW;

    // Los 14 comandos de inicializacion son identicos
    // para el MAX7219 lejano y el cercano.
    function [15:0] init_command;
        input integer idx;
        begin
            case (idx)
                 0: init_command = 16'h0F00;
                 1: init_command = 16'h0C00;
                 2: init_command = 16'h0900;
                 3: init_command = 16'h0B07;
                 4: init_command = 16'h0A08;
                 5: init_command = 16'h0100;
                 6: init_command = 16'h0200;
                 7: init_command = 16'h0300;
                 8: init_command = 16'h0400;
                 9: init_command = 16'h0500;
                10: init_command = 16'h0600;
                11: init_command = 16'h0700;
                12: init_command = 16'h0800;
                13: init_command = 16'h0C01;
                default: init_command = 16'hFFFF;
            endcase
        end
    endfunction

    // Imagen inicial esperada:
    // J1: columna 0, filas 3 y 4.
    // J2: columna 15, filas 3 y 4.
    // Pelota: columna 7, fila 3.
    // Direcciones corregidas de MAX7219: 8, 7, ..., 1.
    // El controlador B (lejano) recibe los primeros 16 bits.
    function [31:0] expected_row;
        input integer idx;
        reg [3:0] addr;
        reg [7:0] data_a;
        reg [7:0] data_b;
        begin
            addr = 4'd8 - idx;
            data_a = 8'h00;
            data_b = 8'h00;

            if ((idx == 3) || (idx == 4)) begin
                data_a[0] = 1'b1;  // Paleta J1
                data_b[7] = 1'b1;  // Paleta J2
            end
            if (idx == 3)
                data_a[7] = 1'b1;  // Pelota en X=7

            expected_row = {4'b0000, addr, data_b,
                            4'b0000, addr, data_a};
        end
    endfunction

    // MAX7219 captura DIN con cada flanco ascendente de CLK.
    always @(posedge CLK_LED) begin
        if (HCT_EN !== 1'b1)
            $fatal(1, "CLK_LED antes de habilitar HCT");

        RX = {RX[30:0], DIN};
        BITS = BITS + 1;

        if (BITS > 32)
            $fatal(1, "Mas de 32 bits sin LOAD");
    end

    // Un pulso LOAD confirma cada trama de 32 bits.
    always @(posedge LOAD) begin
        if (HCT_EN !== 1'b1)
            $fatal(1, "LOAD antes de habilitar HCT");

        if (BITS != 32)
            $fatal(1, "Trama %0d: se recibieron %0d bits, no 32",
                   FRAMES + 1, BITS);

        if (FRAMES < 14) begin
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b1)
                $fatal(1, "INIT_MODE se desactivo antes de tiempo");

            INIT_WORD = init_command(FRAMES);
            EXPECTED = {INIT_WORD, INIT_WORD};

            if (RX !== EXPECTED)
                $fatal(1, "INIT %0d: RX=%h, esperado=%h",
                       FRAMES + 1, RX, EXPECTED);

            $display("PASS: init %0d/14 = %h", FRAMES + 1, INIT_WORD);
        end
        else if (FRAMES < 22) begin
            ROW = FRAMES - 14;

            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "INIT_MODE sigue activo durante las filas");

            if (ROW == 0 &&
                dut.u_pong_f5.SNAPSHOT !== {3'd3, 3'd3, 4'd7, 3'd3})
                $fatal(1, "La imagen inicial no tiene las posiciones esperadas");

            EXPECTED = expected_row(ROW);
            if (RX !== EXPECTED)
                $fatal(1, "Fila %0d: RX=%h, esperado=%h",
                       ROW + 1, RX, EXPECTED);

            $display("PASS: fila %0d/8, direccion %0d, trama %h",
                     ROW + 1, 8 - ROW, RX);
        end
        else begin
            $fatal(1, "Trama adicional inesperada");
        end

        FRAMES = FRAMES + 1;
        BITS = 0;
        RX = 32'd0;

        if (FRAMES == 22) begin
            #2000;
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "INIT_MODE no se mantiene desactivado");

            $display("PASS: 14/14 comandos MAX7219 correctos");
            $display("PASS: 8/8 filas del primer cuadro correctas");
            $display("PASS: 22/22 tramas de 32 bits correctas");
            $finish;
        end
    end

    initial begin
        #1;
        if (HCT_EN !== 1'b0)
            $fatal(1, "HCT_EN no inicia en cero");

        // Margen suficiente para el reinicio observado de ~20 ms.
        #30000000;
        $fatal(1, "TIMEOUT: no se completaron las 8 filas");
    end

endmodule