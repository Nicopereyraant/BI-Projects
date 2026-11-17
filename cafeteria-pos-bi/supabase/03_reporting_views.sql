-- Vistas adicionales para el dashboard de Power BI.
-- Todas las horas se calculan en America/Argentina/Buenos_Aires.

create or replace view public.vw_ventas_por_franja_horaria as
with ventas_locales as (
  select
    v.venta_id,
    v.total_venta,
    v.sucursal_id,
    (v.fecha_hora at time zone 'America/Argentina/Buenos_Aires') as fecha_hora_local
  from public.ventas v
)
select
  vl.fecha_hora_local::date as fecha,
  s.sucursal_id,
  s.sucursal,
  s.ciudad,
  case
    when extract(hour from vl.fecha_hora_local) between 8 and 10 then '08:00-10:59 Desayuno'
    when extract(hour from vl.fecha_hora_local) between 11 and 13 then '11:00-13:59 Mediodia'
    when extract(hour from vl.fecha_hora_local) between 14 and 16 then '14:00-16:59 Tarde'
    when extract(hour from vl.fecha_hora_local) between 17 and 19 then '17:00-19:59 Merienda'
    else 'Fuera de horario'
  end as franja_horaria,
  count(*) as cantidad_ventas,
  sum(vl.total_venta) as facturacion,
  round(avg(vl.total_venta), 2) as ticket_promedio
from ventas_locales vl
join public.sucursales s using (sucursal_id)
group by 1, 2, 3, 4, 5;

create or replace view public.vw_ventas_por_medio_pago_canal as
with ventas_locales as (
  select
    v.venta_id,
    v.total_venta,
    v.sucursal_id,
    coalesce(nullif(trim(v.medio_pago), ''), 'Sin especificar') as medio_pago,
    coalesce(nullif(trim(v.canal), ''), 'Sin especificar') as canal,
    (v.fecha_hora at time zone 'America/Argentina/Buenos_Aires') as fecha_hora_local
  from public.ventas v
)
select
  vl.fecha_hora_local::date as fecha,
  s.sucursal_id,
  s.sucursal,
  s.ciudad,
  vl.medio_pago,
  vl.canal,
  count(*) as cantidad_ventas,
  sum(vl.total_venta) as facturacion,
  round(avg(vl.total_venta), 2) as ticket_promedio
from ventas_locales vl
join public.sucursales s using (sucursal_id)
group by 1, 2, 3, 4, 5, 6;

-- Control operativo: permite ver el estado de cada archivo importado.
create or replace view public.vw_import_batches as
select
  operating_date as fecha_operativa,
  source_file_name,
  status,
  rows_received,
  rows_loaded,
  errors,
  created_at,
  completed_at
from public.import_batches;