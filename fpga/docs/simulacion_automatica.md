# Script de simulación y GitHub Actions

[Volver al índice](README.md) · Archivos: [`sim/correr_pruebas.sh`](../sim/correr_pruebas.sh), [`.github/workflows/simulacion.yml`](../../.github/workflows/simulacion.yml)

## Para qué sirven

Con 35 bancos de prueba, correrlos uno por uno en Questa toma bastante tiempo. Escribimos un script que los corre todos con un solo comando y nos dice cuáles pasan y cuáles no. Además, configuramos GitHub para que ejecute ese script cada vez que alguien sube un cambio al repositorio. Así, si una modificación daña algo, lo vemos antes de llevar el diseño a la tarjeta.

## `sim/correr_pruebas.sh`

### Uso

```bash
bash fpga/sim/correr_pruebas.sh          # todos los bancos
bash fpga/sim/correr_pruebas.sh f5       # solo los que tengan "f5" en el nombre
```

Se puede llamar desde cualquier carpeta, porque lo primero que hace es moverse a `fpga/`. Necesita Icarus Verilog (`sudo apt install iverilog` en Ubuntu o WSL).

### Qué hace, paso a paso

1. **Prepara las carpetas** `sim/build/` (archivos compilados, que no se suben al repositorio) y `sim/resultados/` (un registro por banco).
2. **Toma todos los archivos de `rtl/`** como diseño.
3. **Para cada `tb/tb_*.v`:**
   * Lo compila junto con el RTL:
     ```bash
     iverilog -g2012 -s "$nombre" -o "sim/build/$nombre.vvp" "$tb" $RTL
     ```
     La opción `-s` le dice a Icarus cuál es el módulo superior. Es necesaria porque en `rtl/` hay varios tops (`pong_top`, `pong_f4_visual_top`, `pong_f5_controles_top` y `pong_f6_integracion_top`), y sin ella Icarus intentaría simularlos todos a la vez.
   * Si no compila, lo marca como `NO COMPILA`.
   * Si compila, lo simula con `vvp` y guarda todo lo que imprime en `sim/resultados/<banco>.log`.
4. **Decide si pasó.** Un banco falla si `vvp` termina con error o si en el registro aparece alguna línea que empiece con `ERROR` o `FATAL`, un `$stop` o un `Error:`. Si no aparece nada de eso, pasó, y del registro se toma la última línea de resumen (`PASS`, `OK`, `COMPROBACIONES`...) para mostrarla.
5. **Imprime el resumen** y termina con código 0 si todo pasó, o 1 si algo falló. Ese código es el que usa GitHub para marcar la ejecución en verde o en rojo.

### Ejemplo de salida

```
=========================== RESUMEN ===========================
  PASA       tb_boton_evento   OK: INIT cancela pulsacion pendiente
  PASA       tb_captura_imagen   PRUEBAS SUPERADAS: 13
  ...
  PASA       tb_transmisor_max7219   OK: Cuadro 2 Fila 8/8 WORD=01810100
Pasan: 35   Fallan: 0
```

La salida completa está en [`fpga/README.md`](../README.md).

### Por qué Icarus y no solo Questa

Questa viene con Quartus y es la herramienta con la que hicimos las simulaciones originales, pero necesita instalar Quartus y configurar su licencia. Icarus Verilog es libre, pesa poco y corre en cualquier computador y en los servidores de GitHub. Los bancos están escritos en Verilog estándar, así que funcionan en los dos.

Los bancos de `tb/anteriores_al_movimiento_diagonal/` no se corren, porque el patrón `tb/tb_*.v` solo toma los archivos de la carpeta `tb/` (ver [bancos de prueba](bancos_de_prueba.md)).

## `.github/workflows/simulacion.yml`

Es la configuración de GitHub Actions. Se ejecuta en cada `push` y en cada *pull request*:

```yaml
on:
  push:
  pull_request:

jobs:
  pruebas:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4                 # descarga el repositorio
      - run: sudo apt-get install -y iverilog     # instala Icarus
      - run: bash fpga/sim/correr_pruebas.sh      # corre los 35 bancos
      - uses: actions/upload-artifact@v4          # guarda los registros
        if: always()
        with:
          path: fpga/sim/resultados/
```

* GitHub crea una máquina virtual con Ubuntu, descarga el repositorio, instala Icarus y corre el script.
* Si el script termina con error, la ejecución queda en rojo en la pestaña *Actions* y junto al último cambio.
* Al final, pase o no pase, guarda la carpeta `sim/resultados/` como un archivo descargable, para poder ver el registro del banco que falló.
