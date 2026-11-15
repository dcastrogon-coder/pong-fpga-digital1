`timescale 1ns/1ps
// ============================================================
// PF ELECTRONICA DIGITAL 1 - FASE 3
// TB DE INTEGRACION: COLISIONES E IMPACTOS EN LAS PALETAS,
// MOVIMIENTO NATURAL Y REBOTES VERTICALES.
//
// DUT: pong_top REAL, con parametros temporales reducidos.
// Solo se posicionan temporalmente los FF internos de pelota
// mediante force/release para alcanzar escenarios reproducibles.
// NO se fuerzan TICK_BALL, HIT_J*, GOAL_J*, GAME_EN, STATE,
// CAPTURE_GOAL, POINT_EN ni puntajes.
// NO sintetizable: usar exclusivamente en Questa.
// ============================================================
module tb_pong_colisiones_rebotes;

    localparam [2:0] ESPERA = 3'd0;
    localparam [2:0] JUEGO  = 3'd1;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS; // 50 MHz

    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b1;
    reg PAUSE_RAW = 1'b0;
    reg [1:0] CMD_RX1 = 2'b00;
    reg [1:0] CMD_RX2 = 2'b00;
    reg FRAME_1_VALID = 1'b0;
    reg FRAME_2_VALID = 1'b0;
    reg RF_HEARTBEAT = 1'b0;

    wire DIN, CLK_LED, LOAD;
    wire [3:0] SCORE_J1_BCD, SCORE_J2_BCD;

    integer rf_contador = 0;
    integer chequeos = 0;
    integer hit_j1_contados = 0;
    integer hit_j2_contados = 0;
    integer goles_contados = 0;
    integer puntos_contados = 0;

    pong_top #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4),
        .N_RF(25'd400),
        .N_BALL(24'd48),
        .N_PADDLE(24'd65),
        .H_LED(2),
        .FAR_IS_B(1'b1)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .START_RAW(START_RAW),
        .RESET_RAW(RESET_RAW),
        .PAUSE_RAW(PAUSE_RAW),
        .CMD_RX1(CMD_RX1),
        .FRAME_1_VALID(FRAME_1_VALID),
        .CMD_RX2(CMD_RX2),
        .FRAME_2_VALID(FRAME_2_VALID),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .SCORE_J1_BCD(SCORE_J1_BCD),
        .SCORE_J2_BCD(SCORE_J2_BCD)
    );

    // Ambas conexiones RF reciben tramas validas cada 10 ciclos.
    always @(negedge CLK_SYS) begin
        FRAME_1_VALID = 1'b0;
        FRAME_2_VALID = 1'b0;
        if (RF_HEARTBEAT) begin
            if (rf_contador == 0) begin
                FRAME_1_VALID = 1'b1;
                FRAME_2_VALID = 1'b1;
            end
            if (rf_contador == 9)
                rf_contador = 0;
            else
                rf_contador = rf_contador + 1;
        end else begin
            rf_contador = 0;
        end
    end

    // Observamos los pulsos reales justo antes de cada flanco.
    always @(posedge CLK_SYS) begin
        if (!dut.INIT_GLOBAL) begin
            if (dut.HIT_J1) hit_j1_contados = hit_j1_contados + 1;
            if (dut.HIT_J2) hit_j2_contados = hit_j2_contados + 1;
            if (dut.CAPTURE_GOAL) goles_contados = goles_contados + 1;
            if (dut.POINT_EN) puntos_contados = puntos_contados + 1;
        end
    end

    task esperar_init_y_rf;
        integer n;
        begin
            n = 0;
            while ((dut.INIT_GLOBAL !== 1'b0 ||
                    dut.RF_OK_EFF !== 1'b1) && n < 90) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.INIT_GLOBAL !== 1'b0 || dut.RF_OK_EFF !== 1'b1)
                $fatal(1, "No se libero INIT_GLOBAL o no estan validos los dos enlaces RF");
        end
    endtask

    task iniciar_juego;
        integer n;
        begin
            @(negedge CLK_SYS);
            START_RAW = 1'b1;
            repeat (10) @(negedge CLK_SYS);
            START_RAW = 1'b0;
            n = 0;
            while (dut.STATE !== JUEGO && n < 30) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.STATE !== JUEGO || dut.GAME_EN !== 1'b1)
                $fatal(1, "START no llevo a JUEGO o GAME_EN no esta activo");
        end
    endtask

    task esperar_tick_pelota;
        integer n;
        begin
            n = 0;
            @(negedge CLK_SYS);
            while (dut.TICK_BALL !== 1'b1 && n < 180) begin
                @(negedge CLK_SYS);
                n = n + 1;
            end
            if (dut.TICK_BALL !== 1'b1)
                $fatal(1, "Timeout esperando un TICK_BALL real");
            if (dut.STATE !== JUEGO || dut.GAME_EN !== 1'b1)
                $fatal(1, "El juego salio de JUEGO durante la prueba");
        end
    endtask

    // Deposita un estado fisico valido entre flancos del reloj.
    // En un registro Verilog, tras release conserva el valor
    // depositado hasta la proxima asignacion secuencial.
    task colocar_pelota;
        input [3:0] x;
        input [2:0] y;
        input dx;
        input dy;
        input phase;
        begin
            @(negedge CLK_SYS);
            // Evita alterar el estado justo en un ciclo de tick.
            while (dut.TICK_BALL === 1'b1)
                @(negedge CLK_SYS);
            force dut.u_pelota.XB    = x;
            force dut.u_pelota.YB    = y;
            force dut.u_pelota.DX    = dx;
            force dut.u_pelota.DY    = dy;
            force dut.u_pelota.PHASE = phase;
            #1;
            release dut.u_pelota.XB;
            release dut.u_pelota.YB;
            release dut.u_pelota.DX;
            release dut.u_pelota.DY;
            release dut.u_pelota.PHASE;
            #1;
            if (dut.XB !== x || dut.YB !== y ||
                dut.DX !== dx || dut.DY !== dy || dut.PHASE !== phase)
                $fatal(1, "No se pudo colocar el estado dirigido de pelota");
            if (dut.FAULT_RECOVER !== 1'b0)
                $fatal(1, "La posicion dirigida activo una recuperacion por fallo");
        end
    endtask

    task confirmar_juego_sin_goles;
        begin
            if (dut.STATE !== JUEGO || dut.GAME_EN !== 1'b1 ||
                SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0 ||
                dut.FAULT_RECOVER !== 1'b0)
                $fatal(1, "Estado, marcador o supervisor de fallos alterados");
        end
    endtask

    initial begin
        $display("================================================");
        $display("TB PONG: COLISIONES, IMPACTOS Y REBOTES");
        $display("================================================");

        // 1. Arranque completo y paletas centradas.
        repeat (4) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        RF_HEARTBEAT = 1'b1;
        esperar_init_y_rf();
        if (dut.STATE !== ESPERA ||
            dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.YP1 !== 3'd3 || dut.YP2 !== 3'd3)
            $fatal(1, "Posiciones iniciales incorrectas");
        iniciar_juego();
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 1: reset, dos enlaces RF y START -> JUEGO");

        // 2. Primer tick natural: fase horizontal (PHASE=0).
        esperar_tick_pelota();
        if (dut.XB !== 4'd7 || dut.YB !== 3'd3 ||
            dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
            dut.PHASE !== 1'b0 ||
            dut.HIT !== 1'b0 || dut.GOAL !== 1'b0)
            $fatal(1, "Condiciones previas incorrectas en primer tick");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd8 || dut.YB !== 3'd3 ||
            dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
            dut.PHASE !== 1'b1)
            $fatal(1, "Movimiento horizontal natural incorrecto");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 2: tick natural horizontal (7,3) -> (8,3)");

        // 3. Segundo tick natural: fase vertical (PHASE=1).
        esperar_tick_pelota();
        if (dut.HIT !== 1'b0 || dut.GOAL !== 1'b0)
            $fatal(1, "Colision inesperada en movimiento interior");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd9 || dut.YB !== 3'd4 ||
            dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
            dut.PHASE !== 1'b0)
            $fatal(1, "Movimiento vertical natural incorrecto");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 3: tick natural vertical (8,3) -> (9,4)");

        // 4. Impacto izquierdo: J1 en Y=3,4; la pelota llega
        //    desde XB=1 hacia X=0 en fila 3. No debe haber gol.
        colocar_pelota(4'd1, 3'd3, 1'b0, 1'b1, 1'b0);
        esperar_tick_pelota();
        if (dut.HIT_J1 !== 1'b1 || dut.HIT_J2 !== 1'b0 ||
            dut.GOAL !== 1'b0 || dut.HIT !== 1'b1 ||
            dut.X_CAND !== 4'd0 || dut.Y_CAND !== 3'd3)
            $fatal(1, "J1: fallo al distinguir impacto de gol");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd1 || dut.YB !== 3'd3 ||
            dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
            dut.PHASE !== 1'b1)
            $fatal(1, "Impacto J1: no se retuvo XB o no se invirtio DX");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 4: paleta J1 devuelve pelota sin anotar");

        // 5. Impacto derecho: J2 en Y=3,4; la pelota llega
        //    desde XB=14 hacia X=15 en fila 4.
        colocar_pelota(4'd14, 3'd4, 1'b1, 1'b0, 1'b0);
        esperar_tick_pelota();
        if (dut.HIT_J1 !== 1'b0 || dut.HIT_J2 !== 1'b1 ||
            dut.GOAL !== 1'b0 || dut.HIT !== 1'b1 ||
            dut.X_CAND !== 4'd15 || dut.Y_CAND !== 3'd4)
            $fatal(1, "J2: fallo al distinguir impacto de gol");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd14 || dut.YB !== 3'd4 ||
            dut.DX !== 1'b0 || dut.DY !== 1'b0 ||
            dut.PHASE !== 1'b1)
            $fatal(1, "Impacto J2: no se retuvo XB o no se invirtio DX");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 5: paleta J2 devuelve pelota sin anotar");

        // 6. Rebote en techo: Y=0, DY=0 (hacia arriba),
        //    PHASE=1 habilita componente vertical y la refleja.
        colocar_pelota(4'd7, 3'd0, 1'b1, 1'b0, 1'b1);
        esperar_tick_pelota();
        if (dut.HIT !== 1'b0 || dut.GOAL !== 1'b0 ||
            dut.Y_CAND !== 3'd1)
            $fatal(1, "Candidato vertical incorrecto en pared superior");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd8 || dut.YB !== 3'd1 ||
            dut.DX !== 1'b1 || dut.DY !== 1'b1 ||
            dut.PHASE !== 1'b0)
            $fatal(1, "Rebote vertical superior incorrecto");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 6: rebote superior Y=0 -> 1, DY=abajo");

        // 7. Rebote en piso: Y=7, DY=1 (hacia abajo).
        colocar_pelota(4'd7, 3'd7, 1'b0, 1'b1, 1'b1);
        esperar_tick_pelota();
        if (dut.HIT !== 1'b0 || dut.GOAL !== 1'b0 ||
            dut.Y_CAND !== 3'd6)
            $fatal(1, "Candidato vertical incorrecto en pared inferior");
        @(posedge CLK_SYS); #1;
        if (dut.XB !== 4'd6 || dut.YB !== 3'd6 ||
            dut.DX !== 1'b0 || dut.DY !== 1'b0 ||
            dut.PHASE !== 1'b0)
            $fatal(1, "Rebote vertical inferior incorrecto");
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 7: rebote inferior Y=7 -> 6, DY=arriba");

        // 8. Dos impactos reales, ningun gol ni punto duplicado.
        repeat (3) @(negedge CLK_SYS);
        if (hit_j1_contados !== 1 || hit_j2_contados !== 1 ||
            goles_contados !== 0 || puntos_contados !== 0 ||
            SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0)
            $fatal(1, "Conteo final incorrecto: HIT1=%0d HIT2=%0d GOAL=%0d POINT=%0d", 
                   hit_j1_contados, hit_j2_contados,
                   goles_contados, puntos_contados);
        confirmar_juego_sin_goles();
        chequeos = chequeos + 1;
        $display("OK 8: 2 impactos, 0 goles, 0 puntos, marcador 0:0");

        $display("================================================");
        $display("COMPROBACIONES: %0d / 8", chequeos);
        $display("HIT_J1 OBSERVADOS: %0d", hit_j1_contados);
        $display("HIT_J2 OBSERVADOS: %0d", hit_j2_contados);
        $display("CAPTURE_GOAL OBSERVADOS: %0d", goles_contados);
        $display("POINT_EN OBSERVADOS: %0d", puntos_contados);
        $display("FIN TB_PONG_COLISIONES_REBOTES");
        $display("================================================");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout global: testbench de colisiones incompleto");
    end
endmodule
