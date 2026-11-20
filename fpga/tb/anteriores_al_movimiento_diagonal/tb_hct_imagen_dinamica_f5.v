`timescale 1ns/1ps

// FASE 5: inicializacion MAX7219 + tres cuadros con dos cambios
// efectivos de posicion. No modifica el RTL del proyecto.
// Se inyectan SOLO durante un ciclo las condiciones internas de
// movimiento para probar paletas/pelota -> snapshot -> imagen -> SPI.
// No es una prueba de botones fisicos ni de antirrebote.
module tb_hct_imagen_dinamica_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;  // 50 MHz

    wire DIN, CLK_LED, LOAD, HCT_EN;

    pong_f5_controles_top #(
        .HCT_WAIT_CYCLES(12),
        .NDB_RESET_TOP(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_N(1'b1), .RESET_N(1'b1), .PAUSE_N(1'b1),
        .J1_UP_N(1'b1), .J1_DOWN_N(1'b1), .J1_DETECT_N(1'b1),
        .J2_UP_N(1'b1), .J2_DOWN_N(1'b1), .J2_DETECT_N(1'b1),
        .DIN(DIN), .CLK_LED(CLK_LED), .LOAD(LOAD), .HCT_EN(HCT_EN)
    );

    reg [31:0] RX = 32'd0;
    reg [31:0] EXPECTED;
    reg [15:0] CMD;
    integer BITS = 0;
    integer TRAMAS = 0;
    integer CUADRO;
    integer FILA;

    function [15:0] init_word;
        input integer n;
        begin
            case (n)
                 0: init_word = 16'h0F00;
                 1: init_word = 16'h0C00;
                 2: init_word = 16'h0900;
                 3: init_word = 16'h0B07;
                 4: init_word = 16'h0A08;
                 5: init_word = 16'h0100;
                 6: init_word = 16'h0200;
                 7: init_word = 16'h0300;
                 8: init_word = 16'h0400;
                 9: init_word = 16'h0500;
                10: init_word = 16'h0600;
                11: init_word = 16'h0700;
                12: init_word = 16'h0800;
                13: init_word = 16'h0C01;
                default: init_word = 16'hFFFF;
            endcase
        end
    endfunction

    // Valores esperados despues de un avance real de los
    // registros internos de paletas y pelota:
    // 0: inicio      P1=3, P2=3, pelota=(7,3)
    // 1: movimiento P1=2, P2=4, pelota=(8,3)
    // 2: movimiento P1=3, P2=3, pelota=(9,4)
    function [12:0] snapshot_esperado;
        input integer etapa;
        begin
            case (etapa)
                0: snapshot_esperado = {3'd3,3'd3,4'd7,3'd3};
                1: snapshot_esperado = {3'd2,3'd4,4'd8,3'd3};
                2: snapshot_esperado = {3'd3,3'd3,4'd9,3'd4};
                default: snapshot_esperado = 13'h1FFF;
            endcase
        end
    endfunction

    // Se calcula el contenido esperado a partir de posiciones
    // especificas, sin leer DATA_A ni DATA_B del propio DUT.
    function [31:0] trama_esperada;
        input integer etapa;
        input integer fila;
        reg [12:0] pos;
        reg [2:0] yp1, yp2, yb;
        reg [3:0] xb;
        reg [7:0] a, b;
        reg [3:0] addr;
        begin
            pos = snapshot_esperado(etapa);
            yp1 = pos[12:10];
            yp2 = pos[9:7];
            xb  = pos[6:3];
            yb  = pos[2:0];
            addr = 4'd8 - fila;
            a = 8'h00;
            b = 8'h00;

            if ((fila == yp1) || (fila == (yp1 + 1))) a[0] = 1'b1;
            if ((fila == yp2) || (fila == (yp2 + 1))) b[7] = 1'b1;
            if (fila == yb) begin
                if (xb <= 4'd7) a[xb] = 1'b1;
                else            b[xb - 4'd8] = 1'b1;
            end

            // B lejano, A cercano, direccion fisica 8..1.
            trama_esperada = {4'b0000,addr,b,4'b0000,addr,a};
        end
    endfunction

    // Comprobar movimiento efectivo de registros al terminar
    // el primer cuadro; estimular DURANTE UN SOLO reloj.
    task movimiento_1;
        begin
            #1;
            force dut.u_pong_f5.GAME_EN = 1'b1;
            force dut.u_pong_f5.TICK_PADDLE = 1'b1;
            force dut.u_pong_f5.TICK_BALL = 1'b1;
            force dut.u_pong_f5.CMD_J1 = 2'b01; // J1 sube
            force dut.u_pong_f5.CMD_J2 = 2'b10; // J2 baja
            @(posedge CLK_SYS);
            #1;
            release dut.u_pong_f5.CMD_J1;
            release dut.u_pong_f5.CMD_J2;
            release dut.u_pong_f5.TICK_BALL;
            release dut.u_pong_f5.TICK_PADDLE;
            release dut.u_pong_f5.GAME_EN;
            if ({dut.u_pong_f5.YP1,dut.u_pong_f5.YP2,
                 dut.u_pong_f5.XB,dut.u_pong_f5.YB} !== snapshot_esperado(1))
                $fatal(1,"Movimiento 1: posiciones internas incorrectas");
            $display("PASS: movimiento 1 aplicado a paletas y pelota");
        end
    endtask

    // Segundo avance: ambas paletas regresan al centro;
    // la pelota avanza a X=9 y Y=4.
    task movimiento_2;
        begin
            #1;
            force dut.u_pong_f5.GAME_EN = 1'b1;
            force dut.u_pong_f5.TICK_PADDLE = 1'b1;
            force dut.u_pong_f5.TICK_BALL = 1'b1;
            force dut.u_pong_f5.CMD_J1 = 2'b10; // J1 baja
            force dut.u_pong_f5.CMD_J2 = 2'b01; // J2 sube
            @(posedge CLK_SYS);
            #1;
            release dut.u_pong_f5.CMD_J1;
            release dut.u_pong_f5.CMD_J2;
            release dut.u_pong_f5.TICK_BALL;
            release dut.u_pong_f5.TICK_PADDLE;
            release dut.u_pong_f5.GAME_EN;
            if ({dut.u_pong_f5.YP1,dut.u_pong_f5.YP2,
                 dut.u_pong_f5.XB,dut.u_pong_f5.YB} !== snapshot_esperado(2))
                $fatal(1,"Movimiento 2: posiciones internas incorrectas");
            $display("PASS: movimiento 2 aplicado a paletas y pelota");
        end
    endtask

    // MAX7219 muestrea DIN en el flanco ascendente de CLK_LED.
    always @(posedge CLK_LED) begin
        if (HCT_EN !== 1'b1)
            $fatal(1,"CLK_LED antes de habilitar HCT");
        RX = {RX[30:0],DIN};
        BITS = BITS + 1;
        if (BITS > 32)
            $fatal(1,"Mas de 32 bits sin LOAD");
    end

    // Cada pulso LOAD cierra una trama completa de 32 bits.
    always @(posedge LOAD) begin
        if (HCT_EN !== 1'b1)
            $fatal(1,"LOAD antes de habilitar HCT");
        if (BITS != 32)
            $fatal(1,"Trama %0d con %0d bits (esperados 32)",TRAMAS+1,BITS);

        if (TRAMAS < 14) begin
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b1)
                $fatal(1,"INIT_MODE incorrecto durante inicializacion");
            CMD = init_word(TRAMAS);
            EXPECTED = {CMD,CMD};
            if (RX !== EXPECTED)
                $fatal(1,"Inicializacion %0d: RX=%h esperado=%h",TRAMAS+1,RX,EXPECTED);
        end else if (TRAMAS < 38) begin
            CUADRO = (TRAMAS - 14) / 8;
            FILA = (TRAMAS - 14) % 8;
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1,"INIT_MODE activo durante el refresco");
            if (dut.u_pong_f5.u_transmisor_max7219.ROW_IDX !== FILA)
                $fatal(1,"ROW_IDX incorrecto: cuadro %0d fila %0d",CUADRO+1,FILA+1);
            if (FILA == 0 &&
                dut.u_pong_f5.SNAPSHOT !== snapshot_esperado(CUADRO))
                $fatal(1,"Snapshot cuadro %0d: RX=%h esperado=%h",
                       CUADRO+1,dut.u_pong_f5.SNAPSHOT,snapshot_esperado(CUADRO));
            EXPECTED = trama_esperada(CUADRO,FILA);
            if (RX !== EXPECTED)
                $fatal(1,"Cuadro %0d fila %0d: RX=%h esperado=%h",
                       CUADRO+1,FILA+1,RX,EXPECTED);
            $display("PASS: cuadro %0d/3 fila %0d/8 trama %h",
                     CUADRO+1,FILA+1,RX);
            if (FILA == 7)
                $display("PASS: cuadro %0d/3 completo",CUADRO+1);
        end else begin
            $fatal(1,"Trama extra no prevista");
        end

        TRAMAS = TRAMAS + 1;
        BITS = 0;
        RX = 32'd0;

        if (TRAMAS == 22) movimiento_1();
        if (TRAMAS == 30) movimiento_2();

        if (TRAMAS == 38) begin
            #2000;
            if (dut.u_pong_f5.u_transmisor_max7219.INIT_MODE !== 1'b0)
                $fatal(1,"INIT_MODE no se mantiene desactivado");
            if (HCT_EN !== 1'b1)
                $fatal(1,"HCT_EN deshabilitado al terminar");
            $display("PASS: 14/14 comandos de inicializacion");
            $display("PASS: 3/3 cuadros (inicial + 2 cambios)");
            $display("PASS: 24/24 filas dinamicas verificadas");
            $display("PASS: 38/38 tramas de 32 bits correctas");
            $finish;
        end
    end

    initial begin
        #1;
        if (HCT_EN !== 1'b0)
            $fatal(1,"HCT_EN no inicia en cero");
        #30000000; // 30 ms: reinicio observado de ~20 ms
        $fatal(1,"TIMEOUT: imagen dinamica incompleta");
    end

endmodule