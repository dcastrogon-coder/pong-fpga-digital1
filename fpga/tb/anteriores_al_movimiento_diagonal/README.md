# Testbenches anteriores al movimiento diagonal

Estos cuatro bancos de prueba los escribimos antes de cambiar la pelota a movimiento diagonal en F5 (el 14 de noviembre). Esperan que la pelota avance en Y solo cada dos pulsos (bit PHASE), así que con el RTL final fallan en el primer movimiento, que es lo esperado.

| Archivo | De qué fase es | Qué lo reemplaza |
|---------|----------------|------------------|
| `tb_pelota.v` | F3 | `tb_pelota_diagonal_f5.v` |
| `tb_pong_colisiones_rebotes.v` | F3 | `tb_pelota_goles_diagonal_f5.v` y `tb_colisiones.v` |
| `tb_pelota_goles_f5.v` | Comienzos de F5 | `tb_pelota_goles_diagonal_f5.v` |
| `tb_hct_imagen_dinamica_f5.v` | Comienzos de F5 | `tb_hct_filas_f5.v` y `tb_hct_refresco_f5.v` |

Los dejamos como registro de cómo verificamos el comportamiento anterior. `correr_pruebas.sh` no los corre.
