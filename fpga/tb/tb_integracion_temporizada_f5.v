`timescale 1ns/1ps

module tb_integracion_temporizada_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b0;
    reg PAUSE_RAW = 1'b0;

    reg J1_UP_N = 1'b1;
    reg J1_DOWN_N = 1'b1;
    reg J1_DETECT_N = 1'b1;

    reg J2_UP_N = 1'b1;
    reg J2_DOWN_N = 1'b1;
    reg J2_DETECT_N = 1'b1;

    wire DIN, CLK_LED, LOAD;
    wire [3:0] SCORE_J1_BCD;
    wire [3:0] SCORE_J2_BCD;

    localparam [2:0]
        ESPERA = 3'b000,
        JUEGO = 3'b001,
        PAUSA_RF = 3'b011;

    integer pruebas = 0;

    reg [2:0] YP1_GUARDADA;
    reg [2:0] YP2_GUARDADA;
    reg [3:0] XB_GUARDADA;
    reg [2:0] YB_GUARDADA;

    // Nucleo real de F5
    // Parametros reducidos SOLO para simulacion
    pong_f5_core #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4),
        .N_BALL(24'd128),
        .N_PADDLE(24'd16)
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

    task verificar;
        input condicion;
        input [8*80-1:0] descripcion;
        begin
            #1;

            if (condicion !== 1'b1) begin
                $display("ERROR prueba %0d: %0s",
                         pruebas + 1, descripcion);
                $display(
                    "STATE=%b RF=%b GAME_EN=%b",
                    dut.STATE,
                    dut.RF_OK_EFF,
                    dut.GAME_EN
                );
                $display(
                    "YP1=%0d YP2=%0d XB=%0d YB=%0d",
                    dut.YP1, dut.YP2,
                    dut.XB, dut.YB
                );
                $fatal(1, "Fallo integracion temporizada");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d: %0s",
                     pruebas, descripcion);
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

        // 1. Arranque del nucleo
        esperar(25);
        verificar(
            dut.STATE === ESPERA &&
            dut.YP1 === 3'd3 &&
            dut.YP2 === 3'd3 &&
            dut.GAME_EN === 1'b0,
            "Arranque correcto"
        );

        // 2. Conectar ambos controles
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;

        esperar(14);

        verificar(
            dut.RF_OK_EFF === 1'b1,
            "Ambos controles detectados"
        );

        // 3. Iniciar partida mediante START
        pulsar_start();

        verificar(
            dut.STATE === JUEGO &&
            dut.GAME_EN === 1'b1,
            "Partida iniciada"
        );

        // 4. Pulsar J1 UP y J2 DOWN
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;

        esperar(14);

        verificar(
            dut.CMD_J1 === 2'b01 &&
            dut.CMD_J2 === 2'b10,
            "Comandos cableados correctos"
        );

        // 5. Movimiento con ticks reales
        esperar(90);

        verificar(
            dut.YP1 === 3'd0 &&
            dut.YP2 === 3'd6,
            "Paletas llegan a sus limites"
        );

        // 6. Desconectar control J1
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b1;

        esperar(14);

        verificar(
            dut.STATE === PAUSA_RF &&
            dut.RF_OK_EFF === 1'b0 &&
            dut.GAME_EN === 1'b0 &&
            dut.CMD_J1 === 2'b00,
            "Desconexion detiene el juego"
        );

        // Guardar posiciones durante pausa
        YP1_GUARDADA = dut.YP1;
        YP2_GUARDADA = dut.YP2;
        XB_GUARDADA = dut.XB;
        YB_GUARDADA = dut.YB;

        // 7. Comprobar congelamiento
        esperar(140);

        verificar(
            dut.YP1 === YP1_GUARDADA &&
            dut.YP2 === YP2_GUARDADA &&
            dut.XB === XB_GUARDADA &&
            dut.YB === YB_GUARDADA &&
            dut.TICK_BALL === 1'b0 &&
            dut.TICK_PADDLE === 1'b0,
            "Posiciones congeladas durante pausa"
        );

        // 8. Reconectar sin pulsar START
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;

        esperar(14);

        verificar(
            dut.RF_OK_EFF === 1'b1 &&
            dut.STATE === PAUSA_RF &&
            dut.GAME_EN === 1'b0,
            "Reconexion no reanuda automaticamente"
        );

        // 9. Reanudar mediante START
        pulsar_start();

        verificar(
            dut.STATE === JUEGO &&
            dut.GAME_EN === 1'b1,
            "START reanuda la partida"
        );

        // 10. Reiniciar el nucleo
        @(negedge CLK_SYS);
        RESET_RAW = 1'b1;

        esperar(3);

        verificar(
            dut.STATE === ESPERA &&
            dut.GAME_EN === 1'b0 &&
            dut.YP1 === 3'd3 &&
            dut.YP2 === 3'd3 &&
            dut.XB === 4'd7 &&
            dut.YB === 3'd3 &&
            SCORE_J1_BCD === 4'd0 &&
            SCORE_J2_BCD === 4'd0,
            "RESET restaura el estado inicial"
        );

        $display("----------------------------");
        $display(
            "INTEGRACION TEMPORIZADA F5: %0d/10 PASS",
            pruebas
        );
        $display("----------------------------");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule