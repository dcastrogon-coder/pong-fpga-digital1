#!/usr/bin/env bash
# ============================================================================
#  correr_etapa1.sh - Simula la etapa 1 y saca las figuras.
#  Uso (desde la raíz del repositorio o desde esta carpeta):
#       bash etapas/etapa1_pantalla/correr_etapa1.sh
# ============================================================================
set -e
cd "$(dirname "$0")"
mkdir -p sim
FUENTES="tb_etapa1.v etapa1_pantalla.v imagen_punto.v ../../rtl/generador_ticks.v \
../../rtl/antirrebote.v ../../rtl/max7219_tx.v ../../tb/modelo_max7219.v"

ok=0
for div in 1 2; do
  echo ">> tb_etapa1 con DIV_PRUEBA=$div"
  iverilog -g2012 -DDIV_PRUEBA=$div -o sim/tb_etapa1_$div.vvp $FUENTES
  vvp -n sim/tb_etapa1_$div.vvp > sim/tb_etapa1_div$div.log 2>&1 || true
  linea=$(grep -m1 "^RESULTADO" sim/tb_etapa1_div$div.log || echo "SIN REPORTE")
  echo "   $linea"
  [[ "$linea" == *": PASA"* ]] || ok=1
done

# Las figuras salen de la corrida rápida (DIV_PRUEBA = 1)
if command -v python3 >/dev/null && python3 -c "import matplotlib" 2>/dev/null; then
  python3 graficar_etapa1.py
fi
exit $ok
