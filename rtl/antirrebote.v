// ============================================================================
//  antirrebote.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Toda señal que viene de afuera (pulsadores de la tarjeta, receptores RF)
//  es asíncrona respecto a CLK_SYS. Por eso la pasamos primero por dos
//  flip-flops en cascada: así reducimos muchísimo la probabilidad de que un
//  estado metaestable se propague al resto del circuito.
//
//  Después del sincronizador muestreamos la señal una vez por milisegundo y
//  solo aceptamos un cambio cuando N_MUESTRAS lecturas seguidas coinciden.
//  Con N_MUESTRAS = 8 un rebote tiene que durar menos de ~8 ms para
//  desaparecer, que es lo normal en pulsadores mecánicos.
//
//  La polaridad la dejamos como parámetro porque los pulsadores de la tarjeta
//  son activos en bajo, pero las salidas del HT12D (o del receptor que
//  terminemos usando) pueden venir en alto. Hacia adentro todo es activo en alto.
// ============================================================================

`timescale 1ns / 1ps

module antirrebote #(
    parameter integer N_MUESTRAS  = 8,   // lecturas iguales que exigimos antes de aceptar un cambio
    parameter         ACTIVO_BAJO = 0,   // 1 si la señal física vale 0 cuando está "presionada"
    parameter         VALOR_REPOSO = 0   // valor lógico de la salida justo después del reinicio
)(
    input  wire clk,
    input  wire rst,
    input  wire muestrear,    // normalmente tick_1ms
    input  wire entrada,      // señal cruda del pin
    output reg  salida,       // señal limpia, activa en alto
    output reg  flanco_subida // pulso de un ciclo cuando la salida pasa de 0 a 1
);

    // Sincronizador de dos etapas. Les damos un valor inicial de "reposo"
    // para que al configurar la FPGA no aparezca una pulsación fantasma.
    localparam REPOSO_PIN = (ACTIVO_BAJO != 0) ? 1'b1 : 1'b0;

    reg sinc_1 = REPOSO_PIN;
    reg sinc_2 = REPOSO_PIN;

    always @(posedge clk) begin
        sinc_1 <= entrada;
        sinc_2 <= sinc_1;
    end

    // Ya sincronizada, la pasamos a lógica positiva
    wire logica = (ACTIVO_BAJO != 0) ? ~sinc_2 : sinc_2;

    // Contador de lecturas consecutivas distintas a la salida actual.
    // Si una lectura vuelve a coincidir con la salida, el contador arranca de cero.
    reg [7:0] cuenta;

    always @(posedge clk) begin
        if (rst) begin
            cuenta        <= 8'd0;
            salida        <= VALOR_REPOSO;
            flanco_subida <= 1'b0;
        end else begin
            flanco_subida <= 1'b0;
            if (muestrear) begin
                if (logica == salida) begin
                    cuenta <= 8'd0;
                end else if (cuenta >= N_MUESTRAS - 1) begin
                    // Llevamos N_MUESTRAS lecturas iguales: aceptamos el cambio
                    cuenta        <= 8'd0;
                    salida        <= logica;
                    flanco_subida <= logica;   // solo marcamos la subida
                end else begin
                    cuenta <= cuenta + 8'd1;
                end
            end
        end
    end

endmodule
