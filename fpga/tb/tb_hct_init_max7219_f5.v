`timescale 1ns/1ps

module tb_hct_init_max7219_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

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
    reg [15:0] EXPECTED;

    integer BITS = 0;
    integer FRAMES = 0;

    // Capturar los datos seriales en cada flanco de CLK_LED.
    always @(posedge CLK_LED) begin
        if (HCT_EN !== 1'b1)
            $fatal(1, "CLK antes de habilitar HCT");

        RX = {RX[30:0], DIN};
        BITS = BITS + 1;
    end

    // Comprobar los 14 comandos de inicializacion del MAX7219.
    always @(posedge LOAD) begin

        if (HCT_EN !== 1'b1)
            $fatal(1, "LOAD antes de habilitar HCT");

        if (BITS != 32)
            $fatal(1, "Trama incorrecta: %0d bits", BITS);

        case (FRAMES)
             0: EXPECTED = 16'h0F00;
             1: EXPECTED = 16'h0C00;
             2: EXPECTED = 16'h0900;
             3: EXPECTED = 16'h0B07;
             4: EXPECTED = 16'h0A08;
             5: EXPECTED = 16'h0100;
             6: EXPECTED = 16'h0200;
             7: EXPECTED = 16'h0300;
             8: EXPECTED = 16'h0400;
             9: EXPECTED = 16'h0500;
            10: EXPECTED = 16'h0600;
            11: EXPECTED = 16'h0700;
            12: EXPECTED = 16'h0800;
            13: EXPECTED = 16'h0C01;
            default:
                $fatal(1, "Trama adicional inesperada");
        endcase

        // Cada comando debe llegar a ambos MAX7219 en cascada.
        if (RX !== {EXPECTED, EXPECTED})
            $fatal(1,
                "Trama %0d incorrecta. RX=%h ESP=%h",
                FRAMES, RX, {EXPECTED, EXPECTED}
            );

        $display("PASS: comando %0d = %h",
                 FRAMES + 1, EXPECTED);

        FRAMES = FRAMES + 1;
        BITS = 0;
        RX = 32'd0;

        if (FRAMES == 14) begin

            // No finalizar durante el ultimo pulso de LOAD.
            // Dar tiempo a la FSM para salir de INIT_MODE.
            #2000;

            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "ERROR: INIT_MODE sigue activo");

            $display("PASS: 14/14 comandos MAX7219 correctos");
            $display("PASS: INIT_MODE desactivado correctamente");

            $finish;
        end
    end

    initial begin
        #1;

        if (HCT_EN !== 1'b0)
            $fatal(1, "HCT_EN no inicia en cero");

        // 30 ms: cubre el reinicio nominal de 20 ms
        // y la inicializacion.
        #30000000;

        $fatal(1, "TIMEOUT: inicializacion incompleta");
    end

endmodule