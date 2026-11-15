# F5 · Controles cableados y validación física del juego

14 de noviembre de 2026 · **PC5**

> ⚠️ **Falta subir** la memoria técnica de F5 y su código (`pong_f5_core.v`, `filtro_entrada_cableada.v`, `supervisor_cableado.v`). Lo que sigue sale de las referencias que hacen F6 y F7.

En esta fase el juego quedó funcionando en la tarjeta con las dos matrices:

* Los controles RF se reemplazaron por **mandos cableados** con UP, DOWN y DETECT (detección de que el mando está conectado). Las entradas pasan por dos flip-flops de sincronización y un antirrebote de 20 ms.
* La señal `RF_OK_EFF` del diseño original se reutilizó para la conexión del mando: si un mando se desconecta, el juego pasa a PAUSA_RF y no sigue hasta reconectarlo y presionar START.
* La pelota pasó a moverse en **diagonal** (X e Y en cada pulso de 200 ms).

Pruebas observadas en la FPGA real (según F6 y F7): START, PAUSE, RESET, paletas independientes, movimiento diagonal, rebotes, goles y pausa al desconectar un mando.
