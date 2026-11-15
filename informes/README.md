# Informes para el profesor

Los dos informes están en LaTeX (formato IEEE) y ya compilados en PDF.

| Informe | PDF | Estructura que pidió el profesor |
|---------|-----|----------------------------------|
| **Avance** | [`avance/informe_avance.pdf`](avance/informe_avance.pdf) | 1. Título · 2. Introducción · 3. Arquitectura diseñada (diagrama de bloques, circuito y listado de sensores y actuadores) · 4. Avance cuantitativo y cualitativo frente al cronograma · 5. Desafíos para cerrar el proyecto · 6. Bibliografía |
| **Desafío** (informe final) | [`desafio/informe_desafio.pdf`](desafio/informe_desafio.pdf) | 1. Título · 2. Introducción · 3. Arquitectura implementada · 4. Pruebas · 5. Uso de IA · 6. Conclusiones · 7. Bibliografía |

## Figuras

Todas están en [`figuras/`](figuras/), en TikZ, y se usan en los dos informes y en los README.

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

## Supuestos que hay que revisar antes de entregar

* **Semanas del cronograma.** La propuesta habla de S1–S4 sin fechas. Tomamos S1 = 26 oct – 1 nov, S2 = 2–8 nov, S3 = 9–15 nov y S4 = 16–22 nov. Si el profesor contaba otras semanas, se cambian en `figuras/fig_cronograma.tex` y en la Tabla II del informe de avance.
* **Porcentajes de avance.** Son nuestra estimación por actividad (Tabla II del avance). El promedio da 88 %.
* **Uso de IA.** La sección 5 del informe del Desafío dice que en F0–F7 usamos IA para depuración y revisión, y que con Claude organizamos el repositorio, las figuras y los borradores de estos informes. Si alguien usó IA en otra parte, hay que agregarlo.
* **Fotos y video.** El informe del Desafío solo tiene la foto de F4. Conviene agregar una foto del montaje completo con el marcador y el enlace a un video de una partida.
