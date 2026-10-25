// ============================================================================
//  tb_imagen.v  -  Prueba T07
//  Autores: Daniel Felipe Castro González, Juan David Ortiz Muñoz,
//           David Eduardo Chivata Arias
// ----------------------------------------------------------------------------
//  Comprobamos los 128 LEDs de la imagen lógica para TODAS las posiciones
//  posibles de pelota y paletas (16 x 8 x 6 x 6 = 4608 escenas), y el mapeo
//  a los registros de los MAX7219 con la orientación por defecto y con una
//  orientación alterna (transpuesta e invertida), que es la que tendríamos
//  si los módulos vienen soldados "al revés".
// ============================================================================

`timescale 1ns / 1ps

module tb_imagen;

    `include "tb_comun.vh"

    reg  [3:0] x;
    reg  [2:0] y, yp1, yp2;
    reg        mostrar = 1, fin = 0, ganador = 0, parp = 0;
    wire [127:0] img, bytes, img_b, bytes_b;

    imagen #(.LP(3)) dut (
        .x(x), .y(y), .yp1(yp1), .yp2(yp2), .mostrar_pelota(mostrar),
        .modo_fin(fin), .ganador(ganador), .parpadeo(parp), .img(img), .bytes(bytes)
    );

    imagen #(.LP(3), .TRANSPONER(1), .INV_BITS(1), .INV_DIGITOS(1)) dut_alt (
        .x(x), .y(y), .yp1(yp1), .yp2(yp2), .mostrar_pelota(mostrar),
        .modo_fin(fin), .ganador(ganador), .parpadeo(parp), .img(img_b), .bytes(bytes_b)
    );

    // Pixel esperado, escrito como lo diríamos en palabras
    function esperado;
        input integer fila, col;
        begin
            esperado = 0;
            if (col == 0  && fila >= yp1 && fila < yp1 + 3) esperado = 1;
            if (col == 15 && fila >= yp2 && fila < yp2 + 3) esperado = 1;
            if (mostrar && col == x && fila == y)          esperado = 1;
            if (fin && parp && ((ganador == 0 && col < 8) || (ganador == 1 && col >= 8))) esperado = 1;
        end
    endfunction

    integer ix, iy, a, b, f, c, m, d, bit_i;
    integer malos_img, malos_map, malos_alt, encendidos;

    task revisar_escena;
        begin
            #1;
            encendidos = 0;
            for (f = 0; f < 8; f = f + 1)
                for (c = 0; c < 16; c = c + 1) begin
                    if (img[f*16 + c] !== esperado(f, c)) malos_img = malos_img + 1;
                    encendidos = encendidos + img[f*16 + c];
                end
            // Mapeo por defecto: dígito d = fila d, bit 7 = columna izquierda del módulo
            for (m = 0; m < 2; m = m + 1)
                for (d = 0; d < 8; d = d + 1)
                    for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                        if (bytes[(m*8 + d)*8 + bit_i] !== img[d*16 + m*8 + (7 - bit_i)]) malos_map = malos_map + 1;
                        // Alterna: dígito d = columna (7-d) del módulo, bit b = fila b
                        if (bytes_b[(m*8 + d)*8 + bit_i] !== img[bit_i*16 + m*8 + (7 - d)]) malos_alt = malos_alt + 1;
                    end
            pruebas = pruebas + 1;
        end
    endtask

    // Imprime la pantalla en ASCII, así se ve en el log lo que se vería en los LEDs
    task imprimir;
        input [127:0] im;
        reg [8*16-1:0] linea;
        begin
            $display("   +----------------+");
            for (f = 0; f < 8; f = f + 1) begin
                for (c = 0; c < 16; c = c + 1) linea[(15 - c)*8 +: 8] = im[f*16 + c] ? "O" : ".";
                $display("   |%s|", linea);
            end
            $display("   +----------------+");
        end
    endtask

    initial begin
        $display("== tb_imagen ==");
        malos_img = 0; malos_map = 0; malos_alt = 0;

        // Barrido completo con la pelota visible
        for (ix = 0; ix < 16; ix = ix + 1)
        for (iy = 0; iy < 8; iy = iy + 1)
        for (a = 0; a <= 5; a = a + 1)
        for (b = 0; b <= 5; b = b + 1) begin
            x = ix; y = iy; yp1 = a; yp2 = b;
            revisar_escena;
            // Con la pelota lejos de las paletas deben verse exactamente 7 LEDs
            if (ix > 0 && ix < 15) begin
                `VERIFICAR(encendidos == 7, $sformatf("%0d LEDs encendidos en vez de 7", encendidos))
            end
        end

        // Pelota oculta (estado ESPERA en el semiciclo apagado)
        mostrar = 0;
        x = 7; y = 3; yp1 = 2; yp2 = 2; revisar_escena;
        `VERIFICAR(encendidos == 6, "la pelota no se oculto")
        mostrar = 1;

        // Efecto de fin de partida
        fin = 1; parp = 1; ganador = 1; revisar_escena;
        `VERIFICAR(encendidos == 64 + 3 + (x < 8 ? 1 : 0), $sformatf("efecto fin J2: %0d LEDs", encendidos))
        ganador = 0; revisar_escena;
        parp = 0; revisar_escena;
        fin = 0;

        `VERIFICAR(malos_img == 0, $sformatf("T07 %0d pixeles distintos al mapa logico", malos_img))
        `VERIFICAR(malos_map == 0, $sformatf("%0d bits mal mapeados (orientacion por defecto)", malos_map))
        `VERIFICAR(malos_alt == 0, $sformatf("%0d bits mal mapeados (orientacion alterna)", malos_alt))

        // Un par de escenas impresas para el informe
        x = 4; y = 5; yp1 = 1; yp2 = 4; #1;
        $display("  Escena de ejemplo: pelota (X=4, Y=5), YP1=1, YP2=4");
        imprimir(img);
        x = 14; y = 0; yp1 = 5; yp2 = 0; #1;
        $display("  Escena de ejemplo: pelota a punto de golpear la paleta de J2");
        imprimir(img);

        reporte_final("tb_imagen");
        $finish;
    end

endmodule
