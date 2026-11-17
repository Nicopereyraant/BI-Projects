create or replace view public.vw_ventas_diarias as
select (v.fecha_hora at time zone 'America/Argentina/Buenos_Aires')::date as fecha,
       s.sucursal, s.ciudad, count(*) as cantidad_ventas,
       sum(v.total_venta) as facturacion, round(avg(v.total_venta),2) as ticket_promedio
from public.ventas v
join public.sucursales s using (sucursal_id)
group by 1,2,3;

create or replace view public.vw_ventas_por_producto as
select (d.fecha_hora at time zone 'America/Argentina/Buenos_Aires')::date as fecha,
       s.sucursal, s.ciudad, p.producto, p.categoria,
       sum(d.cantidad) as unidades_vendidas, sum(d.subtotal) as facturacion
from public.detalle_ventas d
join public.sucursales s using (sucursal_id)
join public.productos p using (producto_id)
group by 1,2,3,4,5;
