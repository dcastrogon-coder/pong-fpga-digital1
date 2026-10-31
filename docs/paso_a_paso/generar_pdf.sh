#!/usr/bin/env bash
# Genera el PDF de la guía de la etapa 1 (para mandarlo por WhatsApp).
# Necesita pandoc y xelatex.  Uso:  bash docs/paso_a_paso/generar_pdf.sh
set -e
cd "$(dirname "$0")"
pandoc etapa1_pantalla.md -f markdown-implicit_figures -o etapa1_pantalla.pdf \
  --pdf-engine=xelatex -V mainfont="DejaVu Sans" -V monofont="DejaVu Sans Mono" \
  -V geometry:margin=1.8cm -V fontsize=10pt -V lang=es -V colorlinks=true -V linestretch=1.1
echo "-> docs/paso_a_paso/etapa1_pantalla.pdf"
