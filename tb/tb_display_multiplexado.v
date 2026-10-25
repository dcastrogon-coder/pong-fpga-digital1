// ============================================================================
//  tb_display_multiplexado.v  -  Marcador en el display de la tarjeta (T06)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Probamos dos cosas:
//   1. caracter_7seg: los 32 códigos contra una tabla escrita a mano aquí.
//   2. display_multiplexado: con un reloj de 1 MHz (1 ciclo = 1 us) para
//      poder medir los tiempos en microsegundos directamente:
//        - nunca hay dos dígitos encendidos al mismo tiempo;
//        - cada dígito muestra su carácter (reconstruimos los 8 dígitos
//          "mirando" las líneas como lo haría el ojo);
//        - entre un dígito y el siguiente hay un hueco apagado >= 20 us;
//        - cada dígito se enciende una vez cada 4 ms (250 Hz);
//        - un dígito marcado en "apagar" no se enciende nunca.
//  Al final dibujamos el display en ASCII para verlo en el registro.
// ============================================================================

`timescale 1ns / 1ps

module tb_display_multiplexado;

    `include "tb_comun.vh"

    localparam integer CLK_HZ = 1_000_000;

    reg clk = 0, rst = 1;
    always #500 clk = ~clk;   // 1 MHz

    // ------------------------------------------------------------------
    // 1. Tabla de caracteres
    // ------------------------------------------------------------------
    reg  [4:0] codigo;
    wire [6:0] seg_car;
    caracter_7seg u_car (.codigo(codigo), .seg(seg_car));

    function [6:0] esperado_car;       // {g,f,e,d,c,b,a}
        input [4:0] c;
        begin
            case (c)
                0: esperado_car = 7'b0111111;  1: esperado_car = 7'b0000110;
                2: esperado_car = 7'b1011011;  3: esperado_car = 7'b1001111;
                4: esperado_car = 7'b1100110;  5: esperado_car = 7'b1101101;
                6: esperado_car = 7'b1111101;  7: esperado_car = 7'b0000111;
                8: esperado_car = 7'b1111111;  9: esperado_car = 7'b1101111;
                10: esperado_car = 7'b1110110; // H
                11: esperado_car = 7'b0111000; // L
                12: esperado_car = 7'b1110111; // A
                13: esperado_car = 7'b1110011; // P
                14: esperado_car = 7'b0111110; // U
                15: esperado_car = 7'b0111101; // G
                16: esperado_car = 7'b1010100; // n
                17: esperado_car = 7'b1000000; // -
                default: esperado_car = 7'b0000000;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------
    // 2. Display multiplexado
    // ------------------------------------------------------------------
    reg  [39:0] caracteres;
    reg  [7:0]  apagar = 8'h00, punto = 8'h00;
    wire [7:0]  seg, dig;

    display_multiplexado #(.CLK_HZ(CLK_HZ), .T_DIGITO_US(500), .T_APAGADO_US(20),
                           .SEG_ACTIVO_BAJO(1), .DIG_ACTIVO_BAJO(1)) dut (
        .clk(clk), .rst(rst), .caracteres(caracteres), .apagar(apagar), .punto(punto),
        .seg(seg), .dig(dig)
    );

    // Lógica positiva para leer más fácil
    wire [7:0] seg_on = ~seg;
    wire [7:0] dig_on = ~dig;

    // "Ojo": lo último que se vio en cada dígito y cuándo
    reg  [7:0] visto [0:7];
    integer    t_encendido [0:7];
    integer    periodo_medido [0:7];
    integer    i, k, ciclo = 0, encendidos, dobles = 0, hueco = 0, hueco_min = 1000000;
    reg  [7:0] dig_ant = 8'h00;
    integer    activo_ant = -1;

    always @(posedge clk) begin
        ciclo = ciclo + 1;
        if (!rst) begin
            encendidos = 0;
            for (k = 0; k < 8; k = k + 1) if (dig_on[k]) encendidos = encendidos + 1;
            if (encendidos > 1) dobles = dobles + 1;

            if (encendidos == 0) hueco = hueco + 1;
            for (k = 0; k < 8; k = k + 1)
                if (dig_on[k]) begin
                    visto[k] = seg_on;
                    if (!dig_ant[k]) begin
                        // acaba de encender: medimos el hueco y el periodo
                        if (activo_ant != -1 && activo_ant != k && hueco < hueco_min) hueco_min = hueco;
                        if (t_encendido[k] > 0) periodo_medido[k] = ciclo - t_encendido[k];
                        t_encendido[k] = ciclo;
                        activo_ant = k;
                    end
                    hueco = 0;
                end
        end
        dig_ant <= dig_on;
    end

    // Arma la cadena de caracteres como se escribe: [7] a la izquierda
    function [39:0] texto;
        input [4:0] c7, c6, c5, c4, c3, c2, c1, c0;
        begin
            texto = {c7, c6, c5, c4, c3, c2, c1, c0};
        end
    endfunction

    // Dibuja los 8 dígitos tal como los "vio" el testbench
    task dibujar;
        reg [8*40-1:0] l1, l2, l3;
        reg [7:0] s;
        integer d;
        begin
            l1 = ""; l2 = ""; l3 = "";
            for (d = 7; d >= 0; d = d - 1) begin
                s = visto[d];
                l1 = {l1[8*35-1:0], s[0] ? " __  " : "     "};
                l2 = {l2[8*35-1:0], s[5] ? "|" : " ", s[6] ? "__" : "  ", s[1] ? "| " : "  "};
                l3 = {l3[8*35-1:0], s[4] ? "|" : " ", s[3] ? "__" : "  ", s[2] ? "|" : " ", s[7] ? "." : " "};
            end
            $display("     %s", l1);
            $display("     %s", l2);
            $display("     %s", l3);
        end
    endtask

    task limpiar_ojo;
        begin
            for (k = 0; k < 8; k = k + 1) begin visto[k] = 8'h00; t_encendido[k] = 0; periodo_medido[k] = 0; end
        end
    endtask

    task revisar_texto;
        input [39:0] esperado;
        input [8*16-1:0] nombre;
        integer d;
        reg [7:0] e;
        begin
            for (d = 0; d < 8; d = d + 1) begin
                e = {punto[d], esperado_car(esperado[5*d +: 5])};
                if (apagar[d]) e = 8'h00;
                `VERIFICAR(visto[d] == e, $sformatf("%0s: digito %0d muestra %b, se esperaba %b", nombre, d, visto[d], e))
            end
        end
    endtask

    initial begin
        $dumpfile("sim/tb_display_multiplexado.vcd");
        $dumpvars(0, tb_display_multiplexado);
        $display("== tb_display_multiplexado ==");

        // ---- 1. Todos los códigos ----
        for (i = 0; i < 32; i = i + 1) begin
            codigo = i; #1;
            `VERIFICAR(seg_car == esperado_car(i), $sformatf("codigo %0d -> %b", i, seg_car))
        end

        // ---- 2. Marcador "3  HOLA  7" ----
        limpiar_ojo;
        caracteres = texto(3, 18, 10, 0, 11, 12, 18, 7);
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (20_000) @(posedge clk);          // 20 ms = 5 vueltas completas
        $display("  Display con el mensaje de ESPERA y marcador 3-7:");
        dibujar;
        revisar_texto(caracteres, "HOLA");
        `VERIFICAR(dobles == 0, $sformatf("%0d ciclos con dos digitos encendidos", dobles))
        `VERIFICAR(hueco_min >= 20, $sformatf("hueco entre digitos de %0d us", hueco_min))
        for (k = 0; k < 8; k = k + 1)
            `VERIFICAR(periodo_medido[k] == 4000, $sformatf("digito %0d se repite cada %0d us", k, periodo_medido[k]))
        $display("  cada digito se refresca cada %0d us (%0d Hz); hueco minimo entre digitos: %0d us",
                 periodo_medido[0], 1_000_000 / periodo_medido[0], hueco_min);

        // ---- 3. Mensaje de FIN y dígito del ganador apagado (titilando) ----
        limpiar_ojo;
        caracteres = texto(9, 18, 15, 12, 16, 12, 18, 4);   // 9  GAnA  4
        apagar = 8'b1000_0000;                               // el 9 titilando, en su semiciclo apagado
        repeat (20_000) @(posedge clk);
        $display("  Display en FIN con el puntaje del ganador en su semiciclo apagado:");
        dibujar;
        revisar_texto(caracteres, "GAnA");
        `VERIFICAR(t_encendido[7] == 0, "el digito apagado se encendio")
        apagar = 8'h00;

        // ---- 4. Patrón de prueba: todo encendido con punto ----
        limpiar_ojo;
        caracteres = {8{5'd8}};
        punto = 8'hFF;
        repeat (20_000) @(posedge clk);
        $display("  Patron de prueba (todos los segmentos):");
        dibujar;
        revisar_texto(caracteres, "8.8.8.8.");
        `VERIFICAR(dobles == 0, "dos digitos a la vez en el patron de prueba")

        reporte_final("tb_display_multiplexado");
        $finish;
    end

endmodule
