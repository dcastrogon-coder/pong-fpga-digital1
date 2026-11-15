`timescale 1ns/1ps

module tb_imagen;

    reg [12:0] SNAPSHOT;
    reg [2:0] ROW_IDX;

    wire [7:0] DATA_A;
    wire [7:0] DATA_B;

    integer pruebas_dir;
    integer pruebas_exh;
    integer snap_n;
    integer fila_n;

    localparam [12:0] S_INIT =
        {3'd3, 3'd3, 4'd7, 3'd3};

    // ------------------------------------
    // 1. Modulo bajo prueba
    // ------------------------------------

    imagen dut (
        .SNAPSHOT(SNAPSHOT),
        .ROW_IDX(ROW_IDX),
        .DATA_A(DATA_A),
        .DATA_B(DATA_B)
    );

    // ------------------------------------
    // Ajuste F4 (orientacion fisica)
    // ------------------------------------
    // En la prueba visual de F4 (7 nov) vimos que las matrices
    // quedaban en espejo y corregimos imagen.v: ahora la columna 0
    // de cada matriz es el bit 0 del byte (antes era el bit 7).
    // Para no reescribir todas las tablas de este testbench, le
    // damos la vuelta a cada byte esperado con esta funcion.
    function [7:0] rev8;
        input [7:0] v;
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1)
                rev8[k] = v[7 - k];
        end
    endfunction

    // ------------------------------------
    // 2. Prueba dirigida
    // ------------------------------------

    task comprobar_dir;
        input [12:0] s;
        input [2:0] f;
        input [7:0] esperado_a;
        input [7:0] esperado_b;
        input [8*72-1:0] nombre;

        begin
            // Ajuste F4: los valores escritos abajo siguen la
            // orientacion de F3; aqui los pasamos a la de F4.
            esperado_a = rev8(esperado_a);
            esperado_b = rev8(esperado_b);

            SNAPSHOT = s;
            ROW_IDX = f;

            #1;

            if (DATA_A !== esperado_a ||
                DATA_B !== esperado_b) begin

                $display("ERROR: %0s", nombre);

                $display(
                    "Esperado A=%02h B=%02h",
                    esperado_a, esperado_b
                );

                $display(
                    "Obtenido A=%02h B=%02h",
                    DATA_A, DATA_B
                );

                $stop;
            end

            pruebas_dir = pruebas_dir + 1;

            $display(
                "OK: %0s | FILA=%0d A=%02h B=%02h",
                nombre, f, DATA_A, DATA_B
            );
        end
    endtask

    // ------------------------------------
    // 3. Modelo de referencia
    // ------------------------------------

    task comprobar_exh;
        input [12:0] s;
        input [2:0] f;

        integer py1;
        integer py2;
        integer bx;
        integer by;

        reg [15:0] fila_esperada;

        begin

            SNAPSHOT = s;
            ROW_IDX = f;

            // Separar campos del SNAPSHOT
            py1 = s[12:10];
            py2 = s[9:7];
            bx  = s[6:3];
            by  = s[2:0];

            // Modelo de una fila de 16 LEDs
            fila_esperada = 16'h0000;

            // Columna 0: paleta izquierda
            if ((f == py1) ||
                (f == py1 + 1))
                fila_esperada[15] = 1'b1;

            // Columna 15: paleta derecha
            if ((f == py2) ||
                (f == py2 + 1))
                fila_esperada[0] = 1'b1;

            // Columna correspondiente
            // a la pelota
            if (f == by)
                fila_esperada[15 - bx] = 1'b1;

            // Ajuste F4: misma fila, con cada byte al reves
            fila_esperada = {rev8(fila_esperada[15:8]),
                             rev8(fila_esperada[7:0])};

            #1;

            // Comparacion de 16 bits
            if ({DATA_A, DATA_B} !==
                fila_esperada) begin

                $display("ERROR EXHAUSTIVO");

                $display(
                    "SNAPSHOT=%04h FILA=%0d",
                    s, f
                );

                $display(
                    "Esperado A=%02h B=%02h",
                    fila_esperada[15:8],
                    fila_esperada[7:0]
                );

                $display(
                    "Obtenido A=%02h B=%02h",
                    DATA_A, DATA_B
                );

                $stop;
            end

            pruebas_exh = pruebas_exh + 1;

        end
    endtask

    // ------------------------------------
    // 4. Secuencia de simulacion
    // ------------------------------------

    initial begin

        SNAPSHOT = 13'd0;
        ROW_IDX = 3'd0;

        pruebas_dir = 0;
        pruebas_exh = 0;

        $display("------------------------------");
        $display("TESTBENCH IMAGEN 8x16");
        $display("------------------------------");

        // =================================
        // A. PRUEBAS DIRIGIDAS
        // =================================

        // 1. Estado inicial: fila 3
        // Paleta izquierda + pelota
        // + paleta derecha
        comprobar_dir(
            S_INIT, 3'd3,
            8'h81, 8'h01,
            "Inicio: fila 3"
        );

        // 2. Estado inicial: fila 4
        // Ambas paletas
        comprobar_dir(
            S_INIT, 3'd4,
            8'h80, 8'h01,
            "Inicio: fila 4"
        );

        // 3. Fila vacia superior
        comprobar_dir(
            S_INIT, 3'd0,
            8'h00, 8'h00,
            "Inicio: fila vacia superior"
        );

        // 4. Fila vacia inferior
        comprobar_dir(
            S_INIT, 3'd7,
            8'h00, 8'h00,
            "Inicio: fila vacia inferior"
        );

        // 5. Pelota en columna 8
        // Cruce entre los dos MAX7219
        comprobar_dir(
            {3'd3,3'd3,4'd8,3'd3},
            3'd3,
            8'h80, 8'h81,
            "Pelota en columna 8"
        );

        // 6. Pelota sobre paleta J1
        comprobar_dir(
            {3'd0,3'd6,4'd0,3'd0},
            3'd0,
            8'h80, 8'h00,
            "Superposicion con paleta J1"
        );

        // 7. Pelota sobre paleta J2
        comprobar_dir(
            {3'd0,3'd6,4'd15,3'd7},
            3'd7,
            8'h00, 8'h01,
            "Superposicion con paleta J2"
        );

        // 8. Pelota en columna 14
        comprobar_dir(
            {3'd2,3'd5,4'd14,3'd4},
            3'd4,
            8'h00, 8'h02,
            "Pelota en columna 14"
        );

        // 9. Pelota en columna 7
        comprobar_dir(
            {3'd2,3'd5,4'd7,3'd3},
            3'd3,
            8'h81, 8'h00,
            "Pelota en columna 7"
        );

        // 10. Objetos en ambos extremos
        comprobar_dir(
            {3'd0,3'd6,4'd15,3'd0},
            3'd0,
            8'h80, 8'h01,
            "Objetos en extremos"
        );

        $display(
            "PRUEBAS DIRIGIDAS: %0d",
            pruebas_dir
        );

        // =================================
        // B. VERIFICACION EXHAUSTIVA
        // =================================

        // 13 bits de SNAPSHOT:
        // 2^13 = 8192 combinaciones.
        //
        // 3 bits de ROW_IDX:
        // 8 filas.
        //
        // Total: 8192 x 8 = 65536.

        for (snap_n = 0;
             snap_n < 8192;
             snap_n = snap_n + 1) begin

            for (fila_n = 0;
                 fila_n < 8;
                 fila_n = fila_n + 1) begin

                comprobar_exh(
                    snap_n[12:0],
                    fila_n[2:0]
                );

            end
        end

        // =================================
        // C. RESULTADO FINAL
        // =================================

        $display("------------------------------");

        $display(
            "PRUEBAS DIRIGIDAS: %0d",
            pruebas_dir
        );

        $display(
            "PRUEBAS EXHAUSTIVAS: %0d",
            pruebas_exh
        );

        $display(
            "TOTAL VERIFICADO: %0d",
            pruebas_dir + pruebas_exh
        );

        $display(
            "FIN TESTBENCH IMAGEN"
        );

        $display("------------------------------");

        $finish;

    end

endmodule