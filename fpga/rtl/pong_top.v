// ============================================================
// PF ELECTRONICA DIGITAL - PONG FPGA
// FASE 3 - Integracion RTL
// FPGA objetivo: Cyclone IV E EP4CE10E22C8
// Reloj nominal: 50 MHz (verificar sobre tarjeta)
//
// IMPORTANTE:
//   - START_RAW, RESET_RAW y PAUSE_RAW son activos en alto.
//   - CMD_RXi y FRAME_i_VALID deben llegar sincronizados y
//     coherentes con CLK_SYS desde el receptor/adaptador RF.
//   - DIN/CLK_LED/LOAD controlan dos MAX7219 en cascada.
//   - FAR_IS_B=1 presupone controlador B lejano.
//   - Se requiere verificar los puertos reales de cada RTL,
//     sintesis, asignacion de pines y adaptacion electrica.
// ============================================================

module pong_top #(
    // Parametros nominales para 50 MHz.
    // Reducibles solo en los testbenches de integracion.
    parameter [19:0] NDB_BUTTON = 20'd1000000,
    parameter [19:0] NDB_RESET  = 20'd1000000,
    parameter [24:0] N_RF       = 25'd25000000,
    parameter [23:0] N_BALL     = 24'd10000000,
    parameter [23:0] N_PADDLE   = 24'd12500000,
    parameter integer H_LED     = 25,
    parameter FAR_IS_B         = 1'b1
)(
    input  wire CLK_SYS,

    // Entradas de botones, activas en alto
    input  wire START_RAW,
    input  wire RESET_RAW,
    input  wire PAUSE_RAW,

    // Interfaz RF ya adaptada a CLK_SYS
    input  wire [1:0] CMD_RX1,
    input  wire       FRAME_1_VALID,
    input  wire [1:0] CMD_RX2,
    input  wire       FRAME_2_VALID,

    // Dos MAX7219 en cascada
    output wire DIN,
    output wire CLK_LED,
    output wire LOAD,

    // Dos decodificadores BCD a 7 segmentos externos
    output wire [3:0] SCORE_J1_BCD,
    output wire [3:0] SCORE_J2_BCD
);

    // --------------------------------------------------------
    // 1. RESET global, deteccion de fallos y botones
    // --------------------------------------------------------
    wire POR_REQ;
    wire RESET_CLEAN;
    wire FAULT_RECOVER;
    wire INIT_GLOBAL;

    wire START_PULSE;
    wire PAUSE_PULSE;

    assign INIT_GLOBAL = POR_REQ | RESET_CLEAN | FAULT_RECOVER;

    reset_seguro #(
        .NDB(NDB_RESET)
    ) u_reset_seguro (
        .CLK_SYS(CLK_SYS),
        .RESET_RAW_ACTIVE(RESET_RAW),
        .POR_REQ(POR_REQ),
        .RESET_CLEAN(RESET_CLEAN)
    );

    boton_evento #(
        .NDB(NDB_BUTTON)
    ) u_start (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .PRESSED_RAW(START_RAW),
        .PRESSED_DB(),
        .PRESS_EVENT(START_PULSE)
    );

    boton_evento #(
        .NDB(NDB_BUTTON)
    ) u_pause (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .PRESSED_RAW(PAUSE_RAW),
        .PRESSED_DB(),
        .PRESS_EVENT(PAUSE_PULSE)
    );

    // --------------------------------------------------------
    // 2. Supervisor de los dos enlaces RF
    // --------------------------------------------------------
    wire [1:0] CMD_J1;
    wire [1:0] CMD_J2;
    wire RF1_OK_EFF;
    wire RF2_OK_EFF;
    wire RF_OK_EFF;

    supervisor_rf #(
        .N_RF(N_RF)
    ) u_supervisor_rf (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CMD_RX1(CMD_RX1),
        .FRAME_1_VALID(FRAME_1_VALID),
        .CMD_RX2(CMD_RX2),
        .FRAME_2_VALID(FRAME_2_VALID),
        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),
        .RF1_OK_EFF(RF1_OK_EFF),
        .RF2_OK_EFF(RF2_OK_EFF),
        .RF_OK_EFF(RF_OK_EFF)
    );

    // --------------------------------------------------------
    // 3. FSM de seis estados y sus senales de control
    // --------------------------------------------------------
    wire [2:0] STATE;
    wire GAME_EN;
    wire CAPTURE_GOAL;
    wire POINT_EN;
    wire CENTER_EN;
    wire REARM_TIMERS;
    wire SERVE_DIR;
    wire WIN_NEXT;

    wire GOAL_J1;
    wire GOAL_J2;

    control_juego u_control_juego (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .START_PULSE(START_PULSE),
        .PAUSE_PULSE(PAUSE_PULSE),
        .RF_OK_EFF(RF_OK_EFF),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .WIN_NEXT(WIN_NEXT),
        .STATE(STATE),
        .GAME_EN(GAME_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .POINT_EN(POINT_EN),
        .CENTER_EN(CENTER_EN),
        .REARM_TIMERS(REARM_TIMERS),
        .SERVE_DIR(SERVE_DIR)
    );

    // --------------------------------------------------------
    // 4. Contadores y ticks de movimiento
    // --------------------------------------------------------
    wire TICK_BALL;
    wire TICK_PADDLE;

    temporizadores #(
        .N_BALL(N_BALL),
        .N_PADDLE(N_PADDLE)
    ) u_temporizadores (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GAME_EN(GAME_EN),
        .REARM_TIMERS(REARM_TIMERS),
        .TICK_BALL(TICK_BALL),
        .TICK_PADDLE(TICK_PADDLE)
    );

    // --------------------------------------------------------
    // 5. Paletas y candidatos efectivos
    // --------------------------------------------------------
    wire [2:0] YP1;
    wire [2:0] YP2;
    wire [2:0] YP1_EFF;
    wire [2:0] YP2_EFF;

    paletas u_paletas (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GAME_EN(GAME_EN),
        .TICK_PADDLE(TICK_PADDLE),
        .CENTER_EN(CENTER_EN),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .CMD_J1(CMD_J1),
        .CMD_J2(CMD_J2),
        .YP1(YP1),
        .YP2(YP2),
        .YP1_EFF(YP1_EFF),
        .YP2_EFF(YP2_EFF)
    );

    // --------------------------------------------------------
    // 6. Pelota con prioridades de gol e impacto
    // --------------------------------------------------------
    wire [3:0] XB;
    wire [2:0] YB;
    wire DX;
    wire DY;
    wire PHASE;
    wire [3:0] X_CAND;
    wire [2:0] Y_CAND;
    wire HIT_J1;
    wire HIT_J2;
    wire HIT;
    wire GOAL;

    // Colisiones informa el jugador; la pelota solo necesita
    // los eventos generales de impacto y gol.
    assign HIT  = HIT_J1  | HIT_J2;
    assign GOAL = GOAL_J1 | GOAL_J2;

    pelota u_pelota (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .GAME_EN(GAME_EN),
        .TICK_BALL(TICK_BALL),
        .CENTER_EN(CENTER_EN),
        .SERVE_DIR(SERVE_DIR),
        .HIT(HIT),
        .GOAL(GOAL),
        .XB(XB),
        .YB(YB),
        .DX(DX),
        .DY(DY),
        .PHASE(PHASE),
        .X_CAND(X_CAND),
        .Y_CAND(Y_CAND)
    );

    // --------------------------------------------------------
    // 7. Colisiones combinacionales
    // --------------------------------------------------------
    colisiones u_colisiones (
        .GAME_EN(GAME_EN),
        .TICK_BALL(TICK_BALL),
        .XB(XB),
        .X_CAND(X_CAND),
        .Y_CAND(Y_CAND),
        .DX(DX),
        .YP1_EFF(YP1_EFF),
        .YP2_EFF(YP2_EFF),
        .HIT_J1(HIT_J1),
        .HIT_J2(HIT_J2),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2)
    );

    // --------------------------------------------------------
    // 8. Puntaje, victoria y buses BCD externos
    // --------------------------------------------------------
    wire [3:0] SCORE_J1;
    wire [3:0] SCORE_J2;

    puntaje u_puntaje (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CAPTURE_GOAL(CAPTURE_GOAL),
        .GOAL_J1(GOAL_J1),
        .GOAL_J2(GOAL_J2),
        .POINT_EN(POINT_EN),
        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),
        .WIN_NEXT(WIN_NEXT)
    );

    marcador_bcd u_marcador_bcd (
        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),
        .SCORE_J1_BCD(SCORE_J1_BCD),
        .SCORE_J2_BCD(SCORE_J2_BCD)
    );

    // --------------------------------------------------------
    // 9. Captura consistente de cuadro y generacion de filas
    // --------------------------------------------------------
    wire CAPTURE_REQ;
    wire FRAME_READY;
    wire FRAME_BUSY;
    wire [12:0] SNAPSHOT;
    wire [2:0] ROW_IDX;
    wire [7:0] DATA_A;
    wire [7:0] DATA_B;

    captura_imagen u_captura_imagen (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .CAPTURE_REQ(CAPTURE_REQ),
        .YP1(YP1),
        .YP2(YP2),
        .XB(XB),
        .YB(YB),
        .SNAPSHOT(SNAPSHOT),
        .FRAME_READY(FRAME_READY)
    );

    imagen u_imagen (
        .SNAPSHOT(SNAPSHOT),
        .ROW_IDX(ROW_IDX),
        .DATA_A(DATA_A),
        .DATA_B(DATA_B)
    );

    // --------------------------------------------------------
    // 10. Transmisor a dos MAX7219 en cascada
    // --------------------------------------------------------
    wire FAULT_TX;

    transmisor_max7219 #(
        .H(H_LED),
        .FAR_IS_B(FAR_IS_B)
    ) u_transmisor_max7219 (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .FRAME_READY(FRAME_READY),
        .CAPTURE_REQ(CAPTURE_REQ),
        .FRAME_BUSY(FRAME_BUSY),
        .ROW_IDX(ROW_IDX),
        .DATA_A(DATA_A),
        .DATA_B(DATA_B),
        .DIN(DIN),
        .CLK_LED(CLK_LED),
        .LOAD(LOAD),
        .FAULT_TX(FAULT_TX)
    );

    // --------------------------------------------------------
    // 11. Supervision combinacional de fallos registrados
    // --------------------------------------------------------
    wire INVALID_FSM;
    wire INVALID_BCD_J1;
    wire INVALID_BCD_J2;
    wire INVALID_YP1;
    wire INVALID_YP2;
    wire INVALID_XB;

    supervisor_fallos u_supervisor_fallos (
        .STATE(STATE),
        .SCORE_J1(SCORE_J1),
        .SCORE_J2(SCORE_J2),
        .YP1(YP1),
        .YP2(YP2),
        .XB(XB),
        .FAULT_TX(FAULT_TX),
        .INVALID_FSM(INVALID_FSM),
        .INVALID_BCD_J1(INVALID_BCD_J1),
        .INVALID_BCD_J2(INVALID_BCD_J2),
        .INVALID_YP1(INVALID_YP1),
        .INVALID_YP2(INVALID_YP2),
        .INVALID_XB(INVALID_XB),
        .FAULT_RECOVER(FAULT_RECOVER)
    );

endmodule