# F7 · Informe técnico del funcionamiento en protoboard

Documento: [`F7_informe_funcionamiento_protoboard.pdf`](F7_informe_funcionamiento_protoboard.pdf) · 15 de noviembre de 2026 · **PC6**

Aquí explicamos cómo funciona el prototipo de F6, subsistema por subsistema, y relacionamos cada parte del montaje con la lógica en Verilog: entradas cableadas, FSM de seis estados, temporizadores, paletas, pelota diagonal, colisiones, puntaje BCD, supervisión y reset, instantánea de imagen, enlace serial con los GC7219C, búferes y marcador.

No hicimos pruebas nuevas en esta fase: recogimos las de F5 y F6. En la memoria planteamos dos PCB para F8, una para los mandos y otra para búferes, matrices y marcador. Al final el profesor aprobó dejar los controles en protoboard y solo hicimos la placa principal; está en [`F8_pcb_kicad/`](../F8_pcb_kicad/).
