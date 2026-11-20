module supervisor_cableado #(
    // 20 ms a 50 MHz
    parameter [19:0] NDB = 20'd1000000
)(
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Jugador 1: entradas activas en bajo
    input wire J1_UP_N,
    input wire J1_DOWN_N,
    input wire J1_DETECT_N,

    // Jugador 2: entradas activas en bajo
    input wire J2_UP_N,
    input wire J2_DOWN_N,
    input wire J2_DETECT_N,

    // Comandos hacia las paletas
    output wire [1:0] CMD_J1,
    output wire [1:0] CMD_J2,

    // Compatibilidad con la FSM existente
    output wire RF1_OK_EFF,
    output wire RF2_OK_EFF,
    output wire RF_OK_EFF
);

    // ----------------------------------------
    // 1. Entradas sincronizadas y filtradas
    // ----------------------------------------

    wire J1_UP_CLEAN_N;
    wire J1_DOWN_CLEAN_N;
    wire J1_DETECT_CLEAN_N;

    wire J2_UP_CLEAN_N;
    wire J2_DOWN_CLEAN_N;
    wire J2_DETECT_CLEAN_N;

    // ----------------------------------------
    // 2. Filtros del jugador 1
    // ----------------------------------------

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j1_up (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J1_UP_N),
        .CLEAN_N(J1_UP_CLEAN_N)
    );

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j1_down (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J1_DOWN_N),
        .CLEAN_N(J1_DOWN_CLEAN_N)
    );

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j1_detect (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J1_DETECT_N),
        .CLEAN_N(J1_DETECT_CLEAN_N)
    );

    // ----------------------------------------
    // 3. Filtros del jugador 2
    // ----------------------------------------

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j2_up (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J2_UP_N),
        .CLEAN_N(J2_UP_CLEAN_N)
    );

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j2_down (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J2_DOWN_N),
        .CLEAN_N(J2_DOWN_CLEAN_N)
    );

    filtro_entrada_cableada #(
        .NDB(NDB)
    ) u_j2_detect (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .RAW_N(J2_DETECT_N),
        .CLEAN_N(J2_DETECT_CLEAN_N)
    );

    // ----------------------------------------
    // 4. Deteccion de controles conectados
    // ----------------------------------------
    // DETECT_N = 0: control conectado
    // DETECT_N = 1: control desconectado

    assign RF1_OK_EFF = !J1_DETECT_CLEAN_N;
    assign RF2_OK_EFF = !J2_DETECT_CLEAN_N;

    assign RF_OK_EFF =
        RF1_OK_EFF && RF2_OK_EFF;

    // ----------------------------------------
    // 5. Comando del jugador 1
    // ----------------------------------------
    // 01 = subir
    // 10 = bajar
    // 00 = mantener
    //
    // Ambos botones presionados = mantener.
    // Control desconectado = mantener.

    assign CMD_J1 =
        !RF1_OK_EFF ? 2'b00 :
        (!J1_UP_CLEAN_N &&
          J1_DOWN_CLEAN_N) ? 2'b01 :
        ( J1_UP_CLEAN_N &&
         !J1_DOWN_CLEAN_N) ? 2'b10 :
        2'b00;

    // ----------------------------------------
    // 6. Comando del jugador 2
    // ----------------------------------------

    assign CMD_J2 =
        !RF2_OK_EFF ? 2'b00 :
        (!J2_UP_CLEAN_N &&
          J2_DOWN_CLEAN_N) ? 2'b01 :
        ( J2_UP_CLEAN_N &&
         !J2_DOWN_CLEAN_N) ? 2'b10 :
        2'b00;

endmodule