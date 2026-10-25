// ============================================================================
//  tb_integracion.v  -  Simulación de extremo a extremo (PC3, T01-T09)
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Esta es la prueba que más nos gusta: juega una partida COMPLETA contra el
//  diseño entero (pong_top) con dos "jugadores robot" y dos modelos de
//  MAX7219 colgados de DIN/CLK_LED/LOAD, exactamente como irá en el montaje.
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
//   5. Partida nueva y RESET en medio del juego.
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
    wire [6:0] seg1, seg2;
    wire [3:0] led;

    pong_top #(
        .CLK_HZ(CLK_HZ),
        .DIV_CLK_LED(1),
        .PAUSA_PUNTO_MS(800),
        .PUNTOS_VICTORIA(9)
    ) dut (
        .CLK_SYS(clk), .RESET_PIN(reset_n), .START_PIN(start_n),
        .J1_UP(j1u), .J1_DOWN(j1d), .J2_UP(j2u), .J2_DOWN(j2d),
        .J1_VT(vt1), .J2_VT(vt2),
        .DIN(din), .CLK_LED(sclk), .LOAD(load),
        .SEG_J1(seg1), .SEG_J2(seg2), .LED(led)
    );

    // Dos MAX7219 en cadena, el cercano maneja la mitad izquierda
    wire dout1, dout2;
    modelo_max7219 u1 (.din(din),   .clk(sclk), .load(load), .dout(dout1));
    modelo_max7219 u2 (.din(dout1), .clk(sclk), .load(load), .dout(dout2));

    // Atajos a señales internas (solo para observar, nunca para manejar)
    wire [2:0] estado = dut.estado;
    wire [3:0] bx  = dut.bx;
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
    // Pantalla reconstruida desde los registros de los dos chips
    // ------------------------------------------------------------------
    function [127:0] pantalla;
        input dummy;
        integer f, c;
        begin
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 16; c = c + 1)
                    pantalla[f*16 + c] = (c < 8) ? u1.digito[f+1][7 - c] : u2.digito[f+1][7 - (c - 8)];
        end
    endfunction

    task imprimir;
        input [127:0] im;
        integer f, c;
        reg [8*16-1:0] linea;
        begin
            $display("   +----------------+   J1 %0d - %0d J2", p1, p2);
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < 16; c = c + 1) linea[(15 - c)*8 +: 8] = im[f*16 + c] ? "O" : ".";
                $display("   |%s|", linea);
            end
            $display("   +----------------+");
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
        if (yp1 > 5 || yp2 > 5 || p1 > 9 || p2 > 9 || bx > 15) begin
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
    integer d;
    always @(posedge clk) begin
        if (dut.u_max7219.trama_fin && revisar_pantalla) begin
            pantallas_revisadas = pantallas_revisadas + 1;
            for (d = 0; d < 8; d = d + 1)
                if (u1.digito[d+1] !== dut.u_max7219.buffer[(0*8 + d)*8 +: 8] ||
                    u2.digito[d+1] !== dut.u_max7219.buffer[(1*8 + d)*8 +: 8])
                    pantallas_malas = pantallas_malas + 1;
        end
    end

    // Decodificación de displays (ánodo común: activo en bajo)
    function [6:0] patron7;
        input [3:0] v;
        begin
            case (v)
                0: patron7 = 7'b0111111; 1: patron7 = 7'b0000110; 2: patron7 = 7'b1011011;
                3: patron7 = 7'b1001111; 4: patron7 = 7'b1100110; 5: patron7 = 7'b1101101;
                6: patron7 = 7'b1111101; 7: patron7 = 7'b0000111; 8: patron7 = 7'b1111111;
                9: patron7 = 7'b1101111; default: patron7 = 7'b1000000;
            endcase
        end
    endfunction

    integer seg_malos = 0;
    always @(negedge clk) begin
        if (estado != FIN && !dut.rst) begin
            if (seg1 !== ~patron7(p1) || seg2 !== ~patron7(p2)) seg_malos = seg_malos + 1;
        end
    end

    // ------------------------------------------------------------------
    // Registro de la partida para la animación
    // ------------------------------------------------------------------
    integer archivo, f_i, c_i;
    reg [127:0] scr;
    initial begin
        archivo = $fopen("sim/partida.txt", "w");
        $fdisplay(archivo, "# t_ms estado p1 p2 pantalla(8 filas x 16 columnas, fila 0 primero)");
        forever begin
            esperar_ms(40);
            scr = pantalla(0);
            $fwrite(archivo, "%0d %0d %0d %0d ", $time / MS, estado, p1, p2);
            for (f_i = 0; f_i < 8; f_i = f_i + 1)
                for (c_i = 0; c_i < 16; c_i = c_i + 1)
                    $fwrite(archivo, "%0d", scr[f_i*16 + c_i]);
            $fwrite(archivo, "\n");
        end
    end

    // Imprimimos la pantalla en el instante de cada gol
    always @(posedge clk) begin
        if (estado == JUEGO && (dut.gol_j1 || dut.gol_j2)) begin
            #(60.0e6);   // dejamos que los MAX7219 reciban la imagen nueva
            $display("  t=%0d ms: gol de %s", $time / MS, dut.u_control.perdio_j2 ? "J1" : "J2");
            imprimir(pantalla(0));
        end
    end

    // ------------------------------------------------------------------
    // Guion
    // ------------------------------------------------------------------
    integer t0, i;
    reg [3:0] x_congelada;
    reg [2:0] yp2_congelada;

    initial begin
        $display("== tb_integracion: partida completa ==");

        // ---- 1. Encendido ----
        esperar_ms(100);
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0, "estado de encendido")
        `VERIFICAR(u1.operando && u2.operando, "los MAX7219 no quedaron configurados")
        `VERIFICAR(seg1 === ~patron7(0) && seg2 === ~patron7(0), "displays en 0-0")
        $display("  Pantalla al encender (ESPERA):");
        imprimir(pantalla(0));

        // START sin que nadie juegue: la pelota sale y alguien anota
        robots_activos = 1;
        presionar_start;
        `VERIFICAR(estado == JUEGO, "START no inicio el juego")
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

        presionar_start;
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0, "FIN -> ESPERA no limpio el marcador")

        // ---- 5. Nueva partida y RESET ----
        robots_activos = 1;
        presionar_start;
        esperar_ms(3000);
        reset_n = 0; esperar_ms(30); reset_n = 1; esperar_ms(30);
        `VERIFICAR(estado == ESPERA && p1 == 0 && p2 == 0 && yp1 == 2 && yp2 == 2, "T06 RESET")
        robots_activos = 0;
        esperar_ms(100);

        // ---- Resumen ----
        $display("  goles registrados        : %0d", goles_vistos);
        $display("  rebotes en paleta        : %0d", rebotes_paleta);
        $display("  nivel de velocidad maximo: %0d", max_nivel);
        $display("  pantallas comparadas     : %0d (distintas: %0d)", pantallas_revisadas, pantallas_malas);
        $display("  palabras recibidas U1/U2 : %0d / %0d", u1.palabras, u2.palabras);
        $display("  violaciones de tiempo    : %0d", u1.violaciones + u2.violaciones);
        $display("  tiempo simulado          : %0d s", $time / (1000 * MS));
        `VERIFICAR(pantallas_malas == 0, "T08 lo recibido por los MAX7219 no coincide con la imagen")
        `VERIFICAR(pantallas_revisadas > 1000, "muy pocas pantallas revisadas")
        `VERIFICAR(seg_malos == 0, $sformatf("%0d ciclos con displays mal decodificados", seg_malos))
        `VERIFICAR(u1.violaciones + u2.violaciones == 0, "violaciones de tiempo en el MAX7219")
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
