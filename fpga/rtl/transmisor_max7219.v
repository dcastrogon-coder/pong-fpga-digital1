module transmisor_max7219 #(
    // Divisor nominal: 25 ciclos a 50 MHz
    parameter integer H = 25,

    // Asignacion logica provisional:
    // 1 = B lejano, A cercano.
    // La orientacion fisica se revisara en F4.
    parameter FAR_IS_B = 1'b1
)(
    input wire CLK_SYS,
    input wire INIT_GLOBAL,

    // Interfaz con captura_imagen
    input wire FRAME_READY,
    output wire CAPTURE_REQ,
    output wire FRAME_BUSY,

    // Interfaz con imagen
    output reg [2:0] ROW_IDX,
    input wire [7:0] DATA_A,
    input wire [7:0] DATA_B,

    // Interfaz serial MAX7219
    output wire DIN,
    output wire CLK_LED,
    output wire LOAD,

    // Deteccion de estado interno invalido
    output wire FAULT_TX
);

    // ------------------------------------
    // 1. Estados de la FSM
    // ------------------------------------

    localparam [3:0]
        T0  = 4'd0,   // INIT_SELECT
        T1  = 4'd1,   // IDLE
        T2  = 4'd2,   // REQUEST
        T3  = 4'd3,   // WAIT_READY
        T4  = 4'd4,   // ROW_SELECT
        T5  = 4'd5,   // LOAD_SHIFT
        T6  = 4'd6,   // BIT_LOW
        T7  = 4'd7,   // BIT_HIGH
        T8  = 4'd8,   // BIT_STEP
        T9  = 4'd9,   // LATCH_GUARD
        T10 = 4'd10,  // LATCH_HIGH
        T11 = 4'd11,  // LATCH_POST
        T12 = 4'd12;  // NEXT

    // ------------------------------------
    // 2. Registros del transmisor
    // ------------------------------------

    reg [3:0] STATE_TX;
    reg [3:0] INIT_IDX;
    reg INIT_MODE;

    reg [4:0] BIT_COUNT;
    reg [4:0] DIV_COUNT;

    reg [31:0] SHIFT_REG;

    // ------------------------------------
    // 3. Predicados de control
    // ------------------------------------

    wire H_DONE;
    wire LAST_BIT;
    wire LAST_INIT;
    wire LAST_ROW;

    assign H_DONE =
        (DIV_COUNT == H - 1);

    assign LAST_BIT =
        (BIT_COUNT == 5'd31);

    assign LAST_INIT =
        (INIT_IDX == 4'd13);

    assign LAST_ROW =
        (ROW_IDX == 3'd7);

    // ------------------------------------
    // 4. Instrucciones de inicializacion
    // ------------------------------------

    reg [15:0] INIT_WORD;

    always @(*) begin
        case (INIT_IDX)

            // Display test OFF
            4'd0: INIT_WORD = 16'h0F00;

            // Shutdown
            4'd1: INIT_WORD = 16'h0C00;

            // Decode mode OFF
            4'd2: INIT_WORD = 16'h0900;

            // Scan limit: 8 filas
            4'd3: INIT_WORD = 16'h0B07;

            // Intensidad provisional
            4'd4: INIT_WORD = 16'h0A08;

            // Limpiar filas 1 a 8
            4'd5:  INIT_WORD = 16'h0100;
            4'd6:  INIT_WORD = 16'h0200;
            4'd7:  INIT_WORD = 16'h0300;
            4'd8:  INIT_WORD = 16'h0400;
            4'd9:  INIT_WORD = 16'h0500;
            4'd10: INIT_WORD = 16'h0600;
            4'd11: INIT_WORD = 16'h0700;
            4'd12: INIT_WORD = 16'h0800;

            // Normal operation
            4'd13: INIT_WORD = 16'h0C01;

            default: INIT_WORD = 16'h0000;

        endcase
    end

    // ------------------------------------
    // 5. Construccion de palabras
    // ------------------------------------

    wire [3:0] ROW_ADDR;

    wire [15:0] WORD_A;
    wire [15:0] WORD_B;

    wire [31:0] FRAME32_INIT;
    wire [31:0] FRAME32_ROW;
    wire [31:0] FRAME32;

    // Direcciones MAX7219: 8 a 1
	// Correccion de orientacion vertical
	 assign ROW_ADDR =
			4'd8 - {1'b0, ROW_IDX};

    assign WORD_A =
        {4'b0000, ROW_ADDR, DATA_A};

    assign WORD_B =
        {4'b0000, ROW_ADDR, DATA_B};

    // Inicializar ambos controladores
    // con el mismo comando
    assign FRAME32_INIT =
        {INIT_WORD, INIT_WORD};

    // El controlador lejano recibe
    // primero sus 16 bits.
    assign FRAME32_ROW =
        FAR_IS_B ?
        {WORD_B, WORD_A} :
        {WORD_A, WORD_B};

    assign FRAME32 =
        INIT_MODE ?
        FRAME32_INIT :
        FRAME32_ROW;

    // ------------------------------------
    // 6. Salidas de control
    // ------------------------------------

    assign CAPTURE_REQ =
        (STATE_TX == T2) &&
        !INIT_GLOBAL;

    // Ocupado salvo en IDLE
    assign FRAME_BUSY =
        (STATE_TX != T1);

    // Reloj serial activo durante T7
    assign CLK_LED =
        (STATE_TX == T7) &&
        !INIT_GLOBAL;

    // LOAD alto durante T10
    assign LOAD =
        (STATE_TX == T10) &&
        !INIT_GLOBAL;

    // Dato serial MSB primero
    assign DIN =
        !INIT_GLOBAL &&
        (
            (STATE_TX == T6) ||
            (STATE_TX == T7) ||
            (STATE_TX == T8)
        )
        ? SHIFT_REG[31] : 1'b0;

    // ------------------------------------
    // 7. Detector de fallos
    // ------------------------------------

    wire INVALID_STATE;
    wire INVALID_INIT;
    wire INVALID_DIV;

    // Estados 13, 14 y 15 invalidos
    assign INVALID_STATE =
        STATE_TX[3] &&
        STATE_TX[2] &&
        (STATE_TX[1] || STATE_TX[0]);

    assign INVALID_INIT =
        INIT_MODE &&
        (INIT_IDX > 4'd13);

    // Division nominal de 25 ciclos.
    // El limite de fallo es el de F2.
    assign INVALID_DIV =
        (
            (STATE_TX == T6)  ||
            (STATE_TX == T7)  ||
            (STATE_TX == T9)  ||
            (STATE_TX == T10) ||
            (STATE_TX == T11)
        ) &&
        (DIV_COUNT >= 5'd25);

    assign FAULT_TX =
        INVALID_STATE ||
        INVALID_INIT ||
        INVALID_DIV;

    // ------------------------------------
    // 8. FSM secuencial
    // ------------------------------------

    always @(posedge CLK_SYS) begin

        // Prioridad absoluta de INIT_GLOBAL
        if (INIT_GLOBAL) begin

            STATE_TX <= T0;

            INIT_MODE <= 1'b1;
            INIT_IDX <= 4'd0;

            ROW_IDX <= 3'd0;
            BIT_COUNT <= 5'd0;
            DIV_COUNT <= 5'd0;

            SHIFT_REG <= 32'd0;

        end

        else begin

            // Los estados no temporizados
            // dejan el divisor en cero.
            if (
                (STATE_TX != T6) &&
                (STATE_TX != T7) &&
                (STATE_TX != T9) &&
                (STATE_TX != T10) &&
                (STATE_TX != T11)
            )
                DIV_COUNT <= 5'd0;

            case (STATE_TX)

                // ------------------------
                // T0: seleccionar comando
                // ------------------------

                T0: begin
                    STATE_TX <= T5;
                end

                // ------------------------
                // T1: iniciar nuevo cuadro
                // ------------------------

                T1: begin
                    STATE_TX <= T2;
                end

                // ------------------------
                // T2: solicitar captura
                // ------------------------

                T2: begin
                    STATE_TX <= T3;
                end

                // ------------------------
                // T3: esperar FRAME_READY
                // ------------------------

                T3: begin

                    if (FRAME_READY) begin
                        ROW_IDX <= 3'd0;
                        STATE_TX <= T4;
                    end

                end

                // ------------------------
                // T4: seleccionar fila
                // ------------------------

                T4: begin
                    STATE_TX <= T5;
                end

                // ------------------------
                // T5: cargar 32 bits
                // ------------------------

                T5: begin

                    SHIFT_REG <= FRAME32;

                    BIT_COUNT <= 5'd0;
                    DIV_COUNT <= 5'd0;

                    STATE_TX <= T6;

                end

                // ------------------------
                // T6: CLK_LED bajo
                // ------------------------

                T6: begin

                    if (H_DONE) begin

                        DIV_COUNT <= 5'd0;
                        STATE_TX <= T7;

                    end
                    else begin

                        DIV_COUNT <= DIV_COUNT + 5'd1;

                    end

                end

                // ------------------------
                // T7: CLK_LED alto
                // ------------------------

                T7: begin

                    if (H_DONE) begin

                        DIV_COUNT <= 5'd0;
                        STATE_TX <= T8;

                    end
                    else begin

                        DIV_COUNT <= DIV_COUNT + 5'd1;

                    end

                end

                // ------------------------
                // T8: avanzar bit
                // ------------------------

                T8: begin

                    DIV_COUNT <= 5'd0;

                    if (LAST_BIT) begin

                        // Se enviaron los 32 bits
                        STATE_TX <= T9;

                    end
                    else begin

                        SHIFT_REG <= {
                            SHIFT_REG[30:0],
                            1'b0
                        };

                        BIT_COUNT <= BIT_COUNT + 5'd1;

                        STATE_TX <= T6;

                    end

                end

                // ------------------------
                // T9: margen antes de LOAD
                // ------------------------

                T9: begin

                    if (H_DONE) begin

                        DIV_COUNT <= 5'd0;
                        STATE_TX <= T10;

                    end
                    else begin

                        DIV_COUNT <= DIV_COUNT + 5'd1;

                    end

                end

                // ------------------------
                // T10: pulso LOAD alto
                // ------------------------

                T10: begin

                    if (H_DONE) begin

                        DIV_COUNT <= 5'd0;
                        STATE_TX <= T11;

                    end
                    else begin

                        DIV_COUNT <= DIV_COUNT + 5'd1;

                    end

                end

                // ------------------------
                // T11: margen despues LOAD
                // ------------------------

                T11: begin

                    if (H_DONE) begin

                        DIV_COUNT <= 5'd0;
                        STATE_TX <= T12;

                    end
                    else begin

                        DIV_COUNT <= DIV_COUNT + 5'd1;

                    end

                end

                // ------------------------
                // T12: siguiente operacion
                // ------------------------

                T12: begin

                    if (INIT_MODE) begin

                        if (LAST_INIT) begin

                            // Inicializacion completa
                            INIT_MODE <= 1'b0;
                            ROW_IDX <= 3'd0;

                            STATE_TX <= T1;

                        end
                        else begin

                            // Siguiente instruccion
                            INIT_IDX <= INIT_IDX + 4'd1;

                            STATE_TX <= T0;

                        end

                    end
                    else begin

                        if (LAST_ROW) begin

                            // Cuadro completo:
                            // regresar a IDLE
                            STATE_TX <= T1;

                        end
                        else begin

                            // Siguiente fila
                            ROW_IDX <= ROW_IDX + 3'd1;

                            STATE_TX <= T4;

                        end

                    end

                end

                // ------------------------
                // Estado invalido
                // ------------------------

                default: begin

                    // Salida segura local.
                    // La recuperacion global
                    // se conectara en B10.
                    STATE_TX <= T0;

                end

            endcase

        end

    end

endmodule