`timescale 1ns/1ps

module tb_hct_arranque_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    wire DIN, CLK_LED, LOAD, HCT_EN;

    pong_f5_controles_top #(
        .HCT_WAIT_CYCLES(12)
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

    integer i;

    initial begin
        #1;

        if (HCT_EN !== 1'b0)
            $fatal(1, "ERROR: HCT_EN no inicia en cero");

        if (dut.u_pong_f5.INIT_GLOBAL !== 1'b1)
            $fatal(1, "ERROR: nucleo sin reset inicial");

        for (i = 0; i < 11; i = i + 1) begin
            @(posedge CLK_SYS);
            #1;

            if (HCT_EN !== 1'b0)
                $fatal(1, "ERROR: habilitacion anticipada");
        end

        @(posedge CLK_SYS);
        #1;

        if (HCT_EN !== 1'b1)
            $fatal(1, "ERROR: HCT_EN no se habilito");

        if (dut.u_pong_f5.INIT_GLOBAL !== 1'b1)
            $fatal(1, "ERROR: reset liberado demasiado pronto");

        $display("PASS: arranque y habilitacion HCT correctos");
        $finish;
    end

endmodule