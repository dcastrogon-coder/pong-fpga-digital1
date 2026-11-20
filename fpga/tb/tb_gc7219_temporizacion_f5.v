`timescale 1ns/1ps

// PF ELECTRONICA DIGITAL 1 - PONG F5
// GC7219C: temporizacion serial de 2 controladores en cascada.
// Verificacion RTL + escenarios IDEALIZADOS de retardo del SN74HCT245N.
// No sustituye TimeQuest, las medidas en el PCB ni un modelo electrico SPICE.
// Referencias:
//   GC7219: tCP >= 100 ns; tCH, tCL >= 50 ns; tDS >= 25 ns;
//           tCSW >= 50 ns; tLDCK >= 50 ns; tDH, tCSH >= 0 ns.
//   TI SN74HCT245: tpd max 38 ns (VCC=4.5 V, CL=150 pF).

// Un observador independiente comprueba 14 comandos y 8 filas.
module gc7219_monitor_f5 #(
    parameter integer CANAL = 0
)(
    input wire DIN_OBS,
    input wire CLK_OBS,
    input wire LOAD_OBS,
    input wire HCT_EN,
    output reg TERMINADO = 1'b0
);

    localparam integer T_CP_MIN   = 100;
    localparam integer T_CH_MIN   = 50;
    localparam integer T_CL_MIN   = 50;
    localparam integer T_DS_MIN   = 25;
    localparam integer T_CSW_MIN  = 50;
    localparam integer T_LDCK_MIN = 50;

    reg [31:0] RX = 32'd0;
    reg [31:0] ESPERADO = 32'd0;
    reg [15:0] COMANDO = 16'd0;
    integer BITS = 0;
    integer TRAMAS = 0;

    realtime T_DIN = 0.0;
    realtime T_CLK_SUBE = 0.0;
    realtime T_CLK_BAJA = 0.0;
    realtime T_LOAD_SUBE = 0.0;
    realtime T_LOAD_BAJA = 0.0;

    reg VIO_CLK_SUBE = 1'b0;
    reg VIO_CLK_BAJA = 1'b0;
    reg VIO_LOAD_SUBE = 1'b0;
    reg VIO_LOAD_BAJA = 1'b0;
    reg ULTIMA_TRAMA = 1'b0;

    function [15:0] comando_init;
        input integer indice;
        begin
            case (indice)
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

    // Primer cuadro del Pong en estado ESPERA; direcciones 8 .. 1.
    function [31:0] fila_inicial;
        input integer indice;
        reg [3:0] dir;
        reg [7:0] dato_a;
        reg [7:0] dato_b;
        begin
            dir = 4'd8 - indice;
            dato_a = 8'h00;
            dato_b = 8'h00;
            if ((indice == 3) || (indice == 4)) begin
                dato_a[0] = 1'b1;
                dato_b[7] = 1'b1;
            end
            if (indice == 3)
                dato_a[7] = 1'b1;
            fila_inicial = {4'b0000, dir, dato_b,
                            4'b0000, dir, dato_a};
        end
    endfunction

    // Momento mas reciente en que cambia el dato observado.
    always @(DIN_OBS) begin
        if (HCT_EN === 1'b1 && !TERMINADO) begin
            T_DIN = $realtime;
            if ((DIN_OBS !== 1'b0) && (DIN_OBS !== 1'b1))
                $fatal(1, "Canal %0d: DIN desconocido", CANAL);
        end
    end

    // Flanco positivo: captura de bit y tiempos de periodo, bajo y setup.
    always @(posedge CLK_OBS) begin
        if ($realtime > 1.0 && HCT_EN !== 1'b1)
            $fatal(1, "Canal %0d: CLK antes de HCT_EN", CANAL);

        if (HCT_EN === 1'b1 && !TERMINADO) begin
            if ((DIN_OBS !== 1'b0) && (DIN_OBS !== 1'b1))
                $fatal(1, "Canal %0d: DIN invalido al muestrear", CANAL);

            if (VIO_CLK_SUBE &&
                ($realtime - T_CLK_SUBE < T_CP_MIN))
                $fatal(1, "Canal %0d: tCP menor de 100 ns", CANAL);

            if (VIO_CLK_BAJA &&
                ($realtime - T_CLK_BAJA < T_CL_MIN))
                $fatal(1, "Canal %0d: tCL menor de 50 ns", CANAL);

            if ($realtime - T_DIN < T_DS_MIN)
                $fatal(1, "Canal %0d: tDS menor de 25 ns", CANAL);

            // Tras un LOAD ascendente, siguiente CLK >= 50 ns.
            if (VIO_LOAD_SUBE &&
                (!VIO_CLK_SUBE || (T_LOAD_SUBE > T_CLK_SUBE)) &&
                ($realtime - T_LOAD_SUBE < T_LDCK_MIN))
                $fatal(1, "Canal %0d: tLDCK menor de 50 ns", CANAL);

            RX = {RX[30:0], DIN_OBS};
            BITS = BITS + 1;
            if (BITS > 32)
                $fatal(1, "Canal %0d: mas de 32 bits por trama", CANAL);

            T_CLK_SUBE = $realtime;
            VIO_CLK_SUBE = 1'b1;
        end
    end

    // Flanco negativo: duracion del pulso alto de CLK.
    always @(negedge CLK_OBS) begin
        if (HCT_EN === 1'b1 && !TERMINADO && VIO_CLK_SUBE) begin
            if ($realtime - T_CLK_SUBE < T_CH_MIN)
                $fatal(1, "Canal %0d: tCH menor de 50 ns", CANAL);
            T_CLK_BAJA = $realtime;
            VIO_CLK_BAJA = 1'b1;
        end
    end

    // LOAD ascendente: trama terminada y CLK bajo.
    always @(posedge LOAD_OBS) begin
        if ($realtime > 1.0 && HCT_EN !== 1'b1)
            $fatal(1, "Canal %0d: LOAD antes de HCT_EN", CANAL);

        if (HCT_EN === 1'b1 && !TERMINADO) begin
            if (CLK_OBS !== 1'b0)
                $fatal(1, "Canal %0d: LOAD sube con CLK alto", CANAL);
            if (BITS != 32)
                $fatal(1, "Canal %0d: LOAD con %0d bits", CANAL, BITS);

            if (TRAMAS < 14) begin
                COMANDO = comando_init(TRAMAS);
                ESPERADO = {COMANDO, COMANDO};
            end else if (TRAMAS < 22) begin
                ESPERADO = fila_inicial(TRAMAS - 14);
            end else begin
                $fatal(1, "Canal %0d: trama extra", CANAL);
            end

            if (RX !== ESPERADO)
                $fatal(1, "Canal %0d, trama %0d: RX=%h ESP=%h",
                       CANAL, TRAMAS + 1, RX, ESPERADO);

            TRAMAS = TRAMAS + 1;
            BITS = 0;
            RX = 32'd0;
            T_LOAD_SUBE = $realtime;
            VIO_LOAD_SUBE = 1'b1;

            if (TRAMAS == 22)
                ULTIMA_TRAMA = 1'b1;
        end
    end

    // LOAD descendente: verifica tCSW tambien para el ultimo cuadro.
    always @(negedge LOAD_OBS) begin
        if (HCT_EN === 1'b1 && !TERMINADO) begin
            if (VIO_LOAD_SUBE &&
                ($realtime - T_LOAD_SUBE < T_CSW_MIN))
                $fatal(1, "Canal %0d: tCSW menor de 50 ns", CANAL);
            T_LOAD_BAJA = $realtime;
            VIO_LOAD_BAJA = 1'b1;

            if (ULTIMA_TRAMA) begin
                TERMINADO = 1'b1;
                $display("PASS: canal %0d: 14 init + 8 filas; 22 tramas; tCP/tCH/tCL/tDS/tCSW/tLDCK", CANAL);
            end
        end
    end

endmodule

module tb_gc7219_temporizacion_f5;
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
        .J1_UP_N(1'b1), .J1_DOWN_N(1'b1), .J1_DETECT_N(1'b1),
        .J2_UP_N(1'b1), .J2_DOWN_N(1'b1), .J2_DETECT_N(1'b1),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .HCT_EN(HCT_EN)
    );

    // Escenarios de propagacion idealizada del SN74HCT245N.
    // 38 ns es un tpd maximo de hoja de datos en condiciones especificas.
    // Se ensayan desfases desfavorables de 0 a 38 ns entre canales.
    wire DIN_38;
    wire CLK_38;
    wire LOAD_38;
    assign #38 DIN_38  = DIN;
    assign #38 CLK_38  = CLK_LED;
    assign #38 LOAD_38 = LOAD;

    wire OK_RTL, OK_DIN_TARDE, OK_CLK_TARDE, OK_LOAD_TARDE;

    // Sin retardo externo: salidas RTL puras.
    gc7219_monitor_f5 #(.CANAL(0)) u_rtl (
        .DIN_OBS(DIN), .CLK_OBS(CLK_LED), .LOAD_OBS(LOAD),
        .HCT_EN(HCT_EN), .TERMINADO(OK_RTL)
    );

    // Dato llega 38 ns despues del reloj: condicion desfavorable de setup.
    gc7219_monitor_f5 #(.CANAL(1)) u_din_tarde (
        .DIN_OBS(DIN_38), .CLK_OBS(CLK_LED), .LOAD_OBS(LOAD),
        .HCT_EN(HCT_EN), .TERMINADO(OK_DIN_TARDE)
    );

    // Reloj llega 38 ns despues del dato y LOAD.
    gc7219_monitor_f5 #(.CANAL(2)) u_clk_tarde (
        .DIN_OBS(DIN), .CLK_OBS(CLK_38), .LOAD_OBS(LOAD),
        .HCT_EN(HCT_EN), .TERMINADO(OK_CLK_TARDE)
    );

    // LOAD llega 38 ns despues del reloj y dato.
    gc7219_monitor_f5 #(.CANAL(3)) u_load_tarde (
        .DIN_OBS(DIN), .CLK_OBS(CLK_LED), .LOAD_OBS(LOAD_38),
        .HCT_EN(HCT_EN), .TERMINADO(OK_LOAD_TARDE)
    );

    initial begin
        #1;
        if (HCT_EN !== 1'b0)
            $fatal(1, "HCT_EN no inicia en 0");
        // Margen por RESET nominal cercano a 20 ms, observado en Questa.
        #30000000;
        $fatal(1, "TIMEOUT: verificacion temporal incompleta");
    end

    initial begin
        wait (OK_RTL && OK_DIN_TARDE && OK_CLK_TARDE && OK_LOAD_TARDE);
        #100;
        $display("PASS: GC7219C, 4 escenarios temporales verificados");
        $display("PASS: 14/14 comandos y 8/8 filas por escenario");
        $display("PASS: 88/88 tramas comprobadas (4 x 22)");
        $display("AVISO: no modela dispersion de flancos, cableado ni encendido de 5 V");
        $finish;
    end
endmodule