`timescale 1ns/1ps

module tb_supervisor_cableado_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg INIT_GLOBAL = 1'b1;

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

    // Antirrebote reducido a 4 ciclos
    // SOLO para acelerar la simulacion.
    supervisor_cableado #(
        .NDB(20'd4)
    ) dut (
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

    integer pruebas = 0;

    task estabilizar;
        begin
            repeat (10) @(posedge CLK_SYS);
            #1;
        end
    endtask

    task verificar;
        input [1:0] esperado_j1;
        input [1:0] esperado_j2;
        input esperado_rf1;
        input esperado_rf2;
        begin
            if ((CMD_J1 !== esperado_j1) ||
                (CMD_J2 !== esperado_j2) ||
                (RF1_OK_EFF !== esperado_rf1) ||
                (RF2_OK_EFF !== esperado_rf2) ||
                (RF_OK_EFF !==
                    (esperado_rf1 && esperado_rf2))) begin

                $display("ERROR en prueba %0d", pruebas + 1);
                $display("CMD: J1=%b J2=%b",
                         CMD_J1, CMD_J2);
                $display("DETECT: RF1=%b RF2=%b TOTAL=%b",
                         RF1_OK_EFF, RF2_OK_EFF, RF_OK_EFF);
                $fatal(1, "Fallo de supervisor cableado");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    initial begin

        // Inicializacion
        repeat (3) @(negedge CLK_SYS);
        INIT_GLOBAL = 1'b0;

        // 1. Ambos controles desconectados
        estabilizar();
        verificar(2'b00, 2'b00, 1'b0, 1'b0);

        // 2. Conectar ambos controles
        @(negedge CLK_SYS);
        J1_DETECT_N = 1'b0;
        J2_DETECT_N = 1'b0;
        estabilizar();
        verificar(2'b00, 2'b00, 1'b1, 1'b1);

        // 3. Jugador 1 sube
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        estabilizar();
        verificar(2'b01, 2'b00, 1'b1, 1'b1);

        // 4. Jugador 1 baja
        @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J1_DOWN_N = 1'b0;
        estabilizar();
        verificar(2'b10, 2'b00, 1'b1, 1'b1);

        // 5. Jugador 1 presiona ambos botones
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;
        estabilizar();
        verificar(2'b00, 2'b00, 1'b1, 1'b1);

        // 6. Jugador 2 sube
        @(negedge CLK_SYS);
        J1_UP_N = 1'b1;
        J1_DOWN_N = 1'b1;
        J2_UP_N = 1'b0;
        estabilizar();
        verificar(2'b00, 2'b01, 1'b1, 1'b1);

        // 7. Desconectar jugador 2
        @(negedge CLK_SYS);
        J2_DETECT_N = 1'b1;
        estabilizar();
        verificar(2'b00, 2'b00, 1'b1, 1'b0);

        // 8. Reconectar jugador 2
        @(negedge CLK_SYS);
        J2_DETECT_N = 1'b0;
        estabilizar();
        verificar(2'b00, 2'b01, 1'b1, 1'b1);

        // 9. Soltar el boton del jugador 2
        @(negedge CLK_SYS);
        J2_UP_N = 1'b1;
        estabilizar();
        verificar(2'b00, 2'b00, 1'b1, 1'b1);

        // 10. Pulso breve del jugador 1
        // No debe superar el antirrebote.
        @(negedge CLK_SYS);
        J1_UP_N = 1'b0;

        repeat (2) @(negedge CLK_SYS);
        J1_UP_N = 1'b1;

        estabilizar();
        verificar(2'b00, 2'b00, 1'b1, 1'b1);

        $display("----------------------------");
        $display("SUPERVISOR F5: %0d/10 PASS", pruebas);
        $display("----------------------------");

        $finish;
    end

endmodule