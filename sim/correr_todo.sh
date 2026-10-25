#!/usr/bin/env bash
# ============================================================================
#  correr_todo.sh
#  Compila y corre todos los testbenches con Icarus Verilog.
#  Uso (desde la raíz del repositorio):
#       bash sim/correr_todo.sh            # todas las pruebas, 16 y 32 columnas
#       bash sim/correr_todo.sh paletas    # solo las que contengan "paletas"
#       SOLO32=1 bash sim/correr_todo.sh   # solo la versión del módulo x4
#
#  Primero corremos las pruebas que dependen del ancho de la cancha con 16
#  columnas (dos matrices sueltas, la propuesta original) y luego todo con 32
#  (el módulo MAX7219 x4 que compramos). Así las ondas y el registro de la
#  partida que quedan al final son los de 32 columnas.
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
  [tb_max7219]="$RTL/max7219_tx.v tb/modelo_max7219.v"
  [tb_integracion]="$RTL/*.v tb/modelo_max7219.v"
)

# Pruebas cuyo resultado depende del ancho de la cancha
DEPENDEN_DEL_ANCHO="tb_colisiones tb_pelota tb_imagen tb_max7219 tb_integracion"

TODAS="tb_colisiones tb_paletas tb_pelota tb_puntaje tb_control_juego tb_entradas \
tb_generador_ticks tb_imagen tb_siete_segmentos tb_max7219 tb_integracion"

pasan=0; fallan=0; resumen=""

correr() {   # $1 = testbench, $2 = ancho
  local tb="$1" ancho="$2" nombre="$1"
  [[ "$ancho" != "32" ]] && nombre="${tb}_${ancho}"
  echo ">> $tb ($ancho columnas)"
  if ! iverilog -g2012 -I tb -DANCHO_PRUEBA="$ancho" -o "sim/build/$nombre.vvp" "tb/$tb.v" ${FUENTES[$tb]} \
        > "sim/logs/$nombre.compilacion.log" 2>&1; then
    echo "   error de compilación, ver sim/logs/$nombre.compilacion.log"
    fallan=$((fallan+1)); resumen+="  $tb [$ancho col] : NO COMPILA\n"; return
  fi
  vvp -n "sim/build/$nombre.vvp" > "sim/logs/$nombre.log" 2>&1
  local linea
  linea=$(grep -m1 "^RESULTADO" "sim/logs/$nombre.log" || echo "RESULTADO $tb: SIN REPORTE")
  echo "   $linea"
  if [[ "$linea" == *": PASA"* ]]; then pasan=$((pasan+1)); else fallan=$((fallan+1)); fi
  resumen+="  [$ancho col] $linea\n"
}

if [[ -z "${SOLO32:-}" ]]; then
  for tb in $DEPENDEN_DEL_ANCHO; do
    if [[ -n "$FILTRO" && "$tb" != *"$FILTRO"* ]]; then continue; fi
    correr "$tb" 16
  done
fi

for tb in $TODAS; do
  if [[ -n "$FILTRO" && "$tb" != *"$FILTRO"* ]]; then continue; fi
  correr "$tb" 32
done

echo
echo "================ RESUMEN ================"
printf "%b" "$resumen"
echo "Pasan: $pasan   Fallan: $fallan"
[[ $fallan -eq 0 ]]
