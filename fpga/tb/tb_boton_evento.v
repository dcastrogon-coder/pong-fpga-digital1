`timescale 1ns/1ps

module tb_boton_evento;

    localparam integer NDB_TB = 4;

    reg CLK_SYS;
    reg INIT_GLOBAL;
    reg PRESSED_RAW;

    wire PRESSED_DB;
    wire PRESS_EVENT;

    integer pruebas;
    integer eventos;
    integer liberaciones;
    integer i;
    integer j;

    // Modelo de referencia
    reg ref_sync1;
    reg ref_sync2;
    reg ref_db;
    integer ref_cdb;

    // Siguientes valores del modelo
    reg next_sync1;
    reg next_sync2;
    reg next_db;
    reg next_event;
    integer next_cdb;

    reg evento_anterior;

    // ------------------------------------
    // 1. Modulo bajo prueba
    // ------------------------------------

    boton_evento #(
        .NDB(20'd4)
    ) dut (
        .CLK_SYS(CLK_SYS),
        .INIT_GLOBAL(INIT_GLOBAL),
        .PRESSED_RAW(PRESSED_RAW),
        .PRESSED_DB(PRESSED_DB),
        .PRESS_EVENT(PRESS_EVENT)
    );

    // Reloj de 50 MHz: 20 ns
    initial CLK_SYS = 1'b0;
    always #10 CLK_SYS = ~CLK_SYS;

    // ------------------------------------
    // 2. Tarea de comprobacion por ciclo
    // ------------------------------------

    task paso;
        input rst;
        input raw;
        input [8*70-1:0] nombre;

        begin
            @(negedge CLK_SYS);

            INIT_GLOBAL = rst;
            PRESSED_RAW = raw;

            // Calcular valores esperados
            // utilizando el estado anterior.
            if (rst) begin

                next_sync1 = 1'b0;
                next_sync2 = 1'b0;
                next_db = 1'b0;
                next_event = 1'b0;
                next_cdb = 0;

            end
            else begin

                // Modelo del sincronizador
                next_sync1 = raw;
                next_sync2 = ref_sync1;

                // Modelo del antirrebote
                next_db = ref_db;
                next_event = 1'b0;

                if (ref_sync2 == ref_db) begin

                    next_cdb = 0;

                end
                else if (ref_cdb == NDB_TB - 1) begin

                    next_db = ref_sync2;
                    next_cdb = 0;

                    if (ref_sync2)
                        next_event = 1'b1;

                end
                else begin

                    next_cdb = ref_cdb + 1;

                end

            end

            // Esperar el flanco de actualizacion
            @(posedge CLK_SYS);
            #1;

            // Comprobar las salidas
            if (PRESSED_DB !== next_db ||
                PRESS_EVENT !== next_event) begin

                $display("ERROR: %0s", nombre);

                $display(
                    "Esperado DB=%b EVENT=%b",
                    next_db, next_event
                );

                $display(
                    "Obtenido DB=%b EVENT=%b",
                    PRESSED_DB, PRESS_EVENT
                );

                $fatal(1, "Fallo del antirrebote");

            end

            // Comprobar registros internos
            if (dut.SYNC_1 !== next_sync1 ||
                dut.SYNC_2 !== next_sync2 ||
                dut.CDB !== next_cdb[19:0]) begin

                $display("ERROR INTERNO: %0s", nombre);

                $display(
                    "Esperado S1=%b S2=%b CDB=%0d",
                    next_sync1, next_sync2, next_cdb
                );

                $display(
                    "Obtenido S1=%b S2=%b CDB=%0d",
                    dut.SYNC_1, dut.SYNC_2, dut.CDB
                );

                $fatal(1, "Fallo de sincronizacion o contador");

            end

            // El evento no puede ocupar
            // dos ciclos consecutivos.
            if (evento_anterior && PRESS_EVENT)
                $fatal(1, "PRESS_EVENT repetido");

            // Registrar transiciones observadas
            if (PRESS_EVENT)
                eventos = eventos + 1;

            if (ref_db && !next_db && !rst)
                liberaciones = liberaciones + 1;

            evento_anterior = PRESS_EVENT;

            // Actualizar modelo de referencia
            ref_sync1 = next_sync1;
            ref_sync2 = next_sync2;
            ref_db = next_db;
            ref_cdb = next_cdb;

            pruebas = pruebas + 1;

        end
    endtask

    // ------------------------------------
    // 3. Secuencia principal de pruebas
    // ------------------------------------

    initial begin

        INIT_GLOBAL = 1'b1;
        PRESSED_RAW = 1'b0;

        pruebas = 0;
        eventos = 0;
        liberaciones = 0;

        ref_sync1 = 0;
        ref_sync2 = 0;
        ref_db = 0;
        ref_cdb = 0;

        evento_anterior = 0;

        $display("------------------------------");
        $display("TESTBENCH BOTON_EVENTO");
        $display("------------------------------");

        // =================================
        // A. INICIALIZACION
        // =================================

        paso(1,0,"Inicializacion");

        for (i=0; i<7; i=i+1)
            paso(0,0,"Boton liberado");

        if (eventos != 0 || ref_db != 0)
            $fatal(1, "Error en estado inicial");

        $display("OK: Inicializacion");

        // =================================
        // B. REBOTES BREVES
        // =================================

        // Tres pulsos fisicos breves,
        // separados por liberaciones.
        // Ninguno debe superar el filtro.

        for (i=0; i<3; i=i+1) begin

            paso(0,1,"Rebote breve");

            for (j=0; j<8; j=j+1)
                paso(0,0,"Recuperacion del rebote");

        end

        if (eventos != 0 || ref_db != 0)
            $fatal(1, "Rebote detectado como pulsacion");

        $display("OK: Rebotes rechazados");

        // =================================
        // C. PRIMERA PULSACION
        // =================================

        // Alternar la entrada antes
        // de mantenerla estable.

        paso(0,1,"Rebote al presionar");
        paso(0,0,"Rebote al presionar");
        paso(0,1,"Rebote al presionar");
        paso(0,0,"Rebote al presionar");

        for (i=0; i<9; i=i+1)
            paso(0,1,"Primera pulsacion estable");

        if (eventos != 1 || ref_db != 1)
            $fatal(1, "Primera pulsacion incorrecta");

        $display("OK: Primera pulsacion, 1 evento");

        // =================================
        // D. BOTON MANTENIDO
        // =================================

        for (i=0; i<10; i=i+1)
            paso(0,1,"Boton mantenido");

        if (eventos != 1 || ref_db != 1)
            $fatal(1, "Evento repetido al mantener boton");

        $display("OK: Sin repeticion por pulsacion mantenida");

        // =================================
        // E. REBOTE DURANTE PULSACION
        // =================================

        paso(0,0,"Rebote de liberacion");

        for (i=0; i<8; i=i+1)
            paso(0,1,"Retorno a pulsacion estable");

        if (eventos != 1 || ref_db != 1)
            $fatal(1, "Falsa liberacion por rebote");

        $display("OK: Rebote sin falsa liberacion");

        // =================================
        // F. LIBERACION ESTABLE
        // =================================

        for (i=0; i<8; i=i+1)
            paso(0,0,"Liberacion estable");

        if (ref_db != 0 || liberaciones != 1)
            $fatal(1, "Liberacion estable incorrecta");

        if (eventos != 1)
            $fatal(1, "Evento generado al liberar");

        $display("OK: Liberacion sin evento");

        // Mantener el boton liberado
        for (i=0; i<8; i=i+1)
            paso(0,0,"Boton liberado sostenido");

        // =================================
        // G. SEGUNDA PULSACION
        // =================================

        for (i=0; i<9; i=i+1)
            paso(0,1,"Segunda pulsacion");

        if (eventos != 2 || ref_db != 1)
            $fatal(1, "Segunda pulsacion incorrecta");

        $display("OK: Segunda pulsacion, 2 eventos acumulados");

        // =================================
        // H. RESET CON BOTON PRESIONADO
        // =================================

        paso(1,1,"INIT con boton presionado");
        paso(1,0,"INIT sostenido");

        if (ref_db != 0 || PRESS_EVENT != 0)
            $fatal(1, "INIT_GLOBAL no domina");

        // Volver a reposo sin generar evento
        for (i=0; i<8; i=i+1)
            paso(0,0,"Reposo despues de INIT");

        if (eventos != 2)
            $fatal(1, "Evento espurio tras INIT");

        $display("OK: Prioridad de INIT_GLOBAL");

        // =================================
        // I. INIT ANTES DE CONFIRMAR
        // =================================

        // Con NDB=4 y dos FF de sincronizacion,
        // cinco ciclos de PRESSED_RAW=1
        // dejan un cambio pendiente.
        // El siguiente ciclo normalmente
        // confirmaria la pulsacion.

        for (i=0; i<5; i=i+1)
            paso(0,1,"Preparar evento pendiente");

        if (ref_cdb != 3 ||
            ref_db != 0 ||
            eventos != 2)
            $fatal(1, "Preparacion de terminal incorrecta");

        // INIT debe impedir el evento pendiente
        paso(1,1,"INIT domina terminal del contador");
        paso(1,0,"INIT final");

        for (i=0; i<8; i=i+1)
            paso(0,0,"Reposo final");

        if (eventos != 2 || ref_db != 0)
            $fatal(1, "Evento pendiente no cancelado");

        $display("OK: INIT cancela pulsacion pendiente");

        // =================================
        // J. RESULTADOS FINALES
        // =================================

        $display("------------------------------");

        $display(
            "CICLOS VERIFICADOS: %0d",
            pruebas
        );

        $display(
            "EVENTOS VALIDOS DETECTADOS: %0d",
            eventos
        );

        $display(
            "LIBERACIONES CONFIRMADAS: %0d",
            liberaciones
        );

        $display(
            "FIN TESTBENCH BOTON_EVENTO"
        );

        $display("------------------------------");

        $finish;

    end

endmodule