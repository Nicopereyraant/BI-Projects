# PostgreSQL en Supabase

## Orden para recrear el modelo

1. Ejecutar [00_schema.sql](00_schema.sql) para crear `sucursales`, `productos`, `ventas`, `detalle_ventas` e `import_batches` con claves y controles básicos.
2. Ejecutar [01_pos_ingestion.sql](01_pos_ingestion.sql) para crear la función transaccional de ingesta y las primeras vistas.
3. Ejecutar [02_fix_process_pos_batch.sql](02_fix_process_pos_batch.sql), que corrige la referencia ambigua a `batch_id` en la función.
4. Ejecutar [03_reporting_views.sql](03_reporting_views.sql) para las vistas de franja horaria, medio de pago/canal y estado de lotes.
5. Ejecutar [04_fechas_locales.sql](04_fechas_locales.sql). Corrige las fechas de las vistas diarias y por producto a `America/Argentina/Buenos_Aires`.
6. Importar los [CSV iniciales](../../data/raw/README.md) en este orden: sucursales, productos, ventas, detalle_ventas. Antes, ejecutar [preflight_initial_load.sql](preflight_initial_load.sql) si se quiere verificar que las tablas están vacías.
7. Para reproducir la continuidad histórica, ejecutar [05_backfill_sintetico_2026.sql](05_backfill_sintetico_2026.sql) por semanas cambiando las fechas de su CTE inicial. Usa IDs `HGEN-` e inserción sin duplicados.

El proyecto existente se construyó de forma incremental; los scripts 01 y 02 se conservan para mostrar esa evolución. `process_pos_batch(jsonb)` recibe las ventas y líneas ya validadas por n8n, guarda el lote en `import_batches` y confirma las filas en una operación de base de datos.

## Comprobación

```sql
select count(*) as tickets, sum(total_venta) as facturacion
from public.ventas;

select sum(cantidad_ventas) as tickets, sum(facturacion) as facturacion
from public.vw_ventas_diarias;

select count(*) as descuadres
from (
  select v.venta_id
  from public.ventas v
  left join public.detalle_ventas d using (venta_id)
  group by v.venta_id, v.total_venta
  having v.total_venta <> coalesce(sum(d.subtotal), 0)
) x;
```

Los dos primeros resultados deben coincidir; `descuadres` debe ser cero. En la demo, al 16/11/2026, las vistas y tablas coincidían en **97.246 tickets y $985.550.800**, incluidos los 15 tickets de prueba del último día.

Las tablas del esquema `public` tienen RLS habilitada. Para Data Studio se usa una cuenta PostgreSQL de solo lectura con acceso a las vistas; su contraseña y la conexión privada no se publican aquí.
