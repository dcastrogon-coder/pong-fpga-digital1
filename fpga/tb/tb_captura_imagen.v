`timescale 1ns/1ps

module tb_captura_imagen;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg CAPTURE_REQ;

    reg [2:0] YP1;
    reg [2:0] YP2;
    reg [3:0] XB;
    reg [2:0] YB;

    wire [12:0] SNAPSHOT;
    wire FRAME_READY;

    reg MOVE_SOURCE;
    integer pruebas;

    localparam [12:0] S_INIT =
        {3'd3, 3'd3, 4'd7, 3'd3};

    localparam [12:0] S_A =
        {3'd2, 3'd4, 4'd9, 3'd5};

    localparam [12:0] S_B =
        {3'd0, 3'd6, 4'd14, 3'd7};

    localparam [12:0] S_C =
        {3'd6, 3'd0, 4'd1, 3'd0};

    localparam [12:0] S_OLD =
        {3'd3, 3'd5, 4'd8, 3'd2};

    localparam [12:0] S_NEW =
        {3'd1, 3'd6, 4'd12, 3'd7};

    // Modulo bajo prueba
    captura_imagen dut (
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

    // Reloj de 50 MHz
    initial CLK_SYS = 0;
    always #10 CLK_SYS = ~CLK_SYS;

    // Simular movimiento de las posiciones
    // en el mismo flanco de captura.
    always @(posedge CLK_SYS) begin
        if (MOVE_SOURCE) begin
            YP1 <= 3'd1;
            YP2 <= 3'd6;
            XB  <= 4'd12;
            YB  <= 3'd7;
        end
    end

    // ------------------------------------
    // Tarea de comprobacion
    // ------------------------------------

    task probar;
        input rst, req, mover;
        input [2:0] yp1_in, yp2_in;
        input [3:0] xb_in;
        input [2:0] yb_in;
        input [12:0] snap_esperado;
        input ready_esperado;
        input [8*70-1:0] nombre;

        begin
            @(negedge CLK_SYS);

            INIT_GLOBAL = rst;
            CAPTURE_REQ = req;
            MOVE_SOURCE = mover;

            YP1 = yp1_in;
            YP2 = yp2_in;
            XB  = xb_in;
            YB  = yb_in;

            @(posedge CLK_SYS);
            #1;

            if (SNAPSHOT !== snap_esperado ||
                FRAME_READY !== ready_esperado) begin

                $display("ERROR: %0s", nombre);

                $display(
                    "Esperado SNAP=%h READY=%b",
                    snap_esperado,
                    ready_esperado
                );

                $display(
                    "Obtenido SNAP=%h READY=%b",
                    SNAPSHOT,
                    FRAME_READY
                );

                $stop;
            end

            // Comprobar que las posiciones
            // externas cambiaron en el
            // mismo flanco cuando se solicita.
            if (mover) begin
                if ({YP1, YP2, XB, YB} !== S_NEW) begin
                    $display(
                        "ERROR MOVIMIENTO SIMULTANEO"
                    );
                    $stop;
                end
            end

            pruebas = pruebas + 1;

            $display(
                "OK: %0s | SNAP=%h READY=%b",
                nombre,
                SNAPSHOT,
                FRAME_READY
            );
        end
    endtask

    // ------------------------------------
    // Secuencia de pruebas
    // ------------------------------------

    initial begin

        pruebas = 0;

        INIT_GLOBAL = 0;
        CAPTURE_REQ = 0;
        MOVE_SOURCE = 0;

        YP1 = 0;
        YP2 = 0;
        XB = 0;
        YB = 0;

        // 1. Inicializacion con solicitud
        // simultanea: INIT tiene prioridad.
        probar(
            1,1,0, 0,0,1,0,
            S_INIT,0,
            "Inicializacion global"
        );

        // 2. Cambian las entradas,
        // pero no hay solicitud.
        probar(
            0,0,0, 2,4,9,5,
            S_INIT,0,
            "Retencion sin solicitud"
        );

        // 3. Primera captura valida
        probar(
            0,1,0, 2,4,9,5,
            S_A,1,
            "Primera captura"
        );

        // 4. Liberar CAPTURE_REQ
        probar(
            0,0,0, 0,6,14,7,
            S_A,0,
            "FRAME_READY vuelve a cero"
        );

        // 5. Mantener instantanea
        probar(
            0,0,0, 6,0,1,0,
            S_A,0,
            "Instantanea conservada"
        );

        // 6. Segunda captura
        probar(
            0,1,0, 0,6,14,7,
            S_B,1,
            "Segunda captura"
        );

        // 7. Solicitud consecutiva
        probar(
            0,1,0, 6,0,1,0,
            S_C,1,
            "Capturas consecutivas"
        );

        // 8. Liberar solicitud
        probar(
            0,0,0, 2,4,9,5,
            S_C,0,
            "Liberacion de CAPTURE_REQ"
        );

        // 9. RESET prioritario
        probar(
            1,1,0, 6,6,14,7,
            S_INIT,0,
            "INIT domina captura"
        );

        // 10. Capturar mientras las
        // entradas cambian en el
        // mismo flanco de reloj.
        //
        // Debe capturar S_OLD.
        // Las entradas pasan a S_NEW.
        probar(
            0,1,1, 3,5,8,2,
            S_OLD,1,
            "Captura y movimiento simultaneo"
        );

        // 11. Sin nueva solicitud,
        // conservar la captura anterior.
        probar(
            0,0,0, 1,6,12,7,
            S_OLD,0,
            "Retencion tras movimiento"
        );

        // 12. Capturar nuevas posiciones
        probar(
            0,1,0, 1,6,12,7,
            S_NEW,1,
            "Captura despues del movimiento"
        );

        // 13. Comprobar retencion final
        probar(
            0,0,0, 3,3,7,3,
            S_NEW,0,
            "Retencion final"
        );

        $display("------------------------------");
        $display(
            "PRUEBAS SUPERADAS: %0d",
            pruebas
        );
        $display(
            "FIN TESTBENCH CAPTURA_IMAGEN"
        );
        $display("------------------------------");

        $finish;

    end

endmodule