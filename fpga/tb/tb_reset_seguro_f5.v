`timescale 1ns/1ps

module tb_reset_seguro_f5;

    reg CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    reg RESET_RAW_ACTIVE = 1'b0;

    wire POR_REQ;
    wire RESET_CLEAN;

    // Antirrebote reducido para simulacion
    reset_seguro #(
        .NDB(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .RESET_RAW_ACTIVE(RESET_RAW_ACTIVE),
        .POR_REQ(POR_REQ),
        .RESET_CLEAN(RESET_CLEAN)
    );

    integer pruebas = 0;

    task verificar;
        input esperado_por;
        input esperado_reset;
        begin
            if (POR_REQ !== esperado_por ||
                RESET_CLEAN !== esperado_reset) begin

                $display("ERROR prueba %0d", pruebas + 1);
                $display("POR=%b esperado=%b",
                         POR_REQ, esperado_por);
                $display("RESET=%b esperado=%b",
                         RESET_CLEAN, esperado_reset);

                $fatal(1, "Fallo de reset_seguro");
            end

            pruebas = pruebas + 1;
            $display("PASS prueba %0d", pruebas);
        end
    endtask

    initial begin

        // 1. Condicion inicial de encendido
        #1;
        verificar(1'b1, 1'b1);

        // 2. POR termina tras cuatro ciclos
        repeat (4) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b1);

        // 3. RESET se libera tras estabilidad
        repeat (4) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b0);

        // 4. Presionar RESET:
        // afirmacion asincrona
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b1;
        #1;
        verificar(1'b0, 1'b1);

        // 5. Mantener RESET presionado
        repeat (2) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b1);

        // 6. Liberacion demasiado breve
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b0;

        repeat (2) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b1);

        // 7. Nuevo rebote de RESET
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b1;
        #1;
        verificar(1'b0, 1'b1);

        // 8. Liberar nuevamente RESET
        @(negedge CLK_SYS);
        RESET_RAW_ACTIVE = 1'b0;
        #1;
        verificar(1'b0, 1'b1);

        // 9. Esperar liberacion estable
        repeat (7) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b0);

        // 10. RESET permanece inactivo
        repeat (3) @(posedge CLK_SYS);
        #1;
        verificar(1'b0, 1'b0);

        $display("----------------------------");
        $display("RESET F5: %0d/10 PASS", pruebas);
        $display("----------------------------");

        $finish;
    end

endmodule