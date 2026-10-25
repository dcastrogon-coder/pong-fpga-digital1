#!/usr/bin/env bash
# ============================================================================
#  sintesis_yosys.sh
#  Revisión rápida de síntesis con Yosys (sin Quartus). No reemplaza la
#  compilación en Quartus II, pero nos sirve para:
#    - detectar latches inferidos sin querer,
#    - tener una idea del tamaño del diseño en celdas de Cyclone IV E,
#    - comprobar que todo el RTL es sintetizable antes de ir al laboratorio.
#  Uso:  bash scripts/sintesis_yosys.sh
# ============================================================================
set -e
cd "$(dirname "$0")/.."
mkdir -p sim/logs

yosys -p "read_verilog rtl/*.v; synth_intel -family cycloneive -top pong_top; stat" \
      > sim/logs/sintesis_yosys.log 2>&1

echo "Latches inferidos:"
grep -c "Latch inferred" sim/logs/sintesis_yosys.log || true
echo
sed -n '/^14. Printing statistics/,/^End of script/p' sim/logs/sintesis_yosys.log \
    | grep -E "cycloneive_lcell_comb|dffeas|Number of cells"
echo
echo "La EP4CE10E22C8N tiene 10 320 elementos lógicos."
