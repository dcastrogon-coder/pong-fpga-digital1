// ============================================================================
//  modelo_max7219.v
//  Modelo de comportamiento (NO sintetizable) de un MAX7219, para simulación.
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Lo escribimos leyendo la hoja de datos, a propósito sin mirar nuestro
//  transmisor, para que el testbench sea un "receptor" independiente:
//   - registro de desplazamiento de 16 bits que avanza con el flanco de
//     subida de CLK;
//   - DOUT entrega el bit más significativo y cambia en el flanco de bajada,
//     así se pueden poner varios chips en cadena;
//   - en el flanco de subida de LOAD se enclava la palabra: D11-D8 dirección,
//     D7-D0 dato.
//  Además vigila los tiempos mínimos de la hoja de datos (tabla de "Timing
//  Characteristics") y cuenta cuántas veces se violan.
// ============================================================================

`timescale 1ns / 1ps

module modelo_max7219 #(
    parameter real T_CH   = 50.0,   // ancho mínimo de CLK en alto (ns)
    parameter real T_CL   = 50.0,   // ancho mínimo de CLK en bajo (ns)
    parameter real T_DS   = 25.0,   // setup de DIN antes del flanco de CLK (ns)
    parameter real T_LDCK = 50.0,   // de subida de LOAD a la siguiente subida de CLK (ns)
    parameter real T_CSW  = 50.0    // ancho mínimo de LOAD en alto (ns)
)(
    input  wire din,
    input  wire clk,
    input  wire load,
    output reg  dout
);

    reg [15:0] sr = 16'h0000;
    reg [7:0]  digito [1:8];
    reg [7:0]  reg_decode   = 8'hxx;
    reg [7:0]  reg_brillo   = 8'hxx;
    reg [7:0]  reg_scan     = 8'hxx;
    reg [7:0]  reg_shutdown = 8'h00;   // al encender el chip arranca en shutdown
    reg [7:0]  reg_test     = 8'h00;

    integer clks_desde_load = 0;
    integer clks_ultima     = -1;   // cuántos CLK hubo entre los dos últimos LOAD
    integer palabras        = 0;
    integer violaciones     = 0;
    integer i;

    realtime t_clk_sube = -1000, t_clk_baja = -1000, t_din = -1000;
    realtime t_load_sube = -1000;

    initial begin
        dout = 1'b0;
        for (i = 1; i <= 8; i = i + 1) digito[i] = 8'h00;
    end

    always @(din) t_din = $realtime;

    always @(posedge clk) begin
        if ($realtime - t_clk_baja < T_CL && t_clk_baja >= 0) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] CLK en bajo muy corto: %0.1f ns", $realtime - t_clk_baja);
        end
        if ($realtime - t_din < T_DS) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] setup de DIN violado: %0.1f ns", $realtime - t_din);
        end
        if (t_load_sube >= 0 && $realtime - t_load_sube < T_LDCK) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] CLK muy pronto despues de LOAD: %0.1f ns", $realtime - t_load_sube);
        end
        t_clk_sube = $realtime;
        sr <= {sr[14:0], din};
        clks_desde_load = clks_desde_load + 1;
    end

    always @(negedge clk) begin
        if ($realtime - t_clk_sube < T_CH) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] CLK en alto muy corto: %0.1f ns", $realtime - t_clk_sube);
        end
        t_clk_baja = $realtime;
        dout <= sr[15];
    end

    always @(posedge load) begin
        if (clk === 1'b1 && $realtime == t_clk_sube) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] LOAD subio al mismo tiempo que CLK");
        end
        t_load_sube = $realtime;
        case (sr[11:8])
            4'h0: ;                                   // no-op
            4'h1, 4'h2, 4'h3, 4'h4,
            4'h5, 4'h6, 4'h7, 4'h8: digito[sr[11:8]] = sr[7:0];
            4'h9: reg_decode   = sr[7:0];
            4'hA: reg_brillo   = sr[7:0];
            4'hB: reg_scan     = sr[7:0];
            4'hC: reg_shutdown = sr[7:0];
            4'hF: reg_test     = sr[7:0];
            default: ;
        endcase
        palabras        = palabras + 1;
        clks_ultima     = clks_desde_load;
        clks_desde_load = 0;
    end

    always @(negedge load) begin
        if ($realtime - t_load_sube < T_CSW) begin
            violaciones = violaciones + 1;
            $display("  [MAX7219 %m] pulso de LOAD muy corto: %0.1f ns", $realtime - t_load_sube);
        end
    end

    // El chip está mostrando algo solo si salió de shutdown y no está en test
    wire operando = reg_shutdown[0] && !reg_test[0];

endmodule
