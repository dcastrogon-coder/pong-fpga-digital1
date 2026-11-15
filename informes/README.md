# Informes para el profesor

Los dos informes los hicimos en LaTeX (formato IEEE) y aquí también están los PDF.

| Informe | PDF | Estructura que pidió el profesor |
|---------|-----|----------------------------------|
| **Avance** | [`avance/informe_avance.pdf`](avance/informe_avance.pdf) | 1. Título · 2. Introducción · 3. Arquitectura diseñada (diagrama de bloques, circuito y listado de sensores y actuadores) · 4. Avance cuantitativo y cualitativo frente al cronograma · 5. Desafíos para cerrar el proyecto · 6. Bibliografía |
| **Desafío** (informe final) | [`desafio/informe_desafio.pdf`](desafio/informe_desafio.pdf) | 1. Título · 2. Introducción · 3. Arquitectura implementada · 4. Pruebas · 5. Uso de IA · 6. Conclusiones · 7. Bibliografía |

## Figuras

Las dibujamos en TikZ y las usamos en los dos informes y en los README. Están en [`figuras/`](figuras/).

| Figura | Qué muestra |
|--------|-------------|
| [`fig_sistema`](figuras/fig_sistema.png) | Diagrama de bloques del sistema completo con pines |
| [`fig_conexiones`](figuras/fig_conexiones.png) | Circuito a nivel de pines: FPGA, SN74HCT245N, 2N3904, FC-16, CD4511BE y 5161AS |
| [`fig_rtl`](figuras/fig_rtl.png) | Jerarquía de módulos Verilog con sus señales |
| [`fig_fsm`](figuras/fig_fsm.png) | FSM de control del juego |
| [`fig_cronograma`](figuras/fig_cronograma.png) | Cronograma de la propuesta frente a lo ejecutado |

## Volver a compilar

Con TeX Live (o en Overleaf subiendo la carpeta `informes/` completa y la foto de `fases/F4_interfaz_visual/`):

```bash
cd informes/figuras
for f in fig_*.tex; do pdflatex "$f"; done

cd ../avance  && pdflatex informe_avance.tex  && pdflatex informe_avance.tex
cd ../desafio && pdflatex informe_desafio.tex && pdflatex informe_desafio.tex
```

## Lo que nos falta antes de entregar

* **Semanas del cronograma.** En la propuesta pusimos S1–S4 sin fechas. Para comparar tomamos S1 = 26 oct – 1 nov, S2 = 2–8 nov, S3 = 9–15 nov y S4 = 16–22 nov. Si hay que cambiarlas, se cambian en `figuras/fig_cronograma.tex` y en la Tabla II del informe de avance.
* **Fotos y video.** Por ahora el informe del Desafío solo tiene la foto de F4. Nos falta tomar una foto del montaje completo con el marcador y grabar una partida.
* **F5.** Subir la memoria y el código de F5 y F6.
