`timescale 1ns/1ps

// FASE 5: controles cableados -> antirrebote -> paletas ->
// captura de imagen -> tramas seriales para dos MAX7219.
//
// Se instancia pong_f5_core directamente para reducir SOLO los
// parametros de simulacion. No se fuerza ninguna senal interna.
// La habilitacion HCT_EN del modulo superior fue verificada en
// testbenches anteriores y NO se prueba en este archivo.
module tb_hct_controles_cableados_f5;

    localparam integer NDB_TB    = 12;     // 12 ciclos = 240 ns
    localparam integer PADDLE_TB = 6000;   // 120 us por tick

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;         // 50 MHz

    // Entradas equivalentes a los pines fisicos (activas en bajo).
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
        .N_PADDLE(24'd6000),
        .N_BALL(24'd5000000), // pelota quieta durante esta prueba
        .H_LED(25)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_RAW(~START_N),
        .RESET_RAW(~RESET_N),
        .PAUSE_RAW(~PAUSE_N),
        .J1_UP_N(J1_UP_N),
        .J1_DOWN_N(J1_DOWN_N),
        .J1_DETECT_N(J1_DETECT_N),
        .J2_UP_N(J2_UP_N),
        .J2_DOWN_N(J2_DOWN_N),
        .J2_DETECT_N(J2_DETECT_N),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .SCORE_J1_BCD(),
        .SCORE_J2_BCD()
    );

    reg [31:0] RX = 32'd0;
    reg [31:0] ESPERADA;
    reg [15:0] CMD_INIT;
    reg [12:0] SNAP_CUADRO = 13'd0;
    reg [12:0] ULTIMO_SNAP = 13'd0;

    integer BITS = 0;
    integer TRAMAS_INIT = 0;
    integer FILA = 0;
    integer CUADROS = 0;
    integer MUESTRA;

    function [15:0] comando_init;
        input integer i;
        begin
            case (i)
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

    // Oraculo independiente para la codificacion de cada fila.
    // SNAP = {YP1[2:0], YP2[2:0], XB[3:0], YB[2:0]}.
    // Matriz B lejana primero, A cercana despues.
    function [31:0] trama_fila;
        input integer fila;
        input [12:0] snap;
        reg [2:0] y1, y2, by;
        reg [3:0] bx, direccion;
        reg [7:0] a, b;
        begin
            y1 = snap[12:10];
            y2 = snap[9:7];
            bx = snap[6:3];
            by = snap[2:0];
            direccion = 4'd8 - fila;
            a = 8'h00;
            b = 8'h00;
            if ((fila == y1) || (fila == ({1'b0,y1} + 4'd1)))
                a[0] = 1'b1;
            if ((fila == y2) || (fila == ({1'b0,y2} + 4'd1)))
                b[7] = 1'b1;
            if (fila == by) begin
                if (bx <= 4'd7) a[bx] = 1'b1;
                else b[bx - 4'd8] = 1'b1;
            end
            trama_fila = {4'b0000,direccion,b,4'b0000,direccion,a};
        end
    endfunction

    // Comprobar que cada flanco de LOAD completa 32 bits correctos.
    always @(posedge CLK_LED) begin
        RX = {RX[30:0], DIN};
        BITS = BITS + 1;
        if (BITS > 32)
            $fatal(1, "Mas de 32 bits sin LOAD");
    end

    always @(posedge LOAD) begin
        if (BITS != 32)
            $fatal(1,"Trama con %0d bits; esperados 32", BITS);

        if (TRAMAS_INIT < 14) begin
            CMD_INIT = comando_init(TRAMAS_INIT);
            ESPERADA = {CMD_INIT,CMD_INIT};
            if (RX !== ESPERADA)
                $fatal(1,"Inicializacion %0d: RX=%h ESP=%h",
                       TRAMAS_INIT + 1,RX,ESPERADA);
            TRAMAS_INIT = TRAMAS_INIT + 1;
            if (TRAMAS_INIT == 14)
                $display("PASS: inicializacion MAX7219 14/14");
        end else begin
            if (dut.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1,"INIT_MODE activo durante imagen");
            if (dut.u_transmisor_max7219.ROW_IDX !== FILA[2:0])
                $fatal(1,"ROW_IDX incorrecto: fila %0d", FILA);
            if (FILA == 0)
                SNAP_CUADRO = dut.SNAPSHOT;

            ESPERADA = trama_fila(FILA,SNAP_CUADRO);
            if (RX !== ESPERADA)
                $fatal(1,"Fila %0d: RX=%h ESP=%h SNAP=%h",
                       FILA,RX,ESPERADA,SNAP_CUADRO);

            if (FILA == 7) begin
                ULTIMO_SNAP = SNAP_CUADRO;
                CUADROS = CUADROS + 1;
                FILA = 0;
            end else begin
                FILA = FILA + 1;
            end
        end
        RX = 32'd0;
        BITS = 0;
    end

    // Esperar un cuadro ENTERO correspondiente a posiciones concretas.
    // Incluye el contenido realmente serializado en las 8 filas.
    task esperar_cuadro;
        input [2:0] yp1_req;
        input [2:0] yp2_req;
        reg [12:0] esperado_snap;
        integer cuadro_prev;
        begin
            esperado_snap = {yp1_req,yp2_req,4'd7,3'd3};
            cuadro_prev = CUADROS;
            while (!(CUADROS > cuadro_prev && ULTIMO_SNAP === esperado_snap))
                @(negedge CLK_SYS);
            $display("PASS: cuadro verificado J1=%0d J2=%0d, SNAP=%h",
                     yp1_req,yp2_req,ULTIMO_SNAP);
        end
    endtask

    initial begin
        // Verificar el cuadro inicial con las dos entradas DETECT abiertas.
        esperar_cuadro(3'd3,3'd3);
        if (dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
            $fatal(1,"Paletas no iniciaron en el centro");

        // Conectar logicamente ambos mandos: DETECT_N=0.
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;
        wait (dut.RF_OK_EFF === 1'b1);
        $display("PASS: los dos controles detectados tras antirrebote");

        // START sin forzar ninguna senal interna de juego.
        @(negedge CLK_SYS);
        START_N = 1'b0;
        wait (dut.STATE === 3'd1);
        @(negedge CLK_SYS);
        START_N = 1'b1;
        repeat (NDB_TB + 6) @(negedge CLK_SYS);
        if (dut.GAME_EN !== 1'b1)
            $fatal(1,"El juego no quedo habilitado");
        $display("PASS: START externo habilita JUEGO");

        // Rebote inferior al umbral: no debe generar comandos.
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;
        repeat (3) @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J2_DOWN_N = 1'b1;
        repeat (NDB_TB + 8) @(negedge CLK_SYS);
        if (dut.CMD_J1 !== 2'b00 || dut.CMD_J2 !== 2'b00)
            $fatal(1,"El rebote produjo un comando falso");
        if (dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
            $fatal(1,"El rebote movio una paleta");
        $display("PASS: rebotes cortos rechazados");

        // Movimiento 1: J1 SUBE (3->2), J2 BAJA (3->4).
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;
        wait (dut.CMD_J1 === 2'b01 && dut.CMD_J2 === 2'b10);
        wait (dut.YP1 === 3'd2 && dut.YP2 === 3'd4);
        @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J2_DOWN_N = 1'b1;
        repeat (NDB_TB + 8) @(negedge CLK_SYS);
        if (dut.CMD_J1 !== 2'b00 || dut.CMD_J2 !== 2'b00)
            $fatal(1,"Los comandos no se liberaron");
        esperar_cuadro(3'd2,3'd4);
        $display("PASS: botones UP/DOWN actualizan la imagen");

        // Movimiento 2: J1 BAJA (2->3), J2 SUBE (4->3).
        @(negedge CLK_SYS);
        J1_DOWN_N = 1'b0;
        J2_UP_N = 1'b0;
        wait (dut.CMD_J1 === 2'b10 && dut.CMD_J2 === 2'b01);
        wait (dut.YP1 === 3'd3 && dut.YP2 === 3'd3);
        @(negedge CLK_SYS);
        J1_DOWN_N = 1'b1;
        J2_UP_N = 1'b1;
        repeat (NDB_TB + 8) @(negedge CLK_SYS);
        if (dut.CMD_J1 !== 2'b00 || dut.CMD_J2 !== 2'b00)
            $fatal(1,"Los comandos de retorno no se liberaron");
        esperar_cuadro(3'd3,3'd3);
        $display("PASS: movimientos inversos actualizan la imagen");

        // Presionar UP+DOWN simultaneos: ambos comandos = 00.
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J1_DOWN_N = 1'b0;
        J2_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;
        repeat (NDB_TB + 8) @(negedge CLK_SYS);
        if (dut.CMD_J1 !== 2'b00 || dut.CMD_J2 !== 2'b00)
            $fatal(1,"UP+DOWN simultaneos no se neutralizaron");
        repeat (2*PADDLE_TB + 30) @(negedge CLK_SYS);
        if (dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
            $fatal(1,"UP+DOWN simultaneos movieron una paleta");
        J1_UP_N = 1'b1;
        J1_DOWN_N = 1'b1;
        J2_UP_N = 1'b1;
        J2_DOWN_N = 1'b1;
        esperar_cuadro(3'd3,3'd3);
        $display("PASS: UP+DOWN simultaneos no mueven paletas");

        $display("PASS: controles cableados J1 y J2 + antirrebote");
        $display("PASS: movimientos de ambas paletas reflejados en MAX7219");
        $display("PASS: todas las tramas verificadas con 32 bits");
        $finish;
    end

    initial begin
        #10000000;   // 10 ms de margen con parametros abreviados
        $fatal(1,"TIMEOUT: prueba de controles incompleta");
    end

endmodule