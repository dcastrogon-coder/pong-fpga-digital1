#!/usr/bin/env bash
# ============================================================================
#  correr_todo.sh
#  Compila y corre todos los testbenches con Icarus Verilog.
#  Uso (desde la raíz del repositorio):
#       bash sim/correr_todo.sh            # todas las pruebas
#       bash sim/correr_todo.sh paletas    # solo las que contengan "paletas"
#
#  Cada simulación deja su registro en sim/logs/ y su forma de onda (.vcd)
#  en sim/, que se puede abrir con GTKWave.
# ============================================================================
set -u
cd "$(dirname "$0")/.."

mkdir -p sim/logs sim/build

RTL="rtl"
FILTRO="${1:-}"

# nombre_del_tb : archivos RTL que necesita
declare -A FUENTES=(
  [tb_colisiones]="$RTL/colisiones.v"
  [tb_paletas]="$RTL/paletas.v"
  [tb_pelota]="$RTL/pelota.v $RTL/colisiones.v"
  [tb_puntaje]="$RTL/puntaje.v"
  [tb_control_juego]="$RTL/control_juego.v"
  [tb_entradas]="$RTL/entradas.v $RTL/antirrebote.v"
  [tb_generador_ticks]="$RTL/generador_ticks.v"
  [tb_imagen]="$RTL/imagen.v"
  [tb_siete_segmentos]="$RTL/siete_segmentos.v"
  [tb_max7219]="$RTL/max7219_tx.v $RTL/imagen.v tb/modelo_max7219.v"
  [tb_integracion]="$RTL/*.v tb/modelo_max7219.v"
)

ORDEN="tb_colisiones tb_paletas tb_pelota tb_puntaje tb_control_juego tb_entradas \
tb_generador_ticks tb_imagen tb_siete_segmentos tb_max7219 tb_integracion"

pasan=0; fallan=0; resumen=""

for tb in $ORDEN; do
  if [[ -n "$FILTRO" && "$tb" != *"$FILTRO"* ]]; then continue; fi
  echo ">> $tb"
  if ! iverilog -g2012 -I tb -o "sim/build/$tb.vvp" "tb/$tb.v" ${FUENTES[$tb]} \
        > "sim/logs/$tb.compilacion.log" 2>&1; then
    echo "   error de compilación, ver sim/logs/$tb.compilacion.log"
    fallan=$((fallan+1)); resumen+="  $tb : NO COMPILA\n"; continue
  fi
  vvp -n "sim/build/$tb.vvp" > "sim/logs/$tb.log" 2>&1
  linea=$(grep -m1 "^RESULTADO" "sim/logs/$tb.log" || echo "RESULTADO $tb: SIN REPORTE")
  echo "   $linea"
  if [[ "$linea" == *": PASA"* ]]; then
    pasan=$((pasan+1)); resumen+="  $linea\n"
  else
    fallan=$((fallan+1)); resumen+="  $linea\n"
  fi
done

echo
echo "================ RESUMEN ================"
printf "%b" "$resumen"
echo "Pasan: $pasan   Fallan: $fallan"
[[ $fallan -eq 0 ]]
