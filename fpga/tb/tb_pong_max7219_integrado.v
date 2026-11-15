`timescale 1ns/1ps
// ============================================================
// PF ELECTRONICA DIGITAL 1 - FASE 3
// Verificacion serial integrada de DOS MAX7219 en cascada.
//
// Revisa 14 instrucciones de inicializacion (ambos chips),
// 2 cuadros completos x 8 filas, 32 bits por LOAD, orden
// LEJANO=B / CERCANO=A, contenido y captura consistente.
//
// El DUT es el pong_top real. Solo H y filtros se reducen
// para acelerar la simulacion. No hay force/release.
// No agregar este archivo a Quartus; solamente a Questa.
// ============================================================
module tb_pong_max7219_integrado;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;  // 50 MHz

    reg START_RAW = 1'b0;
    reg RESET_RAW = 1'b1;
    reg PAUSE_RAW = 1'b0;
    reg [1:0] CMD_RX1 = 2'b00;
    reg [1:0] CMD_RX2 = 2'b00;
    reg FRAME_1_VALID = 1'b0;
    reg FRAME_2_VALID = 1'b0;

    wire DIN, CLK_LED, LOAD;
    wire [3:0] SCORE_J1_BCD, SCORE_J2_BCD;

    // En ESPERA, la imagen es constante. TX debe refrescarla
    // autonomamente aunque GAME_EN=0 y no existan tramas RF.
    pong_top #(
        .NDB_BUTTON(20'd4),
        .NDB_RESET(20'd4),
        .N_RF(25'd200),
        .N_BALL(24'd64),
        .N_PADDLE(24'd80),
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

    function [15:0] init_word;
        input integer n;
        begin
            case (n)
                0:  init_word = 16'h0F00;  // display test desactivado
                1:  init_word = 16'h0C00;  // shutdown mientras configura
                2:  init_word = 16'h0900;  // sin decodificacion BCD
                3:  init_word = 16'h0B07;  // scan de 8 filas
                4:  init_word = 16'h0A08;  // intensidad provisional
                5:  init_word = 16'h0100;
                6:  init_word = 16'h0200;
                7:  init_word = 16'h0300;
                8:  init_word = 16'h0400;
                9:  init_word = 16'h0500;
                10: init_word = 16'h0600;
                11: init_word = 16'h0700;
                12: init_word = 16'h0800;
                13: init_word = 16'h0C01;  // operacion normal
                default: init_word = 16'hxxxx;
            endcase
        end
    endfunction

    reg [31:0] recibido = 32'd0;
    integer bits_transaccion = 0;
    integer bits_totales = 0;
    integer transferencias = 0;
    integer instrucciones_ok = 0;
    integer filas_ok = 0;
    integer solicitudes_captura = 0;
    integer avisos_ready = 0;
    integer filas_referencia_ok = 0;
    integer check_snapshots = 0;
    reg [12:0] snapshot_de_cuadro = 13'd0;
    reg terminado = 1'b0;

    reg [15:0] palabra_lejana;
    reg [15:0] palabra_cercana;
    reg [15:0] esperado_a;
    reg [15:0] esperado_b;
    reg [3:0] direccion;
    integer fila;

    // Observa el protocolo por los PINES de salida del top.
    // MAX7219 captura DIN en el flanco ascendente de CLK_LED.
    always @(posedge CLK_LED) begin
        if (!dut.INIT_GLOBAL) begin
            if (LOAD !== 1'b0)
                $fatal(1, "CLK_LED ascendio mientras LOAD estaba alto");
            if (DIN !== 1'b0 && DIN !== 1'b1)
                $fatal(1, "DIN indefinido durante CLK_LED");
            if (bits_transaccion >= 32)
                $fatal(1, "Mas de 32 bits antes del siguiente LOAD");
            recibido = {recibido[30:0], DIN};
            bits_transaccion = bits_transaccion + 1;
            bits_totales = bits_totales + 1;
        end
    end

    // Un pulso LOAD debe cerrar exactamente dos palabras de 16 bits.
    always @(posedge LOAD) begin
        if (!dut.INIT_GLOBAL) begin
            if (CLK_LED !== 1'b0)
                $fatal(1, "LOAD ascendio con CLK_LED alto");
            if (bits_transaccion != 32)
                $fatal(1, "Transferencia %0d: llegaron %0d bits, no 32",
                       transferencias, bits_transaccion);

            palabra_lejana = recibido[31:16];
            palabra_cercana = recibido[15:0];

            if (transferencias < 14) begin
                esperado_a = init_word(transferencias);
                if (palabra_lejana !== esperado_a ||
                    palabra_cercana !== esperado_a)
                    $fatal(1, "INIT %0d: lejano=%04h cercano=%04h esperado=%04h",
                           transferencias, palabra_lejana, palabra_cercana, esperado_a);
                instrucciones_ok = instrucciones_ok + 1;
            end else begin
                fila = (transferencias - 14) % 8;
                // Ajuste F4: ROW_ADDR = 8 - ROW_IDX (orientacion vertical)
                direccion = 8 - fila;
                esperado_a = {4'b0000, direccion, dut.DATA_A};
                esperado_b = {4'b0000, direccion, dut.DATA_B};

                // FAR_IS_B=1: B es lejano, A es cercano.
                if (palabra_lejana !== esperado_b ||
                    palabra_cercana !== esperado_a)
                    $fatal(1,
                       "FILA %0d (transferencia %0d): B=%04h (esp %04h), A=%04h (esp %04h)",
                       fila, transferencias, palabra_lejana, esperado_b,
                       palabra_cercana, esperado_a);
                if (dut.ROW_IDX !== fila[2:0])
                    $fatal(1, "ROW_IDX=%0d, fila serial=%0d", dut.ROW_IDX, fila);
                filas_ok = filas_ok + 1;

                // La imagen registrada debe mantenerse identica
                // durante las 8 filas de un mismo cuadro.
                if (fila == 0)
                    snapshot_de_cuadro = dut.SNAPSHOT;
                else begin
                    if (dut.SNAPSHOT !== snapshot_de_cuadro)
                        $fatal(1, "SNAPSHOT cambio dentro del cuadro en fila %0d", fila);
                    check_snapshots = check_snapshots + 1;
                end

                // Imagen conocida en ESPERA: paletas desde Y=3,
                // pelota X=7,Y=3. Valores establecidos en F2.
                // Ajuste F4: con la orientacion horizontal corregida, la
                // paleta J1 queda en DATA_A[0] y la J2 en DATA_B[7]
                // (mismos valores de la Tabla X de F7).
                if (fila == 3) begin
                    if (dut.DATA_A !== 8'h81 || dut.DATA_B !== 8'h80)
                        $fatal(1, "Fila 4: A=%02h B=%02h, esperado 81/80",
                               dut.DATA_A, dut.DATA_B);
                    filas_referencia_ok = filas_referencia_ok + 1;
                end
                if (fila == 4) begin
                    if (dut.DATA_A !== 8'h01 || dut.DATA_B !== 8'h80)
                        $fatal(1, "Fila 5: A=%02h B=%02h, esperado 01/80",
                               dut.DATA_A, dut.DATA_B);
                    filas_referencia_ok = filas_referencia_ok + 1;
                end
            end

            transferencias = transferencias + 1;
            recibido = 32'd0;
            bits_transaccion = 0;
            if (transferencias == 30)
                terminado = 1'b1;  // 14 inicializacion + 2 x 8 filas
        end
    end

    always @(posedge CLK_SYS) begin
        if (!dut.INIT_GLOBAL) begin
            if (dut.CAPTURE_REQ)
                solicitudes_captura = solicitudes_captura + 1;
            if (dut.FRAME_READY)
                avisos_ready = avisos_ready + 1;
            if (dut.FAULT_TX)
                $fatal(1, "FAULT_TX se activo durante la transmision");
        end
    end

    initial begin
        $display("===================================================");
        $display("TB PONG: PROTOCOLO INTEGRADO DOBLE MAX7219");
        $display("===================================================");
        repeat (8) @(negedge CLK_SYS);
        RESET_RAW = 1'b0;
        wait (dut.INIT_GLOBAL === 1'b0);
        wait (terminado === 1'b1);
        #1;

        if (transferencias !== 30)
            $fatal(1, "Total transferencias=%0d, esperado 30", transferencias);
        if (instrucciones_ok !== 14)
            $fatal(1, "Solo %0d instrucciones de inicio correctas", instrucciones_ok);
        if (filas_ok !== 16)
            $fatal(1, "Solo %0d filas correctas", filas_ok);
        if (bits_totales !== 960)
            $fatal(1, "Total pulsos CLK_LED=%0d, esperado 960", bits_totales);
        if (solicitudes_captura !== 2 || avisos_ready !== 2)
            $fatal(1, "Handshake: CAPTURE_REQ=%0d FRAME_READY=%0d, esperado 2/2",
                   solicitudes_captura, avisos_ready);
        if (check_snapshots !== 14)
            $fatal(1, "No se comprobo la estabilidad en las 14 filas posteriores");
        if (filas_referencia_ok !== 4)
            $fatal(1, "No coinciden las filas fijas de los dos cuadros");
        if (dut.STATE !== 3'd0 || dut.GAME_EN !== 1'b0 ||
            SCORE_J1_BCD !== 4'd0 || SCORE_J2_BCD !== 4'd0)
            $fatal(1, "Refresco altero el estado ESPERA o los marcadores");

        $display("OK 1: 14 instrucciones de inicializacion identicas en ambos MAX7219");
        $display("OK 2: 32 bits exactos por LOAD; 960 flancos CLK_LED en 30 transferencias");
        $display("OK 3: 8 filas del primer cuadro, direcciones 8..1 y datos correctos");
        $display("OK 4: 8 filas del segundo cuadro, refresco continuo");
        $display("OK 5: B lejano/A cercano en cada palabra de 32 bits");
        $display("OK 6: CAPTURE_REQ/FRAME_READY una vez por cuadro (2/2)");
        $display("OK 7: SNAPSHOT estable durante todas las filas de cada cuadro");
        $display("OK 8: Filas de referencia Y=3,Y=4 y ESPERA/BCD sin cambios");
        $display("===================================================");
        $display("COMPROBACIONES: 8 / 8");
        $display("TRANSFERENCIAS: %0d (14 init + 16 filas)", transferencias);
        $display("FLANCOS CLK_LED: %0d", bits_totales);
        $display("SOLICITUDES CAPTURE_REQ: %0d", solicitudes_captura);
        $display("FRAME_READY: %0d", avisos_ready);
        $display("FIN TB_PONG_MAX7219_INTEGRADO");
        $display("===================================================");
        $finish;
    end

    initial begin
        #300000;
        $fatal(1, "Timeout general: no se completaron 30 transferencias MAX7219");
    end
endmodule
