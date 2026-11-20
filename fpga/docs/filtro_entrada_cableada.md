# `filtro_entrada_cableada.v`: antirrebote de cada línea de los mandos

[Volver al índice](README.md) · Código: [`rtl/filtro_entrada_cableada.v`](../rtl/filtro_entrada_cableada.v)

## Qué hace

Limpia una sola línea de un mando (UP, DOWN o DETECT): la sincroniza con el reloj y solo acepta un cambio cuando se ha mantenido estable 20 ms. A la salida entrega el nivel filtrado, todavía activo en bajo.

Hay seis instancias, todas dentro de [`supervisor_cableado`](supervisor_cableado.md): tres por cada jugador.

## Parámetros

| Parámetro | Valor | Significado |
|-----------|-------|-------------|
| `NDB` | 1 000 000 | Ciclos de estabilidad necesarios: 20 ms a 50 MHz |

## Puertos

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| `CLK_SYS` | entrada | Reloj de 50 MHz |
| `INIT_GLOBAL` | entrada | Reset del sistema |
| `RAW_N` | entrada | Línea del mando tal como llega del pin (0 = activo) |
| `CLEAN_N` | salida | Línea filtrada (0 = activo) |

## Cómo funciona

```verilog
SYNC_1 <= RAW_N;
SYNC_2 <= SYNC_1;

if (SYNC_2 == CLEAN_N)          COUNT <= 0;          // no hay cambio
else if (COUNT == TC_DB) begin  CLEAN_N <= SYNC_2;   // cambio confirmado
                                COUNT <= 0; end
else                            COUNT <= COUNT + 1;  // seguir contando
```

1. **Sincronización.** Dos flip-flops en fila, igual que en [`boton_evento`](boton_evento.md), para evitar metaestabilidad.
2. **Comparación.** Si la entrada sincronizada coincide con la salida actual, no hay nada que hacer y el contador se queda en 0.
3. **Cuenta.** Si son distintas, el contador sube. Un rebote que devuelva la entrada a su valor anterior pone el contador otra vez en 0.
4. **Confirmación.** Cuando el contador llega a `NDB − 1`, la salida toma el nuevo valor.

Con `INIT_GLOBAL` todo vuelve a 1 (inactivo): `SYNC_1`, `SYNC_2` y `CLEAN_N`.

## Diferencias con `boton_evento`

| | `boton_evento` | `filtro_entrada_cableada` |
|-|----------------|---------------------------|
| Polaridad | Activo en alto | Activo en bajo |
| Salida | Nivel y pulso de un ciclo | Solo nivel |
| Uso | START, PAUSE | UP, DOWN, DETECT |

Para las paletas no queremos un pulso sino el nivel: mientras el jugador mantenga presionado UP, la paleta sigue subiendo una casilla cada 250 ms. Por eso este filtro no genera eventos.

## Por qué lo hicimos así

* **Un módulo pequeño reutilizado seis veces.** Escribir el filtro una vez y probarlo bien es más seguro que repetir la misma lógica en el supervisor.
* **Valor inicial en 1.** Después de un reset, todas las líneas arrancan "inactivas". En particular, DETECT arranca como "mando desconectado" y solo pasa a "conectado" cuando lleva 20 ms en 0. Así el juego no puede arrancar con un mando que esté haciendo falso contacto.
* **Mismo tiempo que los pulsadores.** Usamos 20 ms en todas las entradas para que el comportamiento sea igual en todo el sistema.

## Cómo lo probamos

No tiene un banco de prueba propio: lo cubren `tb_supervisor_cableado_f5`, que prueba las seis instancias a la vez, y `tb_hct_controles_cableados_f5`, que comprueba que los rebotes cortos se rechazan en el sistema completo.

## Historia

Lo creamos en F5, cuando cambiamos los mandos inalámbricos por mandos cableados.
