# Operación y recuperación

## Ejecutar una prueba

1. Confirmar que existe la carpeta de Drive `input/YYYY-MM-DD/`, donde la fecha es la operativa en `America/Argentina/Buenos_Aires`.
2. Subir los CSV `pos_YYYY-MM-DD_S-01.csv` a `S-05.csv`, sin mezclar otras fechas en esa carpeta.
3. Ejecutar manualmente el workflow de cierre en n8n. La demo conserva desactivado el disparador automático.
4. Comprobar que cada archivo quedó en `processed/YYYY-MM-DD/` o `rejected/YYYY-MM-DD/` y que llegó el aviso de Gmail.
5. Consultar `vw_import_batches` y las vistas comerciales en Supabase. Data Studio puede tardar hasta que venza la caché de la fuente; el editor también puede usar **Actualizar datos**.

## Si un archivo se rechaza

Descargar el CSV y `errores_YYYY-MM-DD_S-XX.json` desde `rejected`. Revisar la fila y el código de error, corregir el archivo original y volver a subirlo a `input/YYYY-MM-DD/`. La nueva carga tendrá otro ID de archivo de Drive. Conservar el mismo `venta_id` para el mismo ticket permite conciliar reintentos; no reutilizarlo para otra venta.

Ejemplo probado: un medio de pago inválido se corrigió en el CSV de origen y se reenvió; la nueva ejecución quedó en `processed`.

## Consultas de control

```sql
select fecha_operativa, source_file_name, status, rows_received, rows_loaded, errors
from public.vw_import_batches
order by created_at desc
limit 20;

select v.venta_id, v.total_venta, coalesce(sum(d.subtotal), 0) as suma_detalle
from public.ventas v
left join public.detalle_ventas d using (venta_id)
group by v.venta_id, v.total_venta
having v.total_venta <> coalesce(sum(d.subtotal), 0);
```

La segunda consulta debe devolver cero filas. El [SQL de backfill](../supabase/05_backfill_sintetico_2026.sql) incluye controles específicos para las ventas `HGEN-`.

## Estado de programación

El export de preparación tiene un cron a las 02:00 todos los días y el de cierre a las 20:30 todos los días. Ambos están desactivados en esta demo. Sus configuraciones exportadas no fijan la zona horaria del disparador, aunque calculan la fecha operativa con `America/Argentina/Buenos_Aires`; antes de activarlos habría que confirmar la zona horaria de la instancia.

## Lectura correcta del dashboard

La serie histórica está completa hasta el **15/11/2026**. El **16/11/2026** contiene solo 15 tickets de prueba; una caída visual ese día significa cobertura parcial, no una caída real del negocio ficticio. Limitar el período del gráfico a días completos o mostrar una advertencia de cobertura.
