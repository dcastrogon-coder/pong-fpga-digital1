`timescale 1ns/1ps

module tb_paletas_cableadas_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;
    reg START_PULSE = 1'b0;
    reg TICK_PADDLE = 1'b0;

    // Entradas activas en bajo
    reg J1_UP_N = 1'b1;
    reg J1_DOWN_N = 1'b1;
    reg J1_DETECT_N = 1'b1;

    reg J2_UP_N = 1'b1;
    reg J2_DOWN_N = 1'b1;
    reg J2_DETECT_N = 1'b1;

    wire [1:0] CMD_J1;
    wire [1:0] CMD_J2;
    wire RF1_OK_EFF;
    wire RF2_OK_EFF;
    wire RF_OK_EFF;

    wire [2:0] STATE;
    wire GAME_EN;
    wire CAPTURE_GOAL;
    wire CENTER_EN;

    wire [2:0] YP1;
    wire [2:0] YP2;
    wire [2:0] YP1_EFF;
    wire [2:0] YP2_EFF;

    localparam [2:0]
        ESPERA   = 3'b000,
        JUEGO    = 3'b001,
        PAUSA_RF = 3'b011;

    integer pruebas = 0;

    // 1. Supervisor cableado real
    // NDB reducido solo para simulacion
    supervisor_cableado #(
        .NDB(20'd4)
    ) u_supervisor (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),

        .J1_UP_N(J1_UP_N),
        .J1_DOWN_N(J1_DOWN_N),
        .J1_DETECT_N(J1_DETECT_N),

        .J2_UP_N(J2_UP_N),
        .J2_DOWN_N(J2_DOWN_N),
        .J2_DETECT_N(J2_DETECT_N),

        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),

        .RF1_OK_EFF(RF1_OK_EFF),
        .RF2_OK_EFF(RF2_OK_EFF),
        .RF_OK_EFF(RF_OK_EFF)
    );

    // 2. FSM real
    control_juego u_fsm (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .START_PULSE(START_PULSE),
        .PAUSE_PULSE(1'b0),
        .RF_OK_EFF(RF_OK_EFF),

        .GOAL_J1(1'b0),
        .GOAL_J2(1'b0),
        .WIN_NEXT(1'b0),

        .STATE(STATE),
        .GAME_EN(GAME_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(),
        .CENTER_EN(CENTER_EN),
        .REARM_TIMERS(),
        .SERVE_DIR()
    );

    // 3. Paletas reales
    paletas u_paletas (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CENTER_EN(CENTER_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .GAME_EN(GAME_EN),
        .TICK_PADDLE(TICK_PADDLE),

        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),

        .YP1(YP1),
        .YP2(YP2),
        .YP1_EFF(YP1_EFF),
        .YP2_EFF(YP2_EFF)
    );

    // Esperar sincronizacion y antirrebote
    task estabilizar;
        begin
            repeat (12) @(posedge CLK_SYS);
            #1;
        end
    endtask

    // Pulso START de un ciclo
    task iniciar;
        begin
            @(negedge CLK_SYS);
            START_PULSE = 1'b1;

            @(posedge CLK_SYS);
            #1;

            @(negedge CLK_SYS);
            START_PULSE = 1'b0;
            #1;
        end
    endtask

    // Un tick de movimiento
    task tick_paleta;
        begin
            @(negedge CLK_SYS);
            TICK_PADDLE = 1'b1;

            @(posedge CLK_SYS);
            #1;

            @(negedge CLK_SYS);
            TICK_PADDLE = 1'b0;
            #1;
        end
    endtask

    // Varios ticks de movimiento
    task avanzar;
        input integer cantidad;
        integer i;
        begin
            for (i = 0; i < cantidad; i = i + 1)
                tick_paleta();
        end
    endtask

    // Comprobacion automatica
    task verificar;
        input [2:0] estado_esperado;
        input rf_esperado;
        input [2:0] yp1_esperado;
        input [2:0] yp2_esperado;
        begin
            #1;

            if (STATE !== estado_esperado ||
                RF_OK_EFF !== rf_esperado ||
                YP1 !== yp1_esperado ||
                YP2 !== yp2_esperado) begin

                $display("ERROR prueba %0d",
                         pruebas + 1);

                $display("STATE=%b RF=%b",
                         STATE, RF_OK_EFF);

                $display("YP1=%0d esperado=%0d",
                         YP1, yp1_esperado);

                $display("YP2=%0d esperado=%0d",
                         YP2, yp2_esperado);

                $fatal(1, "Fallo de paletas F5");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    initial begin

        // Inicializacion
        repeat (3) @(posedge CLK_SYS);
        #1;
        INIT_GLOBAL = 1'b0;

        // 1. Posiciones iniciales
        estabilizar();
        verificar(ESPERA, 1'b0, 3'd3, 3'd3);

        // Conectar ambos controles
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;

        estabilizar();

        // 2. Ambos conectados
        verificar(ESPERA, 1'b1, 3'd3, 3'd3);

        // 3. Iniciar partida
        iniciar();
        verificar(JUEGO, 1'b1, 3'd3, 3'd3);

        if (GAME_EN !== 1'b1)
            $fatal(1, "Motor no habilitado");

        // 4. Sin tick, no hay movimiento
        repeat (5) @(posedge CLK_SYS);
        #1;
        verificar(JUEGO, 1'b1, 3'd3, 3'd3);

        // J1 sube y J2 baja simultaneamente
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        J2_DOWN_N = 1'b0;
        estabilizar();

        avanzar(3);

        // 5. Movimiento independiente
        verificar(JUEGO, 1'b1, 3'd0, 3'd6);

        // 6. No superar los limites
        avanzar(2);
        verificar(JUEGO, 1'b1, 3'd0, 3'd6);

        // Ambos botones de J1 presionados
        @(negedge CLK_SYS);
        J1_DOWN_N = 1'b0;
        J2_DOWN_N = 1'b1;
        estabilizar();

        avanzar(2);

        // 7. Conflicto: J1 no se mueve
        verificar(JUEGO, 1'b1, 3'd0, 3'd6);

        if (CMD_J1 !== 2'b00)
            $fatal(1, "Conflicto no bloqueado");

        // Soltar DOWN de J1 y subir J2
        @(negedge CLK_SYS);
        J1_DOWN_N = 1'b1;
        J2_UP_N = 1'b0;
        estabilizar();

        avanzar(1);

        // 8. J2 sube correctamente
        verificar(JUEGO, 1'b1, 3'd0, 3'd5);

        // Desconectar J1 durante JUEGO
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b1;
        estabilizar();

        // 9. Pausa por desconexion
        verificar(PAUSA_RF, 1'b0, 3'd0, 3'd5);

        if (CMD_J1 !== 2'b00 ||
            GAME_EN !== 1'b0)
            $fatal(1, "Desconexion no inhibe juego");

        // 10. Sin movimiento durante pausa
        avanzar(2);
        verificar(PAUSA_RF, 1'b0, 3'd0, 3'd5);

        // Reconectar J1
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        estabilizar();

        // 11. No reanudar automaticamente
        verificar(PAUSA_RF, 1'b1, 3'd0, 3'd5);

        // 12. START permite reanudar
        iniciar();
        verificar(JUEGO, 1'b1, 3'd0, 3'd5);

        // J1 baja y J2 continua subiendo
        @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J1_DOWN_N = 1'b0;
        estabilizar();

        avanzar(1);

        // 13. Movimiento despues de reconexion
        verificar(JUEGO, 1'b1, 3'd1, 3'd4);

        // Soltar ambos botones
        @(negedge CLK_SYS);
        J1_DOWN_N = 1'b1;
        J2_UP_N = 1'b1;
        estabilizar();

        avanzar(2);

        // 14. Paletas mantienen posicion
        verificar(JUEGO, 1'b1, 3'd1, 3'd4);

        $display("----------------------------");
        $display("PALETAS F5: %0d/14 PASS", pruebas);
        $display("----------------------------");

        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout de simulacion");
    end

endmodule