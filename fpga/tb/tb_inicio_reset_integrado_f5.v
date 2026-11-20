`timescale 1ns/1ps

module tb_inicio_reset_integrado_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    // Botones normalizados activos en alto
    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b0;
    reg PAUSE_RAW = 1'b0;

    // Controles cableados activos en bajo
    reg J1_UP_N = 1'b1;
    reg J1_DOWN_N = 1'b1;
    reg J1_DETECT_N = 1'b1;

    reg J2_UP_N = 1'b1;
    reg J2_DOWN_N = 1'b1;
    reg J2_DETECT_N = 1'b1;

    wire DIN;
    wire CLK_LED;
    wire LOAD;

    wire [3:0] SCORE_J1_BCD;
    wire [3:0] SCORE_J2_BCD;

    localparam [2:0]
        ESPERA = 3'b000,
        JUEGO  = 3'b001;

    // Valores iniciales para comprobar RESET
    reg [2:0] YP1_INICIAL;
    reg [2:0] YP2_INICIAL;
    reg [3:0] XB_INICIAL;
    reg [2:0] YB_INICIAL;

    integer pruebas = 0;

    // NDB reducido solo para simulacion
    pong_f5_core #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),

        .START_RAW(START_RAW),
        .RESET_RAW(RESET_RAW),
        .PAUSE_RAW(PAUSE_RAW),

        .J1_UP_N(J1_UP_N),
        .J1_DOWN_N(J1_DOWN_N),
        .J1_DETECT_N(J1_DETECT_N),

        .J2_UP_N(J2_UP_N),
        .J2_DOWN_N(J2_DOWN_N),
        .J2_DETECT_N(J2_DETECT_N),

        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),

        .SCORE_J1_BCD(SCORE_J1_BCD),
        .SCORE_J2_BCD(SCORE_J2_BCD)
    );

    task esperar;
        input integer ciclos;
        begin
            repeat (ciclos) @(posedge CLK_SYS);
            #1;
        end
    endtask

    task verificar_estado;
        input [2:0] esperado;
        begin
            if (dut.STATE !== esperado)
                $fatal(1,
                    "Estado incorrecto: %b, esperado %b",
                    dut.STATE, esperado);

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    task verificar_marcador_cero;
        begin
            if (SCORE_J1_BCD !== 4'd0 ||
                SCORE_J2_BCD !== 4'd0)
                $fatal(1, "Marcador no inicializado");

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    task pulsar_start;
        begin
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            esperar(12);

            @(negedge CLK_SYS);
            START_RAW = 1'b0;
            esperar(12);
        end
    endtask

    initial begin

        // 1. Esperar inicializacion global
        esperar(20);
        verificar_estado(ESPERA);

        // 2. Marcadores inicializados
        verificar_marcador_cero();

        // Guardar posiciones de referencia
        YP1_INICIAL = dut.YP1;
        YP2_INICIAL = dut.YP2;
        XB_INICIAL  = dut.XB;
        YB_INICIAL  = dut.YB;

        // 3. Conectar ambos controles
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;

        esperar(16);

        if (dut.RF_OK_EFF !== 1'b1)
            $fatal(1, "Controles no detectados");

        pruebas = pruebas + 1;
        $display("PASS prueba %0d", pruebas);

        // 4. Iniciar una partida
        pulsar_start();
        verificar_estado(JUEGO);

        // 5. El motor debe estar habilitado
        if (dut.GAME_EN !== 1'b1)
            $fatal(1, "GAME_EN no habilitado");

        pruebas = pruebas + 1;
        $display("PASS prueba %0d", pruebas);

        // 6. Presionar RESET durante JUEGO
        @(negedge CLK_SYS);
        RESET_RAW = 1'b1;

        esperar(2);
        verificar_estado(ESPERA);

        // 7. El motor queda deshabilitado
        if (dut.GAME_EN !== 1'b0)
            $fatal(1, "GAME_EN activo durante RESET");

        pruebas = pruebas + 1;
        $display("PASS prueba %0d", pruebas);

        // 8. Marcadores reiniciados
        verificar_marcador_cero();

        // 9. Paletas y pelota reiniciadas
        if (dut.YP1 !== YP1_INICIAL ||
            dut.YP2 !== YP2_INICIAL ||
            dut.XB  !== XB_INICIAL  ||
            dut.YB  !== YB_INICIAL)
            $fatal(1, "Posiciones no reiniciadas");

        pruebas = pruebas + 1;
        $display("PASS prueba %0d", pruebas);

        // 10. Liberar RESET
        @(negedge CLK_SYS);
        RESET_RAW = 1'b0;

        esperar(20);

        if (dut.INIT_GLOBAL !== 1'b0)
            $fatal(1, "INIT_GLOBAL no se libero");

        verificar_estado(ESPERA);

        // 11. Volver a iniciar una partida
        pulsar_start();
        verificar_estado(JUEGO);

        $display("----------------------------");
        $display("INICIO Y RESET F5: %0d/11 PASS",
                 pruebas);
        $display("----------------------------");

        $finish;
    end

    // Proteccion contra simulacion bloqueada
    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule