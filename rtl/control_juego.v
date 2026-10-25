// ============================================================================
//  control_juego.v
//  Proyecto final Electrónica Digital 1 - Pong en FPGA (UNAL Bogotá)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Máquina de estados general del juego (R05, R06 y R09).
//
//  Estados (codificación binaria, 3 bits):
//     ESPERA (000) : recién encendido o reiniciado. La pelota titila en el
//                    centro y las paletas ya se pueden mover. START empieza.
//     JUEGO  (001) : la pelota avanza con tick_bola y se cuentan goles.
//     PUNTO  (010) : alguien anotó. Congelamos todo PAUSA_PUNTO_MS para que
//                    se vea dónde se escapó la pelota y luego sacamos.
//     PAUSA  (011) : START durante el juego, o se cayó el enlace RF.
//     FIN    (100) : alguien llegó a PUNTOS_VICTORIA. La mitad del ganador
//                    titila hasta que presionen START.
//     Los códigos 101, 110 y 111 no se usan; si el registro cayera ahí por
//     cualquier razón, la máquina vuelve a ESPERA en el siguiente ciclo.
//
//  Tabla de transición (las condiciones se evalúan en este orden, de modo
//  que la prioridad queda definida sin ambigüedad):
//
//   Estado | Condición                         | Siguiente | Acción
//   -------+-----------------------------------+-----------+--------------------
//   ESPERA | start · enlace_ok                 | JUEGO     | -
//   JUEGO  | gol_j1 + gol_j2                   | PUNTO     | recordar quién perdió
//   JUEGO  | enlace_ok'                        | PAUSA     | -
//   JUEGO  | start                             | PAUSA     | -
//   PUNTO  | fin de la espera · (gana1+gana2)  | FIN       | -
//   PUNTO  | fin de la espera                  | JUEGO     | saque hacia quien perdió
//   PAUSA  | start · enlace_ok                 | JUEGO     | -
//   FIN    | start                             | ESPERA    | limpiar marcador + saque
//   (cualquiera) | RESET                       | ESPERA    | todo a valores iniciales
//
//  En JUEGO pusimos el gol por encima de todo: si en el mismo ciclo llega el
//  gol y se cae el enlace, primero se registra el punto. Si no fuera así, el
//  punto se perdería al pasar a PAUSA.
// ============================================================================

`timescale 1ns / 1ps

module control_juego #(
    parameter integer PAUSA_PUNTO_MS = 1000,
    parameter integer GOLPES_POR_NIVEL = 3    // cada cuántos rebotes en paleta sube la velocidad
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_1ms,
    input  wire       start,          // pulso
    input  wire       enlace_ok,      // ambos controles con enlace válido
    input  wire       gol_j1,
    input  wire       gol_j2,
    input  wire       gana_j1,
    input  wire       gana_j2,
    input  wire       rebote_paleta,

    output reg  [2:0] estado,
    output wire       mover_pelota,
    output wire       contar,
    output wire       paletas_hab,
    output reg        saque,
    output reg        saque_dx,
    output reg        saque_dy,
    output reg  [2:0] saque_y,
    output reg        limpiar,
    output wire [1:0] nivel,
    output reg        ganador          // 0 = J1, 1 = J2 (válido en FIN)
);

    localparam [2:0] ESPERA = 3'b000,
                     JUEGO  = 3'b001,
                     PUNTO  = 3'b010,
                     PAUSA  = 3'b011,
                     FIN    = 3'b100;

    // Salidas de Moore, dependen solo del estado
    assign mover_pelota = (estado == JUEGO);
    assign contar       = (estado == JUEGO);
    assign paletas_hab  = (estado == ESPERA) || (estado == JUEGO) || (estado == PUNTO);

    reg [2:0]  estado_sig;
    reg [15:0] cuenta_ms;        // tiempo transcurrido en PUNTO
    reg        perdio_j2;        // 1 si el último punto lo perdió J2
    reg        alterna;          // va cambiando en cada saque para variar la salida
    reg [3:0]  golpes;           // rebotes en paleta desde el último saque

    wire espera_cumplida = (cuenta_ms >= PAUSA_PUNTO_MS - 1);

    // ------------------------------------------------------------------
    // Lógica de estado siguiente (combinacional)
    // ------------------------------------------------------------------
    always @(*) begin
        estado_sig = estado;
        case (estado)
            ESPERA: if (start && enlace_ok)         estado_sig = JUEGO;
            JUEGO : if (gol_j1 || gol_j2)           estado_sig = PUNTO;
                    else if (!enlace_ok)            estado_sig = PAUSA;
                    else if (start)                 estado_sig = PAUSA;
            PUNTO : if (espera_cumplida) begin
                        if (gana_j1 || gana_j2)     estado_sig = FIN;
                        else                        estado_sig = JUEGO;
                    end
            PAUSA : if (start && enlace_ok)         estado_sig = JUEGO;
            FIN   : if (start)                      estado_sig = ESPERA;
            default:                                estado_sig = ESPERA;
        endcase
    end

    // ------------------------------------------------------------------
    // Registro de estado y acciones asociadas a cada transición
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            estado    <= ESPERA;
            cuenta_ms <= 16'd0;
            perdio_j2 <= 1'b1;      // el primer saque de la partida va hacia J2
            alterna   <= 1'b0;
            golpes    <= 4'd0;
            saque     <= 1'b0;
            saque_dx  <= 1'b1;
            saque_dy  <= 1'b1;
            saque_y   <= 3'd3;
            limpiar   <= 1'b0;
            ganador   <= 1'b0;
        end else begin
            estado  <= estado_sig;
            saque   <= 1'b0;
            limpiar <= 1'b0;

            // Cronómetro de la pausa tras el punto: corre solo en PUNTO
            if (estado != PUNTO)
                cuenta_ms <= 16'd0;
            else if (tick_1ms)
                cuenta_ms <= cuenta_ms + 16'd1;

            // Contamos los rebotes en paleta de la jugada actual
            if (saque)
                golpes <= 4'd0;
            else if (rebote_paleta && golpes != 4'hF)
                golpes <= golpes + 4'd1;

            // Al entrar a PUNTO recordamos quién perdió el punto
            if (estado == JUEGO && estado_sig == PUNTO)
                perdio_j2 <= gol_j1;   // si anotó J1 es porque J2 falló

            // Saque después de un punto: hacia el jugador que acaba de perder
            if (estado == PUNTO && estado_sig == JUEGO) begin
                saque    <= 1'b1;
                saque_dx <= perdio_j2;           // 1 = hacia la derecha (J2)
                saque_dy <= alterna;
                saque_y  <= alterna ? 3'd3 : 3'd4;
                alterna  <= ~alterna;
            end

            // Al terminar la partida guardamos quién ganó
            if (estado == PUNTO && estado_sig == FIN)
                ganador <= gana_j2;

            // Nueva partida desde FIN: limpiamos el marcador y dejamos la
            // pelota lista en el centro, saliendo hacia quien perdió.
            if (estado == FIN && estado_sig == ESPERA) begin
                limpiar  <= 1'b1;
                saque    <= 1'b1;
                saque_dx <= ~ganador;            // si ganó J1 (0) sale hacia J2 (1)
                saque_dy <= alterna;
                saque_y  <= alterna ? 3'd3 : 3'd4;
                alterna  <= ~alterna;
            end
        end
    end

    // Nivel de velocidad: sube cada GOLPES_POR_NIVEL rebotes, máximo 3.
    // Son tres comparadores y un codificador de prioridad.
    assign nivel = (golpes >= 3*GOLPES_POR_NIVEL) ? 2'd3 :
                   (golpes >= 2*GOLPES_POR_NIVEL) ? 2'd2 :
                   (golpes >= 1*GOLPES_POR_NIVEL) ? 2'd1 : 2'd0;

endmodule
