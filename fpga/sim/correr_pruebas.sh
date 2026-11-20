#!/usr/bin/env bash
# ============================================================================
#  correr_pruebas.sh
#  Pong en FPGA - Electrónica Digital 1 - UNAL
#  Juan David Ortiz Muñoz, David Eduardo Chivata Arias, Daniel Felipe Castro González
# ----------------------------------------------------------------------------
#  Los testbenches los corrimos originalmente en Questa (Quartus Prime 25.1
#  Lite). Este script los corre con Icarus Verilog, que es gratis y funciona
#  en cualquier computador o en GitHub, para que cualquiera pueda repetir las
#  pruebas sin instalar Quartus.
#
#  Corre todos los tb/tb_*.v contra el RTL final (F6). Los testbenches de
#  tb/anteriores_al_movimiento_diagonal/ no se corren: esperan el movimiento
#  de la pelota que teníamos antes de F5.
#
#  Uso (desde cualquier carpeta):
#       bash fpga/sim/correr_pruebas.sh            # todas las pruebas
#       bash fpga/sim/correr_pruebas.sh f5         # solo las que contengan "f5"
#
#  Cada prueba deja su registro en sim/resultados/<testbench>.log
# ============================================================================
set -u
cd "$(dirname "$0")/.."

mkdir -p sim/resultados sim/build
FILTRO="${1:-}"
RTL=$(ls rtl/*.v)

pasan=0; fallan=0; resumen=""

for tb in tb/tb_*.v; do
  nombre=$(basename "$tb" .v)
  if [[ -n "$FILTRO" && "$nombre" != *"$FILTRO"* ]]; then continue; fi

  # -s fija el testbench como raíz: en rtl/ conviven varios tops (F3, F4, F5 y F6)
  if ! iverilog -g2012 -s "$nombre" -o "sim/build/$nombre.vvp" "$tb" $RTL > "sim/build/$nombre.compilacion.log" 2>&1; then
    resumen+="  NO COMPILA  $nombre\n"; fallan=$((fallan+1)); continue
  fi
  vvp -n "sim/build/$nombre.vvp" > "sim/resultados/$nombre.log" 2>&1
  rc=$?

  # Nuestros testbenches imprimen ERROR/FATAL y paran con $stop o $fatal
  # cuando algo no cuadra; si no aparece nada de eso, la prueba pasó.
  if [[ $rc -ne 0 ]] || grep -q -E "^(ERROR|FATAL)|\\\$stop called|Error:" "sim/resultados/$nombre.log"; then
    resumen+="  FALLA      $nombre   (ver sim/resultados/$nombre.log)\n"; fallan=$((fallan+1))
  else
    # Línea de resumen que imprime cada testbench (si la tiene)
    detalle=$(grep -h -E "COMPROBACIONES|TOTAL VERIFICADO|PRUEBAS|RESULTADO|OK:|PASS" "sim/resultados/$nombre.log" | tail -1 | sed 's/^ *//' | cut -c1-80)
    resumen+="  PASA       $nombre   $detalle\n"; pasan=$((pasan+1))
  fi
done

echo "=========================== RESUMEN ==========================="
printf "%b" "$resumen"
echo "Pasan: $pasan   Fallan: $fallan"
[[ $fallan -eq 0 ]]
