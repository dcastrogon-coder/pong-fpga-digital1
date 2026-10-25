// ============================================================================
//  tb_comun.vh
//  Utilidades que compartimos entre todos los testbenches: contador de
//  verificaciones, contador de errores y el reporte final.
//
//  Cada testbench termina imprimiendo una línea "RESULTADO <nombre>: PASA" o
//  "RESULTADO <nombre>: FALLA". El script sim/correr_todo.sh busca justo esa
//  línea, así que no la cambiemos sin actualizar el script.
// ============================================================================

integer errores = 0;
integer pruebas = 0;

// Ancho de la cancha que se simula. Por defecto 32 (módulo MAX7219 x4);
// el script también corre las pruebas con 16 pasando -DANCHO_PRUEBA=16.
`ifndef ANCHO_PRUEBA
  `define ANCHO_PRUEBA 32
`endif
localparam integer ANCHO   = `ANCHO_PRUEBA;
localparam integer XB      = (ANCHO > 16) ? 5 : 4;
localparam integer N_CHIPS = ANCHO / 8;
localparam integer ULT     = ANCHO - 1;     // última columna

// Uso: `VERIFICAR(condicion, $sformatf("mensaje %0d", valor))
// Ojo: comparamos con !== 1 para que una condición en X (señal sin iniciar)
// cuente como FALLA. Al principio usábamos !(cond) y una X pasaba callada.
`define VERIFICAR(cond, msg) \
    begin \
        pruebas = pruebas + 1; \
        if ((cond) !== 1'b1) begin \
            errores = errores + 1; \
            if (errores <= 25) $display("  [FALLA] t=%0t : %0s", $time, msg); \
        end \
    end

task reporte_final;
    input [8*32-1:0] nombre;
    begin
        $display("------------------------------------------------------------");
        if (errores == 0)
            $display("RESULTADO %0s: PASA (%0d verificaciones)", nombre, pruebas);
        else
            $display("RESULTADO %0s: FALLA (%0d errores en %0d verificaciones)",
                     nombre, errores, pruebas);
        $display("------------------------------------------------------------");
    end
endtask
