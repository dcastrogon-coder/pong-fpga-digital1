// ============================================================================
//  tb_integracion.v  -  Simulación de extremo a extremo (PC3, T01-T09)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Esta es la prueba que más nos gusta: juega una partida COMPLETA contra el
//  diseño entero (pong_top) con dos "jugadores robot" y una cadena de
//  modelos de MAX7219 (cuatro, como en el módulo x4) colgada de
//  DIN/CLK_LED/LOAD, exactamente como irá en el montaje.
//
//  Escalamos el tiempo para que corra rápido: le decimos al diseño que el
//  reloj es de 20 kHz (20 ciclos por milisegundo) y simulamos un periodo de
//  50 us. Así los milisegundos de la simulación son milisegundos de verdad:
//  la partida dura lo mismo que duraría en la mesa.
//
//  Guion de la prueba:
//   1. Encendido: ESPERA, marcador 0-0, pelota titilando.
//   2. START y a jugar. Los robots siguen la pelota pero de vez en cuando
//      "se distraen" para que haya goles de los dos lados.
//   3. A mitad de partida: pausa con START y caída del enlace RF de J2.
//   4. Se juega hasta que alguien llega a 9 -> FIN, y START vuelve a ESPERA.
//   5. Partida nueva, RESET en medio del juego y patrón de calibración
//      mientras se sostiene RESET.
//
//  Revisamos en todo momento: posiciones en rango, un punto por gol, que lo
//  que reciben los MAX7219 coincide con la imagen interna, la decodificación
//  de los displays y los tiempos de la hoja de datos.
//
//  Además guardamos la pantalla cada 40 ms en sim/partida.txt; con ese
//  archivo scripts/animar_partida.py arma el GIF que está en docs/img/.
// ============================================================================

`timescale 1ns / 1ps

module tb_integracion;

    `include "tb_comun.vh"

    localparam integer CLK_HZ = 20_000;
    localparam integer MS     = 1_000_000;   // 1 ms en unidades de simulación (ns)

    localparam [2:0] ESPERA = 3'b000, JUEGO = 3'b001, PUNTO = 3'b010,
                     PAUSA  = 3'b011, FIN   = 3'b100;

    reg clk = 0;
    always #25000 clk = ~clk;          // 20 kHz

    // Pines: controles activos en alto (como un HT12D), botones activos en bajo
    reg j1u = 0, j1d = 0, j2u = 0, j2d = 0;
    reg vt1 = 1, vt2 = 1;
    reg start_n = 1, reset_n = 1;

    wire din, sclk, load;
    wire [7:0] seg, dig7;      // display de 8 dígitos de la tarjeta (activos en bajo)
    wire       buzzer;
    reg        sw_sonido_n = 0, sw_prueba_n = 1;   // DIP: 0 = ON
    wire [3:0] led;

    pong_top #(
        .ANCHO(ANCHO),
        .CLK_HZ(CLK_HZ),
        .DIV_CLK_LED(1),
        .PAUSA_PUNTO_MS(800),
        .PUNTOS_VICTORIA(9)
    ) dut (
        .CLK_SYS(clk), .RESET_PIN(reset_n), .START_PIN(start_n),
        .J1_UP(j1u), .J1_DOWN(j1d), .J2_UP(j2u), .J2_DOWN(j2d),
        .J1_VT(vt1), .J2_VT(vt2),
        .DIN(din), .CLK_LED(sclk), .LOAD(load),
        .SW_SONIDO(sw_sonido_n), .SW_PRUEBA(sw_prueba_n),
        .SEG(seg), .DIG(dig7), .BUZZER(buzzer), .LED(led)
    );

    // Cadena de MAX7219: el chip 0 (cercano) maneja la matriz izquierda
    wire [N_CHIPS-1:0]    dout;
    wire [64*N_CHIPS-1:0] dig;
    wire [40*N_CHIPS-1:0] conf_regs;
    wire [32*N_CHIPS-1:0] viol;
    genvar k;
    generate
        for (k = 0; k < N_CHIPS; k = k + 1) begin : g_chip
            modelo_max7219 u (
                .din((k == 0) ? din : dout[(k == 0) ? 0 : k - 1]),
                .clk(sclk), .load(load), .dout(dout[k]),
                .digitos(dig[64*k +: 64]), .config_regs(conf_regs[40*k +: 40]),
                .n_violaciones(viol[32*k +: 32]), .n_clks_ultima()
            );
        end
    endgenerate

    function integer violaciones_totales;
        input dummy;
        integer i;
        begin
            violaciones_totales = 0;
            for (i = 0; i < N_CHIPS; i = i + 1) violaciones_totales = violaciones_totales + viol[32*i +: 32];
        end
    endfunction

    function todos_operando;
        input dummy;
        integer i;
        begin
            todos_operando = 1;
            // shutdown en 1 y display test en 0 en cada chip
            for (i = 0; i < N_CHIPS; i = i + 1)
                if (conf_regs[40*i +: 8] !== 8'h01 || conf_regs[40*i + 32 +: 8] !== 8'h00) todos_operando = 0;
        end
    endfunction

    // Atajos a señales internas (solo para observar, nunca para manejar)
    wire [2:0] estado = dut.estado;
    wire [XB-1:0] bx = dut.bx;
    wire [2:0] by  = dut.by;
    wire       bdx = dut.bdx;
    wire [2:0] yp1 = dut.yp1;
    wire [2:0] yp2 = dut.yp2;
    wire [3:0] p1  = dut.p1;
    wire [3:0] p2  = dut.p2;

    task esperar_ms;
        input integer n;
        begin #(n * 1.0e6); end   // en real: n*MS en 32 bits se desborda pasados ~2 s
    endtask

    task presionar_start;
        begin start_n = 0; esperar_ms(30); start_n = 1; esperar_ms(30); end
    endtask

    // ------------------------------------------------------------------
    // Pantalla reconstruida desde los registros de todos los chips de la cadena
    // ------------------------------------------------------------------
    function [8*ANCHO-1:0] pantalla;
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < ANCHO; c = c + 1)
                    pantalla[f*ANCHO + c] = dig[64*(c / 8) + 8*f + (7 - (c % 8))];
        end
    endfunction

    // Copia de la pantalla tomada justo cuando termina de llegar cada imagen
    // completa. Si leyéramos los registros en cualquier instante podríamos
    // agarrar la mitad de una imagen y la mitad de la siguiente (en los LEDs
    // eso dura menos de un milisegundo y no se nota, pero en el log sí).
    reg [8*ANCHO-1:0] pantalla_estable = 0;
    always @(posedge clk) if (dut.u_max7219.trama_fin) begin #1 pantalla_estable = pantalla(0); end

    task imprimir;
        input [8*ANCHO-1:0] im;
        integer f, c;
        reg [8*ANCHO-1:0] linea;
        begin
            for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = "-";
            $display("   +%s+   J1 %0d - %0d J2", linea, p1, p2);
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = im[f*ANCHO + c] ? "O" : ".";
                $display("   |%s|", linea);
            end
            for (c = 0; c < ANCHO; c = c + 1) linea[(ANCHO - 1 - c)*8 +: 8] = "-";
            $display("   +%s+", linea);
        end
    endtask

    // ------------------------------------------------------------------
    // Jugadores robot
    // ------------------------------------------------------------------
    // Cada robot da toques cortos (25 ms presionado, 25 ms suelto) hacia la
    // fila de la pelota. Cuando la pelota empieza a venir hacia él, decide al
    // azar si esta vez se "distrae". Al principio el robot distraído solo se
    // quedaba quieto, pero casi nunca fallaba: la paleta ya estaba cerca de
    // donde volvía la pelota. Ahora el distraído persigue una fila al azar.
    reg distraido1 = 0, distraido2 = 0;
    reg [2:0] fila_falsa1 = 0, fila_falsa2 = 0;
    reg bdx_ant = 1;
    integer seed = 2026;
    integer prob_fallo1 = 30, prob_fallo2 = 38;   // en porcentaje
    reg robots_activos = 0;

    always @(posedge clk) begin
        if (bdx != bdx_ant || dut.saque) begin
            // cambió el sentido de la pelota o hubo saque: nueva decisión
            if (!bdx) begin
                distraido1  <= (($random(seed) % 100 + 100) % 100) < prob_fallo1;
                fila_falsa1 <= $random(seed);
            end else begin
                distraido2  <= (($random(seed) % 100 + 100) % 100) < prob_fallo2;
                fila_falsa2 <= $random(seed);
            end
        end
        bdx_ant <= bdx;
    end

    wire [2:0] obj1 = distraido1 ? fila_falsa1 : by;
    wire [2:0] obj2 = distraido2 ? fila_falsa2 : by;

    integer fase = 0;
    always begin
        esperar_ms(25);
        fase = !fase;
        if (!robots_activos || !fase) begin
            j1u = 0; j1d = 0; j2u = 0; j2d = 0;
        end else begin
            // el centro de cada paleta es yp + 1
            j1u = (obj1 < yp1 + 1);
            j1d = (obj1 > yp1 + 1);
            j2u = (obj2 < yp2 + 1);
            j2d = (obj2 > yp2 + 1);
        end
    end

    // ------------------------------------------------------------------
    // Monitores permanentes
    // ------------------------------------------------------------------
    integer esperado1 = 0, esperado2 = 0;
    integer goles_vistos = 0, rebotes_paleta = 0, max_nivel = 0;
    reg     revisar_pantalla = 1;
    integer pantallas_revisadas = 0, pantallas_malas = 0;

    always @(posedge clk) begin
        // Rangos
        if (yp1 > 5 || yp2 > 5 || p1 > 9 || p2 > 9 || bx > ULT) begin
            errores = errores + 1;
            $display("  [FALLA] t=%0t valores fuera de rango", $time);
        end
        // Un punto por gol
        if (estado == JUEGO && dut.gol_j1) begin esperado1 = esperado1 + 1; goles_vistos = goles_vistos + 1; end
        if (estado == JUEGO && dut.gol_j2) begin esperado2 = esperado2 + 1; goles_vistos = goles_vistos + 1; end
        if (dut.limpiar || dut.rst) begin esperado1 = 0; esperado2 = 0; end
        if (dut.rebote_paleta) rebotes_paleta = rebotes_paleta + 1;
        if (dut.nivel > max_nivel) max_nivel = dut.nivel;
    end

    // El marcador se compara un ciclo después (el registro necesita un flanco)
    always @(negedge clk) begin
        if (!dut.rst && (p1 != esperado1 || p2 != esperado2)) begin
            errores = errores + 1;
            if (errores < 10)
                $display("  [FALLA] t=%0t marcador %0d-%0d, esperado %0d-%0d", $time, p1, p2, esperado1, esperado2);
        end
    end

    // Al terminar cada pantalla, lo que tienen los MAX7219 debe ser
    // exactamente lo que el transmisor tomó de la imagen
    integer d, q;
    reg     distinta;
    always @(posedge clk) begin
        if (dut.u_max7219.trama_fin && revisar_pantalla) begin
            pantallas_revisadas = pantallas_revisadas + 1;
            distinta = 0;
            for (q = 0; q < N_CHIPS; q = q + 1)
                for (d = 0; d < 8; d = d + 1)
                    if (dig[64*q + 8*d +: 8] !== dut.u_max7219.buffer[(q*8 + d)*8 +: 8]) distinta = 1;
            if (distinta) pantallas_malas = pantallas_malas + 1;
        end
    end

    // ------------------------------------------------------------------
    // Display de 8 dígitos de la tarjeta
    // ------------------------------------------------------------------
    // Tabla independiente de la del RTL: {g,f,e,d,c,b,a} en lógica positiva
    function [6:0] patron7;
        input [4:0] v;
        begin
            case (v)
                0: patron7 = 7'b0111111; 1: patron7 = 7'b0000110; 2: patron7 = 7'b1011011;
                3: patron7 = 7'b1001111; 4: patron7 = 7'b1100110; 5: patron7 = 7'b1101101;
                6: patron7 = 7'b1111101; 7: patron7 = 7'b0000111; 8: patron7 = 7'b1111111;
                9: patron7 = 7'b1101111;
                10: patron7 = 7'b1110110; 11: patron7 = 7'b0111000; 12: patron7 = 7'b1110111;
                13: patron7 = 7'b1110011; 14: patron7 = 7'b0111110; 15: patron7 = 7'b0111101;
                16: patron7 = 7'b1010100; 17: patron7 = 7'b1000000;
                default: patron7 = 7'b0000000;
            endcase
        end
    endfunction

    // "Ojo": lo último que se vio en cada dígito (lógica positiva, con punto)
    reg [7:0] visto7 [0:7];
    integer   dobles7 = 0, seg_malos = 0, j7, n7;
    reg [3:0] p1_d = 0, p2_d = 0;
    always @(posedge clk) begin p1_d <= p1; p2_d <= p2; end

    always @(negedge clk) begin
        n7 = 0;
        for (j7 = 0; j7 < 8; j7 = j7 + 1)
            if (!dig7[j7]) begin n7 = n7 + 1; visto7[j7] = ~seg; end
        if (n7 > 1) dobles7 = dobles7 + 1;
        // El marcador tiene que coincidir en todo momento (fuera de FIN, donde titila,
        // y del patrón de prueba). Comparamos con el puntaje de un ciclo antes porque
        // las salidas del display están registradas.
        if (!dut.rst && estado != FIN && !dut.modo_prueba) begin
            if (!dig7[7] && (~seg[6:0]) !== patron7(p1_d)) seg_malos = seg_malos + 1;
            if (!dig7[0] && (~seg[6:0]) !== patron7(p2_d)) seg_malos = seg_malos + 1;
        end
    end

    // Revisa que el display muestre "P1 _ c5 c4 c3 c2 _ P2"
    task revisar_display;
        input [4:0] c5, c4, c3, c2;
        input [8*24-1:0] nombre;
        reg ok;
        begin
            esperar_ms(10);   // un par de vueltas del barrido
            ok = (visto7[7][6:0] == patron7(p1)) && (visto7[0][6:0] == patron7(p2)) &&
                 (visto7[6] == 8'h00) && (visto7[1] == 8'h00) &&
                 (visto7[5][6:0] == patron7(c5)) && (visto7[4][6:0] == patron7(c4)) &&
                 (visto7[3][6:0] == patron7(c3)) && (visto7[2][6:0] == patron7(c2));
            `VERIFICAR(ok, $sformatf("display de la tarjeta en %0s", nombre))
        end
    endtask

    // Cuenta los flancos del buzzer
    integer pitidos = 0;
    reg buzzer_ant = 1;
    always @(posedge clk) begin
        if (!buzzer && buzzer_ant) pitidos = pitidos + 1;
        buzzer_ant <= buzzer;
    end

    // ------------------------------------------------------------------
    // Registro de la partida para la animación
    // ------------------------------------------------------------------
    integer archivo, f_i, c_i;
    reg [8*ANCHO-1:0] scr;
    initial begin
        archivo = $fopen("sim/partida.txt", "w");
        $fdisplay(archivo, "# t_ms estado p1 p2 pantalla(8 filas x %0d columnas, fila 0 primero)", ANCHO);
        forever begin
            esperar_ms(40);
            scr = pantalla_estable;
            $fwrite(archivo, "%0d %0d %0d %0d ", $time / MS, estado, p1, p2);
            for (f_i = 0; f_i < 8; f_i = f_i + 1)
                for (c_i = 0; c_i < ANCHO; c_i = c_i + 1)
                    $fwrite(archivo, "%0d", scr[f_i*ANCHO + c_i]);
            $fwrite(archivo, "\n");
        end
    end

    // Imprimimos la pantalla en el instante de cada gol
    integer t_gol;
    always @(posedge clk) begin
        if (estado == JUEGO && (dut.gol_j1 || dut.gol_j2)) begin
            t_gol = $time / MS;
            #(150.0e6);  // en la simulación una imagen tarda ~50 ms en llegar completa (DIV_CLK_LED = 1)
            $display("  t=%0d ms: gol de %s", t_gol, dut.u_control.perdio_j2 ? "J1" : "J2");
            imprimir(pantalla_estable);
        end
    end

    // ------------------------------------------------------------------
    // Guion
    // ------------------------------------------------------------------
    integer t0, i;
    reg [XB-1:0] x_congelada;
    reg [2:0] yp2_congelada;

    initial begin
        $display("== tb_integracion: partida completa en %0d x 8 (%0d MAX7219) ==", ANCHO, N_CHIPS);

        // ---- 1. Encendido ----
        esperar_ms(100);
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0, "estado de encendido")
        `VERIFICAR(todos_operando(0), "los MAX7219 no quedaron configurados")
        revisar_display(10, 0, 11, 12, "ESPERA (HOLA)");
        $display("  Pantalla al encender (ESPERA):");
        imprimir(pantalla(0));

        // START sin que nadie juegue: la pelota sale y alguien anota
        robots_activos = 1;
        presionar_start;
        `VERIFICAR(estado == JUEGO, "START no inicio el juego")
        revisar_display(17, 16, 1, 17, "JUEGO (-n1-)");
        `VERIFICAR(led[0] == 1'b0, "LED de juego apagado (activo en bajo)")

        // ---- 2. Jugamos hasta tener al menos 3 goles ----
        t0 = $time / MS;
        while (goles_vistos < 3 && ($time / MS - t0) < 120_000) esperar_ms(10);
        `VERIFICAR(goles_vistos >= 3, "no hubo goles en 2 minutos")

        // ---- 3a. Pausa con START ----
        while (estado != JUEGO) esperar_ms(5);
        esperar_ms(150);
        presionar_start;
        `VERIFICAR(estado == PAUSA, "START no pauso")
        revisar_display(13, 12, 14, 5, "PAUSA (PAUS)");
        x_congelada = bx;
        robots_activos = 0;
        j1u = 1;                                 // aunque presione, no se mueve
        esperar_ms(600);
        `VERIFICAR(bx == x_congelada, "la pelota se movio en PAUSA")
        `VERIFICAR(yp1 == dut.u_paleta_j1.yp, "paleta inconsistente")
        j1u = 0;
        robots_activos = 1;
        presionar_start;
        `VERIFICAR(estado == JUEGO, "START no reanudo")

        // ---- 3b. Se cae el enlace de J2 con su botón "pegado" en subir ----
        esperar_ms(200);
        robots_activos = 0;
        j2u = 1;
        vt2 = 0;
        esperar_ms(50);
        `VERIFICAR(estado == PAUSA, "T09 la caida del enlace no pauso")
        `VERIFICAR(led[3] == 1'b1, "LED de enlace J2 deberia estar apagado")
        yp2_congelada = yp2;
        esperar_ms(800);
        `VERIFICAR(yp2 == yp2_congelada, "T09 la paleta se movio sin enlace")
        // Intentar reanudar sin enlace no debe funcionar
        presionar_start;
        `VERIFICAR(estado == PAUSA, "reanudo sin enlace")
        // Vuelve el enlace
        j2u = 0;
        vt2 = 1;
        esperar_ms(30);
        robots_activos = 1;
        presionar_start;
        `VERIFICAR(estado == JUEGO, "no reanudo con el enlace de vuelta")

        // ---- 4. Hasta el final ----
        t0 = $time / MS;
        while (estado != FIN && ($time / MS - t0) < 600_000) esperar_ms(10);
        `VERIFICAR(estado == FIN, "la partida no termino")
        $display("  Marcador final: J1 %0d - %0d J2 (ganador J%0d)", p1, p2, dut.ganador + 1);
        `VERIFICAR((p1 == 9) != (p2 == 9), "marcador final invalido")
        `VERIFICAR(dut.ganador == (p2 == 9), "ganador mal registrado")

        // Efecto de fin: la mitad del ganador titila
        while (!dut.parpadeo) esperar_ms(5);
        esperar_ms(60);
        $display("  Pantalla en FIN (semiciclo encendido):");
        imprimir(pantalla(0));
        robots_activos = 0;
        esperar_ms(1000);
        `VERIFICAR(estado == FIN && p1 == esperado1 && p2 == esperado2, "algo cambio en FIN")
        esperar_ms(5);
        `VERIFICAR(visto7[5][6:0] == patron7(15) && visto7[4][6:0] == patron7(12) &&
                   visto7[3][6:0] == patron7(16) && visto7[2][6:0] == patron7(12), "display en FIN (GAnA)")

        presionar_start;
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0, "FIN -> ESPERA no limpio el marcador")

        // ---- 5. Nueva partida y RESET ----
        robots_activos = 1;
        presionar_start;
        esperar_ms(3000);
        robots_activos = 0;   // si no, los robots alcanzan a mover las paletas apenas se suelta RESET
        esperar_ms(30);
        reset_n = 0; esperar_ms(30); reset_n = 1; esperar_ms(30);
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0 && yp1 == 2 && yp2 == 2, "T06 RESET")
        robots_activos = 0;
        esperar_ms(100);

        // ---- Patrón de calibración mientras se sostiene RESET ----
        reset_n = 0;
        esperar_ms(120);   // antirrebote + un par de pantallas
        begin : calibracion
            reg [8*ANCHO-1:0] esperado_cal;
            integer f2, c2;
            for (f2 = 0; f2 < 8; f2 = f2 + 1)
                for (c2 = 0; c2 < ANCHO; c2 = c2 + 1)
                    esperado_cal[f2*ANCHO + c2] = (f2 == 0 && (c2 % 8) <= (c2 / 8) + 1) || ((c2 % 8) == 0 && f2 <= 2);
            `VERIFICAR(pantalla(0) == esperado_cal, "el patron de calibracion no se ve en los LEDs")
            $display("  Pantalla con RESET sostenido (patron de calibracion):");
            imprimir(pantalla(0));
        end
        reset_n = 1;
        esperar_ms(120);
        `VERIFICAR(estado == ESPERA, "no volvio a ESPERA al soltar RESET")

        // ---- DIP 2: patrón de calibración sin tocar RESET ----
        sw_prueba_n = 0;
        esperar_ms(120);
        begin : calibracion_dip
            reg [8*ANCHO-1:0] esperado_cal;
            integer f3, c3;
            for (f3 = 0; f3 < 8; f3 = f3 + 1)
                for (c3 = 0; c3 < ANCHO; c3 = c3 + 1)
                    esperado_cal[f3*ANCHO + c3] = (f3 == 0 && (c3 % 8) <= (c3 / 8) + 1) || ((c3 % 8) == 0 && f3 <= 2);
            `VERIFICAR(pantalla(0) == esperado_cal, "el DIP 2 no muestra el patron de calibracion")
            for (j7 = 0; j7 < 8; j7 = j7 + 1)
                `VERIFICAR(visto7[j7] == 8'hFF, $sformatf("el digito %0d no muestra 8. en el patron de prueba", j7))
        end
        sw_prueba_n = 1;
        esperar_ms(120);

        // ---- DIP 1: sin sonido no hay pitidos ----
        begin : sin_sonido
            integer antes;
            sw_sonido_n = 1;
            robots_activos = 1;
            presionar_start;
            antes = pitidos;
            esperar_ms(4000);
            `VERIFICAR(pitidos == antes, "el buzzer sono con el DIP 1 apagado")
            robots_activos = 0;
            sw_sonido_n = 0;
        end

        // ---- Resumen ----
        $display("  goles registrados        : %0d", goles_vistos);
        $display("  rebotes en paleta        : %0d", rebotes_paleta);
        $display("  nivel de velocidad maximo: %0d", max_nivel);
        $display("  pantallas comparadas     : %0d (distintas: %0d)", pantallas_revisadas, pantallas_malas);
        $display("  palabras recibidas (chip 0): %0d", g_chip[0].u.palabras);
        $display("  violaciones de tiempo    : %0d", violaciones_totales(0));
        $display("  tiempo simulado          : %0d s", $time / (1000 * MS));
        `VERIFICAR(pantallas_malas == 0, "T08 lo recibido por los MAX7219 no coincide con la imagen")
        `VERIFICAR(pantallas_revisadas > 1000, "muy pocas pantallas revisadas")
        `VERIFICAR(seg_malos == 0, $sformatf("%0d ciclos con el marcador mal decodificado", seg_malos))
        `VERIFICAR(dobles7 == 0, "dos digitos del display encendidos a la vez")
        `VERIFICAR(pitidos > 1000, $sformatf("casi no sono el buzzer (%0d flancos)", pitidos))
        $display("  flancos del buzzer       : %0d", pitidos);
        `VERIFICAR(violaciones_totales(0) == 0, "violaciones de tiempo en el MAX7219")
        `VERIFICAR(rebotes_paleta > 10, "casi no hubo rebotes en paleta")

        $fclose(archivo);
        reporte_final("tb_integracion");
        $finish;
    end

    // Por si algo se cuelga
    initial begin
        #(1.0e12);   // 1000 s simulados
        $display("  [FALLA] tiempo maximo de simulacion alcanzado");
        errores = errores + 1;
        reporte_final("tb_integracion");
        $finish;
    end

endmodule
