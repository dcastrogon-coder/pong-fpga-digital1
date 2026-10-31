# Desarrollo por etapas

En vez de armar todo el Pong de una, lo vamos construyendo por etapas. Cada una agrega unos bloques, se simula y se prueba en la tarjeta antes de pasar a la siguiente. Los colores de la [Figura 1](../docs/figuras/figura1_estructura.png) dicen a qué etapa pertenece cada bloque.

| Etapa | Carpeta | Qué se ve en la tarjeta | Guía | Estado |
|-------|---------|-------------------------|------|--------|
| E1 · Pantalla | [`etapa1_pantalla/`](etapa1_pantalla/) | Un punto que recorre la matriz de 8 × 32 | [`docs/paso_a_paso/etapa1_pantalla.md`](../docs/paso_a_paso/etapa1_pantalla.md) | Simulada ✔ · falta probar en la tarjeta |
| E2 · Entradas y paletas | — | Las paletas se mueven con los botones | — | Pendiente |
| E3 · Pelota y colisiones | — | La pelota rebota | — | Pendiente |
| E4 · Reglas, marcador y sonido | — | El juego completo | — | Pendiente |

La versión completa del juego (todas las etapas juntas) está en [`rtl/`](../rtl/) y sirve de referencia.

Para simular la etapa 1:

```bash
bash etapas/etapa1_pantalla/correr_etapa1.sh
```
