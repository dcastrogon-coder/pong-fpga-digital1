# `temporizadores.v`: ritmo de la pelota y de las paletas

[Volver al índice](README.md) · Código: [`rtl/temporizadores.v`](../rtl/temporizadores.v)

## Qué hace

Marca el ritmo del juego. Tiene dos contadores que cuentan ciclos del reloj de 50 MHz y, cada vez que llegan a su valor final, dan un pulso de un ciclo:

* **`TICK_BALL`** cada 200 ms: la pelota avanza una casilla.
* **`TICK_PADDLE`** cada 250 ms: las paletas pueden moverse una casilla.

Sin este bloque, todo se movería 50 millones de veces por segundo y el juego sería imposible de ver.

## Parámetros

| Parámetro | Valor | Tiempo |
|-----------|-------|--------|
| `N_BALL` | 10 000 000 | 10 000 000 × 20 ns = 200 ms |
| `N_PADDLE` | 12 500 000 | 12 500 000 × 20 ns = 250 ms |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS`, `INIT_GLOBAL` | entrada | Reloj y reset |
| `GAME_EN` | entrada | Permiso de [`control_juego`](control_juego.md) para que el juego avance |
| `REARM_TIMERS` | entrada | Pone los dos contadores en cero (al empezar o reanudar) |
| `TICK_BALL` | salida | Pulso de un ciclo cada 200 ms de juego |
| `TICK_PADDLE` | salida | Pulso de un ciclo cada 250 ms de juego |

## Cómo funciona

### Contadores

Hay dos contadores de 24 bits, `CB` (pelota) y `CP` (paletas). Con 24 bits se puede contar hasta 16 777 215, suficiente para los dos valores. Los dos funcionan igual:

```verilog
if (INIT_GLOBAL || REARM_TIMERS)  CB <= 0;
else if (GAME_EN) begin
    if (FIN_BALL) CB <= 0;          // llegó a N_BALL − 1: vuelve a empezar
    else          CB <= CB + 1;
end
// si GAME_EN = 0, CB conserva su valor
```

Cuando el juego no está en marcha (ESPERA, pausa, FIN), los contadores se **detienen** pero no se borran.

### Pulsos

```verilog
assign CE         = GAME_EN && !REARM_TIMERS && !INIT_GLOBAL;
assign TICK_BALL  = CE && (CB == TC_BALL);
assign TICK_PADDLE = CE && (CP == TC_PADDLE);
```

El pulso sale en el ciclo en que el contador está en su último valor, y solo si en ese ciclo el juego tiene permiso para avanzar.

### Rearme

Cuando el juego pasa a JUEGO (después de START o al quitar una pausa), [`control_juego`](control_juego.md) activa `REARM_TIMERS` durante un ciclo y los contadores vuelven a cero. Por eso el primer paso de la pelota siempre llega 200 ms después de presionar START, y el primer paso posible de las paletas 250 ms después.

## Por qué lo hicimos así

* **Pulsos de habilitación y no relojes nuevos.** Una forma ingenua sería dividir el reloj y usar la salida como reloj de los demás módulos. Eso crea varios dominios de reloj, que son difíciles de analizar en tiempos y fuente de errores. Con pulsos de un ciclo, todo el diseño sigue funcionando con un único reloj de 50 MHz.
* **Ritmos distintos para pelota y paletas.** Con 200 ms la pelota se ve rápida pero se puede seguir. Las paletas a 250 ms son un poco más lentas, lo que obliga al jugador a anticiparse. Los dos ritmos coinciden cada segundo (el mínimo común múltiplo de 200 y 250 ms es 1 000 ms); ese caso lo resuelven [`paletas`](paletas.md) y [`colisiones`](colisiones.md) usando la posición nueva de la paleta.
* **Detener en vez de borrar durante la pausa.** No hace falta borrar, porque el rearme al reanudar ya los deja en cero. Lo importante es que durante la pausa no salga ningún pulso.

## Cómo lo probamos

* `tb_temporizadores` (F3): compara con un modelo de referencia ciclo a ciclo, con periodos de 4 y 5 ciclos (la misma proporción 4:5 que hay entre 200 y 250 ms). Revisa la inicialización, la periodicidad y los ticks que coinciden.
* `tb_temporizadores_f5`: 13 pruebas con las condiciones de F5, incluidos la pausa y el rearme.
* `tb_integracion_temporizada_f5` revisa los tiempos dentro del núcleo completo.

## Historia

Escrito en F3. No cambió en las fases siguientes. El paso al movimiento diagonal de F5 se hizo en [`pelota`](pelota.md) y no hizo falta un tercer temporizador.
