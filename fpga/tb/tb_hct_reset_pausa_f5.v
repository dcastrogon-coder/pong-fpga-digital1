`timescale 1ns/1ps

// FASE 5 - Prueba de PAUSE, reanudacion y RESET por entradas externas.
// Instancia el nucleo F5 directamente, como la prueba de controles.
// No fuerza senales RTL internas ni comprueba HCT_EN del modulo superior.
module tb_hct_reset_pausa_f5;

    localparam integer NDB_TB = 12;
    localparam integer N_BALL_TB = 12000;  // 240 us a 50 MHz

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg START_N = 1'b1;
    reg RESET_N = 1'b1;
    reg PAUSE_N = 1'b1;
    reg J1_UP_N = 1'b1;
    reg J1_DOWN_N = 1'b1;
    reg J1_DETECT_N = 1'b1;
    reg J2_UP_N = 1'b1;
    reg J2_DOWN_N = 1'b1;
    reg J2_DETECT_N = 1'b1;

    wire DIN, CLK_LED, LOAD;

    pong_f5_core #(
        .NDB_RESET(20'd8),
        .NDB_BUTTON(20'd12),
        .N_BALL(24'd12000),
        .N_PADDLE(24'd4000),
        .H_LED(25)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_RAW(~START_N),
        .RESET_RAW(~RESET_N),
        .PAUSE_RAW(~PAUSE_N),
        .J1_UP_N(J1_UP_N), .J1_DOWN_N(J1_DOWN_N),
        .J1_DETECT_N(J1_DETECT_N),
        .J2_UP_N(J2_UP_N), .J2_DOWN_N(J2_DOWN_N),
        .J2_DETECT_N(J2_DETECT_N),
        .DIN(DIN), .CLK_LED(CLK_LED), .LOAD(LOAD),
        .SCORE_J1_BCD(), .SCORE_J2_BCD()
    );

    localparam [12:0] SNAP_INICIAL = {3'd3, 3'd3, 4'd7, 3'd3};

    reg [31:0] RX = 32'd0;
    reg [31:0] ESPERADA;
    reg [12:0] SNAP_CUADRO = SNAP_INICIAL;
    integer BITS = 0;
    integer EPOCA = 0;            // 0: arranque; 1: despues de RESET
    integer INIT_CONT = 0;
    integer TOTAL_INIT = 0;
    integer FILA = 0;
    integer CUADROS = 0;          // Se reinicia por cada RESET
    reg ARM_RESET = 1'b0;
    reg [3:0] XB_PAUSA;
    reg [2:0] YB_PAUSA;
    reg [2:0] YP1_PAUSA, YP2_PAUSA;
    integer CUADROS_PREV;

    function [15:0] comando_init;
        input integer n;
        begin
            case(n)
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

    // Oraculo para los bytes transmitidos a las dos matrices.
    function [31:0] trama_fila;
        input integer fila;
        input [12:0] snap;
        reg [2:0] y1, y2, by;
        reg [3:0] bx, dir;
        reg [7:0] a, b;
        begin
            y1 = snap[12:10];
            y2 = snap[9:7];
            bx = snap[6:3];
            by = snap[2:0];
            dir = 4'd8 - fila;
            a = 8'h00;
            b = 8'h00;
            if ((fila == y1) || (fila == ({1'b0,y1}+4'd1))) a[0] = 1'b1;
            if ((fila == y2) || (fila == ({1'b0,y2}+4'd1))) b[7] = 1'b1;
            if (fila == by) begin
                if (bx <= 4'd7) a[bx] = 1'b1;
                else b[bx - 4'd8] = 1'b1;
            end
            trama_fila = {4'b0000,dir,b,4'b0000,dir,a};
        end
    endfunction

    // Al afirmar RESET se descarta cualquier trama interrumpida y
    // se exige otra secuencia completa de inicializacion MAX7219.
    always @(posedge dut.INIT_GLOBAL) begin
        if (ARM_RESET) begin
            EPOCA = EPOCA + 1;
            if (EPOCA != 1)
                $fatal(1, "INIT_GLOBAL se activo inesperadamente %0d veces", EPOCA);
            INIT_CONT = 0;
            FILA = 0;
            CUADROS = 0;
            BITS = 0;
            RX = 32'd0;
            $display("PASS: RESET activa INIT_GLOBAL y reinicia el monitor");
        end
    end

    always @(posedge CLK_LED) begin
        if (dut.INIT_GLOBAL !== 1'b0)
            $fatal(1, "CLK_LED durante RESET");
        RX = {RX[30:0],DIN};
        BITS = BITS + 1;
        if (BITS > 32)
            $fatal(1, "Mas de 32 bits sin LOAD");
    end

    always @(posedge LOAD) begin
        if (dut.INIT_GLOBAL !== 1'b0)
            $fatal(1, "LOAD durante RESET");
        if (BITS != 32)
            $fatal(1, "Trama de %0d bits en vez de 32",BITS);

        if (INIT_CONT < 14) begin
            if (dut.u_transmisor_max7219.INIT_MODE !== 1'b1)
                $fatal(1, "INIT_MODE bajo durante secuencia de inicio");
            ESPERADA = {comando_init(INIT_CONT), comando_init(INIT_CONT)};
            if (RX !== ESPERADA)
                $fatal(1, "Init epoca %0d comando %0d: RX=%h ESP=%h",
                       EPOCA, INIT_CONT+1, RX, ESPERADA);
            INIT_CONT = INIT_CONT + 1;
            TOTAL_INIT = TOTAL_INIT + 1;
            if (INIT_CONT == 14)
                $display("PASS: inicializacion MAX7219 14/14 (epoca %0d)",EPOCA);
        end else begin
            if (dut.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1, "INIT_MODE sigue alto durante refresco");
            if (dut.u_transmisor_max7219.ROW_IDX !== FILA[2:0])
                $fatal(1, "Fila incorrecta: %0d",FILA);
            if (FILA == 0)
                SNAP_CUADRO = dut.SNAPSHOT;
            ESPERADA = trama_fila(FILA,SNAP_CUADRO);
            if (RX !== ESPERADA)
                $fatal(1, "Imagen epoca %0d fila %0d: RX=%h ESP=%h SNAP=%h",
                       EPOCA,FILA,RX,ESPERADA,SNAP_CUADRO);
            if (FILA == 7) begin
                FILA = 0;
                CUADROS = CUADROS + 1;
            end else begin
                FILA = FILA + 1;
            end
        end
        RX = 32'd0;
        BITS = 0;
    end

    task pulsar_start;
        begin
            @(negedge CLK_SYS);
            START_N = 1'b0;
            repeat (NDB_TB + 14) @(negedge CLK_SYS);
            START_N = 1'b1;
            repeat (NDB_TB + 14) @(negedge CLK_SYS);
        end
    endtask

    task pulsar_pausa;
        begin
            @(negedge CLK_SYS);
            PAUSE_N = 1'b0;
            repeat (NDB_TB + 14) @(negedge CLK_SYS);
            PAUSE_N = 1'b1;
            repeat (NDB_TB + 14) @(negedge CLK_SYS);
        end
    endtask

    initial begin
        // Arranque; esperar inicializacion y primer cuadro completo.
        wait (INIT_CONT == 14);
        wait (CUADROS >= 1);
        if (dut.STATE !== 3'd0 || dut.SNAPSHOT !== SNAP_INICIAL)
            $fatal(1, "Estado inicial o imagen inicial incorrectos");
        $display("PASS: imagen inicial y estado ESPERA");

        // Simular que ambos mandos estan enchufados.
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;
        wait (dut.RF_OK_EFF === 1'b1);
        pulsar_start();
        if (dut.STATE !== 3'd1 || dut.GAME_EN !== 1'b1)
            $fatal(1, "START no habilito JUEGO");
        wait (dut.XB == 4'd8);
        $display("PASS: START y movimiento real de pelota");

        // Pulsacion muy corta de PAUSE: debe ignorarse por antirrebote.
        @(negedge CLK_SYS);
        PAUSE_N = 1'b0;
        repeat (3) @(negedge CLK_SYS);
        PAUSE_N = 1'b1;
        repeat (NDB_TB + 10) @(negedge CLK_SYS);
        if (dut.STATE !== 3'd1)
            $fatal(1, "Rebote corto activo PAUSE");
        $display("PASS: rebote corto de PAUSE rechazado");

        // Primera pulsacion valida: JUEGO -> PAUSA_MANUAL (5).
        pulsar_pausa();
        if (dut.STATE !== 3'd5 || dut.GAME_EN !== 1'b0)
            $fatal(1, "PAUSE no detuvo JUEGO");
        XB_PAUSA = dut.XB;
        YB_PAUSA = dut.YB;
        YP1_PAUSA = dut.YP1;
        YP2_PAUSA = dut.YP2;
        CUADROS_PREV = CUADROS;

        // Aun pulsando movimientos, no se deben mover las paletas.
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;
        wait (dut.CMD_J1 === 2'b01 && dut.CMD_J2 === 2'b10);
        repeat (2*N_BALL_TB + 50) @(negedge CLK_SYS);
        if (dut.XB !== XB_PAUSA || dut.YB !== YB_PAUSA ||
            dut.YP1 !== YP1_PAUSA || dut.YP2 !== YP2_PAUSA)
            $fatal(1, "Pelota o paletas se movieron durante PAUSE");
        if (dut.STATE !== 3'd5 || dut.GAME_EN !== 1'b0)
            $fatal(1, "La pausa se perdio inesperadamente");
        if (CUADROS <= CUADROS_PREV)
            $fatal(1, "El refresco MAX7219 se detuvo durante PAUSE");
        $display("PASS: PAUSE congela pelota/paletas, mantiene refresco");

        @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J2_DOWN_N = 1'b1;
        wait (dut.CMD_J1 === 2'b00 && dut.CMD_J2 === 2'b00);

        // Segunda pulsacion valida: PAUSA_MANUAL -> JUEGO.
        pulsar_pausa();
        if (dut.STATE !== 3'd1 || dut.GAME_EN !== 1'b1)
            $fatal(1, "PAUSE no reanudo JUEGO");
        wait (dut.XB != XB_PAUSA);
        $display("PASS: segunda pulsacion de PAUSE reanuda movimiento");

        // RESET fisico activo-bajo durante la partida.
        ARM_RESET = 1'b1;
        @(negedge CLK_SYS);
        RESET_N = 1'b0;
        #1;
        if (dut.INIT_GLOBAL !== 1'b1 || dut.RESET_CLEAN !== 1'b1)
            $fatal(1, "RESET no se afirmo correctamente");
        repeat (6) @(negedge CLK_SYS);
        if (DIN !== 1'b0 || CLK_LED !== 1'b0 || LOAD !== 1'b0)
            $fatal(1, "Salidas MAX7219 no quedan en bajo durante RESET");
        RESET_N = 1'b1;
        wait (dut.INIT_GLOBAL === 1'b0);
        @(negedge CLK_SYS);
        if (dut.STATE !== 3'd0 || dut.GAME_EN !== 1'b0 ||
            dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3 ||
            dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.SCORE_J1 !== 4'd0 || dut.SCORE_J2 !== 4'd0)
            $fatal(1, "RESET no restauro el estado inicial completo");
        $display("PASS: RESET recupera ESPERA, paletas, pelota y marcador");

        // Comprobar que MAX7219 se inicializa OTRA vez y luego
        // transmite un cuadro completamente nuevo con imagen inicial.
        wait (INIT_CONT == 14);
        wait (CUADROS >= 1);
        if (SNAP_CUADRO !== SNAP_INICIAL || EPOCA != 1 || TOTAL_INIT != 28)
            $fatal(1, "No se recupero imagen o doble inicializacion");
        $display("PASS: RESET repite los 14 comandos MAX7219");
        $display("PASS: imagen inicial restaurada y refrescada");
        $display("PASS: 28/28 comandos de inicio (14 + 14)");
        $display("PASS: todas las tramas comprobadas con 32 bits");
        $display("PASS: PAUSE, reanudacion y RESET correctos");
        $finish;
    end

    initial begin
        #5000000; // 5 ms para la prueba con NDB reducido.
        $fatal(1, "TIMEOUT: prueba RESET/PAUSE incompleta");
    end

endmodule