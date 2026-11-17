-- Ejecutar antes de la carga inicial. No presupone que los CSV ya estén cargados.
select 'sucursales' as tabla, count(*) as filas from public.sucursales
union all select 'productos', count(*) from public.productos
union all select 'ventas', count(*) from public.ventas
union all select 'detalle_ventas', count(*) from public.detalle_ventas;

-- La carga inicial sólo debe continuar cuando los cuatro conteos sean 0,
-- o mediante upsert con una conciliación explícita de los IDs existentes.