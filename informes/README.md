# Informes para el profesor

Los informes los hicimos en LaTeX (formato IEEE) y aquí también están los PDF.

| Informe | PDF | Estructura que pidió el profesor |
|---------|-----|----------------------------------|
| **Avance** | [`avance/informe_avance.pdf`](avance/informe_avance.pdf) | 1. Título · 2. Introducción · 3. Arquitectura diseñada (diagrama de bloques, circuito y listado de sensores y actuadores) · 4. Avance cuantitativo y cualitativo frente al cronograma · 5. Desafíos para cerrar el proyecto · 6. Bibliografía |
| **Desafío** (versión corta) | [`desafio/informe_desafio.pdf`](desafio/informe_desafio.pdf) | 1. Título · 2. Introducción · 3. Arquitectura implementada · 4. Pruebas · 5. Uso de IA · 6. Conclusiones · 7. Bibliografía |
| **Informe final** (completo, F0–F8) | [`final/informe_final.pdf`](final/informe_final.pdf) | Lo mismo que el del Desafío, más la metodología por fases, el diseño lógico con ecuaciones, la regresión completa de F5, los márgenes de tiempo de F6 y la placa de F8 |

## Figuras

Las dibujamos en TikZ y las usamos en los informes y en los README. Están en [`figuras/`](figuras/).

| Figura | Qué muestra |
|--------|-------------|
| [`fig_sistema`](figuras/fig_sistema.png) | Diagrama de bloques del sistema completo con pines |
| [`fig_conexiones`](figuras/fig_conexiones.png) | Circuito a nivel de pines: FPGA, SN74HCT245N, 2N3904, FC-16, CD4511BE y 5161AS |
| [`fig_rtl`](figuras/fig_rtl.png) | Jerarquía de módulos Verilog con sus señales |
| [`fig_fsm`](figuras/fig_fsm.png) | FSM de control del juego |
| [`fig_cronograma`](figuras/fig_cronograma.png) | Cronograma de la propuesta frente a lo ejecutado |

## Volver a compilar

Con TeX Live, o en Overleaf subiendo la carpeta del informe completa:

```bash
cd informes/figuras
for f in fig_*.tex; do pdflatex "$f"; done

cd ../avance  && pdflatex informe_avance.tex  && pdflatex informe_avance.tex
cd ../desafio && pdflatex informe_desafio.tex && pdflatex informe_desafio.tex
cd ../final   && pdflatex informe_final.tex   && pdflatex informe_final.tex
```

El informe final trae todas sus imágenes en `final/figuras/`. Si falta alguna, compila igual y deja un recuadro con el nombre del archivo.

## Lo que nos falta antes de entregar

* **Videos.** Grabar las pruebas V01–V11 y poner los enlaces en la Tabla XII del informe final (están en rojo).
* **Foto de una partida.** Tomar una foto con las matrices y el marcador durante el juego y subirla como `final/figuras/foto_partida.jpg`.
* **Prueba con la placa.** Escribir en la sección de F8 el resultado del juego completo con la placa principal (está en rojo).
