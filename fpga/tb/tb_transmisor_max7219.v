`timescale 1ns/1ps

module tb_transmisor_max7219;

    localparam integer H_TB = 2;

    // Imagen inicial y segunda imagen
    localparam [12:0] IMG0 =
        {3'd3, 3'd3, 4'd7, 3'd3};

    localparam [12:0] IMG1 =
        {3'd0, 3'd6, 4'd8, 3'd7};

    reg CLK_SYS;
    reg INIT_GLOBAL;

    reg [2:0] YP1, YP2, YB;
    reg [3:0] XB;

    wire CAPTURE_REQ;
    wire FRAME_READY;
    wire FRAME_BUSY;
    wire [12:0] SNAPSHOT;

    wire [2:0] ROW_IDX;
    wire [7:0] DATA_A, DATA_B;

    wire DIN, CLK_LED, LOAD;
    wire FAULT_TX;

    // Contadores del banco de pruebas
    integer solicitudes;
    integer confirmaciones;
    integer inicializaciones;
    integer filas;
    integer transferencias;
    integer bits_actuales;
    integer bits_totales;
    integer pulsos_clk_ok;

    integer duracion_clk;
    integer duracion_load;

    integer fila_ref;
    integer cuadro_ref;

    reg [31:0] recibido;
    reg [31:0] esperado;
    reg [12:0] imagen_ref;

    reg req_anterior;
    reg ready_anterior;

    time ultimo_flanco;

    // ------------------------------------
    // 1. Reloj de 50 MHz
    // ------------------------------------

    initial CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // 2. Captura real de imagen
    // ------------------------------------

    captura_imagen u_captura (
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

    // ------------------------------------
    // 3. Generador real de filas
    // ------------------------------------

    imagen u_imagen (
        .SNAPSHOT(SNAPSHOT),
        .ROW_IDX(ROW_IDX),
        .DATA_A(DATA_A),
        .DATA_B(DATA_B)
    );

    // ------------------------------------
    // 4. Transmisor bajo prueba
    // ------------------------------------

    transmisor_max7219 #(
        .H(H_TB),
        .FAR_IS_B(1'b1)
    ) dut (
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

    // ------------------------------------
    // 5. Reportar errores
    // ------------------------------------

    task error_tb;
        input [8*100-1:0] mensaje;
        begin
            $display(
                "ERROR B8: %0s | tiempo=%0t",
                mensaje, $time
            );
            $stop;
        end
    endtask

    // ------------------------------------
    // 6. Modelo de inicializacion F2
    // ------------------------------------

    function [15:0] init_ref;
        input integer indice;

        begin
            case (indice)
                0:  init_ref = 16'h0F00;
                1:  init_ref = 16'h0C00;
                2:  init_ref = 16'h0900;
                3:  init_ref = 16'h0B07;
                4:  init_ref = 16'h0A08;

                5:  init_ref = 16'h0100;
                6:  init_ref = 16'h0200;
                7:  init_ref = 16'h0300;
                8:  init_ref = 16'h0400;
                9:  init_ref = 16'h0500;
                10: init_ref = 16'h0600;
                11: init_ref = 16'h0700;
                12: init_ref = 16'h0800;

                13: init_ref = 16'h0C01;

                default: init_ref = 16'hFFFF;
            endcase
        end
    endfunction


    // ------------------------------------
    // Ajuste F4 (orientacion fisica)
    // ------------------------------------
    // En la prueba visual de F4 (7 nov) vimos que las matrices
    // quedaban en espejo y corregimos imagen.v: ahora la columna 0
    // de cada matriz es el bit 0 del byte (antes era el bit 7).
    // El modelo de fila de abajo se escribio con la orientacion
    // de F3, asi que volteamos cada byte con esta funcion.
    function [7:0] rev8;
        input [7:0] v;
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1)
                rev8[k] = v[7 - k];
        end
    endfunction

    // ------------------------------------
    // 7. Modelo independiente de fila
    // ------------------------------------

    function [31:0] palabra_fila;
        input [12:0] s;
        input integer r;

        integer py1, py2, bx, by;
        reg [15:0] pixeles;
        reg [3:0] direccion;

        begin
            py1 = s[12:10];
            py2 = s[9:7];
            bx  = s[6:3];
            by  = s[2:0];

            pixeles = 16'h0000;

            if ((r == py1) || (r == py1 + 1))
                pixeles[15] = 1'b1;

            if ((r == py2) || (r == py2 + 1))
                pixeles[0] = 1'b1;

            if (r == by)
                pixeles[15 - bx] = 1'b1;

            // Ajuste F4: la fila 0 va al registro 8 (antes al 1),
            // porque en F4 corregimos la orientacion vertical en
            // transmisor_max7219.v (ROW_ADDR = 8 - ROW_IDX).
            direccion = 4'd8 - r;

            // Primero B lejano; despues A cercano
            palabra_fila = {
                4'h0, direccion, rev8(pixeles[7:0]),
                4'h0, direccion, rev8(pixeles[15:8])
            };
        end
    endfunction

    // ------------------------------------
    // 8. Monitor de solicitudes
    // ------------------------------------

    always @(posedge CAPTURE_REQ) begin

        if (!INIT_GLOBAL) begin

            if (inicializaciones != 14)
                error_tb(
                    "CAPTURE_REQ antes de finalizar INIT"
                );

            if (filas != solicitudes * 8)
                error_tb(
                    "Nueva captura durante un cuadro"
                );

            if (FRAME_BUSY !== 1'b1)
                error_tb(
                    "FRAME_BUSY inactivo en REQUEST"
                );

            solicitudes = solicitudes + 1;

            $display(
                "OK: Solicitud de cuadro %0d",
                solicitudes
            );

        end
    end

    // ------------------------------------
    // 9. Monitor FRAME_READY
    // ------------------------------------

    always @(posedge FRAME_READY) begin

        if (!INIT_GLOBAL) begin

            confirmaciones = confirmaciones + 1;

            if (confirmaciones > solicitudes)
                error_tb(
                    "FRAME_READY sin solicitud previa"
                );

            if (confirmaciones == 1)
                imagen_ref = IMG0;
            else if (confirmaciones == 2)
                imagen_ref = IMG1;
            else
                error_tb(
                    "Confirmacion adicional inesperada"
                );

            if (SNAPSHOT !== imagen_ref)
                error_tb(
                    "SNAPSHOT incorrecto al capturar"
                );

            $display(
                "OK: FRAME_READY %0d SNAP=%04h",
                confirmaciones, SNAPSHOT
            );

        end
    end

    // ------------------------------------
    // 10. Reconstruir bits seriales
    // ------------------------------------

    always @(posedge CLK_LED) begin

        if (!INIT_GLOBAL) begin

            if (LOAD !== 1'b0)
                error_tb(
                    "CLK_LED activo durante LOAD"
                );

            if ((DIN !== 1'b0) &&
                (DIN !== 1'b1))
                error_tb(
                    "DIN contiene X o Z"
                );

            if (bits_actuales >= 32)
                error_tb(
                    "Mas de 32 bits sin LOAD"
                );

            // Verificar periodo entre bits
            if (bits_actuales > 0) begin

                if (($time - ultimo_flanco) !=
                    ((2 * H_TB + 1) * 20))
                    error_tb(
                        "Periodo serial incorrecto"
                    );

            end

            ultimo_flanco = $time;

            recibido = {
                recibido[30:0],
                DIN
            };

            bits_actuales = bits_actuales + 1;
            bits_totales = bits_totales + 1;

        end
    end

    // ------------------------------------
    // 11. Verificar cada pulso LOAD
    // ------------------------------------

    always @(posedge LOAD) begin

        if (!INIT_GLOBAL) begin

            if (CLK_LED !== 1'b0)
                error_tb(
                    "LOAD coincide con CLK_LED alto"
                );

            if (bits_actuales != 32)
                error_tb(
                    "LOAD sin exactamente 32 bits"
                );

            // Las primeras 14 transferencias
            // corresponden a inicializacion.
            if (transferencias < 14) begin

                esperado = {
                    init_ref(inicializaciones),
                    init_ref(inicializaciones)
                };

                if (recibido !== esperado) begin

                    $display(
                        "INIT=%0d REC=%08h ESP=%08h",
                        inicializaciones,
                        recibido,
                        esperado
                    );

                    error_tb(
                        "Instruccion INIT incorrecta"
                    );
                end

                inicializaciones =
                    inicializaciones + 1;

                $display(
                    "OK: INIT %0d/14 WORD=%08h",
                    inicializaciones,
                    recibido
                );

            end

            // Despues se verifican
            // los dos cuadros de 8 filas.
            else begin

                cuadro_ref = filas / 8;
                fila_ref = filas % 8;

                if (cuadro_ref == 0)
                    imagen_ref = IMG0;
                else if (cuadro_ref == 1)
                    imagen_ref = IMG1;
                else
                    error_tb(
                        "Cuadro adicional inesperado"
                    );

                if (solicitudes != cuadro_ref + 1)
                    error_tb(
                        "Cuadro sin captura correcta"
                    );

                if (ROW_IDX !== fila_ref[2:0])
                    error_tb(
                        "Orden de filas incorrecto"
                    );

                if (SNAPSHOT !== imagen_ref)
                    error_tb(
                        "SNAPSHOT cambio durante cuadro"
                    );

                esperado = palabra_fila(
                    imagen_ref, fila_ref
                );

                if (recibido !== esperado) begin

                    $display(
                        "CUADRO=%0d FILA=%0d",
                        cuadro_ref + 1,
                        fila_ref
                    );

                    $display(
                        "REC=%08h ESP=%08h",
                        recibido, esperado
                    );

                    error_tb(
                        "Palabra serial de fila incorrecta"
                    );
                end

                filas = filas + 1;

                $display(
                    "OK: Cuadro %0d Fila %0d/8 WORD=%08h",
                    cuadro_ref + 1,
                    fila_ref + 1,
                    recibido
                );

            end

            transferencias =
                transferencias + 1;

            // Preparar siguiente paquete
            bits_actuales = 0;
            recibido = 32'd0;

        end
    end

    // ------------------------------------
    // 12. Comprobar duraciones y fallos
    // ------------------------------------

    always @(negedge CLK_SYS) begin

        if (!INIT_GLOBAL) begin

            if (FAULT_TX !== 1'b0)
                error_tb(
                    "FAULT_TX activo inesperadamente"
                );

            // CLK_LED alto durante H ciclos
            if (CLK_LED) begin

                duracion_clk = duracion_clk + 1;

            end
            else if (duracion_clk > 0) begin

                if (duracion_clk != H_TB)
                    error_tb(
                        "Duracion CLK_LED alta incorrecta"
                    );

                pulsos_clk_ok = pulsos_clk_ok + 1;
                duracion_clk = 0;

            end

            // LOAD alto durante H ciclos
            if (LOAD) begin

                duracion_load = duracion_load + 1;

            end
            else if (duracion_load > 0) begin

                if (duracion_load != H_TB)
                    error_tb(
                        "Duracion LOAD incorrecta"
                    );

                duracion_load = 0;

            end

            // Pulsos de un ciclo para captura
            if (CAPTURE_REQ && req_anterior)
                error_tb(
                    "CAPTURE_REQ dura mas de un ciclo"
                );

            if (FRAME_READY && ready_anterior)
                error_tb(
                    "FRAME_READY dura mas de un ciclo"
                );

            req_anterior = CAPTURE_REQ;
            ready_anterior = FRAME_READY;

            // Estabilidad entre capturas
            if (confirmaciones == 1 &&
                filas < 8 &&
                SNAPSHOT !== IMG0)
                error_tb(
                    "Imagen 1 modificada durante envio"
                );

            if (confirmaciones == 2 &&
                filas < 16 &&
                SNAPSHOT !== IMG1)
                error_tb(
                    "Imagen 2 modificada durante envio"
                );

        end
    end

    // ------------------------------------
    // 13. Secuencia principal
    // ------------------------------------

    initial begin

        INIT_GLOBAL = 1'b1;

        YP1 = 3'd3;
        YP2 = 3'd3;
        XB  = 4'd7;
        YB  = 3'd3;

        solicitudes = 0;
        confirmaciones = 0;
        inicializaciones = 0;
        filas = 0;
        transferencias = 0;
        bits_actuales = 0;
        bits_totales = 0;
        pulsos_clk_ok = 0;

        duracion_clk = 0;
        duracion_load = 0;

        recibido = 32'd0;
        esperado = 32'd0;
        imagen_ref = IMG0;

        req_anterior = 0;
        ready_anterior = 0;
        ultimo_flanco = 0;

        $display("------------------------------");
        $display("TESTBENCH TRANSMISOR MAX7219");
        $display("------------------------------");

        // Mantener inicializacion
        repeat (3) @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b0;

        // Esperar dos filas del primer cuadro
        wait (filas >= 2);

        // Cambiar las posiciones DEL JUEGO,
        // mientras el primer cuadro continua.
        //
        // La instantanea IMG0 debe conservarse
        // hasta completar sus ocho filas.

        @(negedge CLK_SYS);

        YP1 = 3'd0;
        YP2 = 3'd6;
        XB  = 4'd8;
        YB  = 3'd7;

        $display(
            "OK: Posiciones cambiadas durante cuadro 1"
        );

        // Esperar 8 filas del primer cuadro
        // y 8 filas del segundo.
        wait (filas == 16);

        // Esperar a que termine el ultimo LOAD
        wait (LOAD == 1'b0);

        @(negedge CLK_SYS);

        // --------------------------------
        // 14. Comprobaciones finales
        // --------------------------------

        if (inicializaciones != 14)
            error_tb(
                "Cantidad incorrecta de INIT"
            );

        if (filas != 16)
            error_tb(
                "Cantidad incorrecta de filas"
            );

        if (transferencias != 30)
            error_tb(
                "Cantidad incorrecta de transferencias"
            );

        if (bits_totales != 960)
            error_tb(
                "Cantidad incorrecta de bits"
            );

        if (pulsos_clk_ok != 960)
            error_tb(
                "Cantidad incorrecta de pulsos CLK"
            );

        if (solicitudes != 2 ||
            confirmaciones != 2)
            error_tb(
                "Protocolo de captura incorrecto"
            );

        if (bits_actuales != 0)
            error_tb(
                "Paquete serial incompleto"
            );

        $display("------------------------------");

        $display(
            "INSTRUCCIONES INIT: %0d",
            inicializaciones
        );

        $display(
            "CUADROS VERIFICADOS: %0d",
            filas / 8
        );

        $display(
            "FILAS VERIFICADAS: %0d",
            filas
        );

        $display(
            "TRANSFERENCIAS DE 32 BITS: %0d",
            transferencias
        );

        $display(
            "BITS SERIALES: %0d",
            bits_totales
        );

        $display(
            "PULSOS CLK_LED: %0d",
            pulsos_clk_ok
        );

        $display(
            "CAPTURE_REQ: %0d",
            solicitudes
        );

        $display(
            "FRAME_READY: %0d",
            confirmaciones
        );

        $display(
            "FIN TESTBENCH TRANSMISOR MAX7219"
        );

        $display("------------------------------");

        $finish;

    end

    // ------------------------------------
    // 15. Proteccion contra bloqueo
    // ------------------------------------

    initial begin
        #1000000;
        error_tb(
            "Timeout: transmisor no termino"
        );
        $finish;
    end

endmodule