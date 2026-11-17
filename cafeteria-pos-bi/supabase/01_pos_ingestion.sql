-- Ejecutar una vez en Supabase SQL Editor antes de activar el workflow de cierre.
create extension if not exists pgcrypto;

-- Cambia la PK para admitir el mismo producto más de una vez en una venta.
alter table public.detalle_ventas add column if not exists linea_id integer;
with lineas as (
  select ctid, row_number() over (partition by venta_id order by producto_id, ctid)::integer as linea_id
  from public.detalle_ventas
)
update public.detalle_ventas d set linea_id = l.linea_id from lineas l where d.ctid = l.ctid and d.linea_id is null;
alter table public.detalle_ventas alter column linea_id set not null;
alter table public.detalle_ventas drop constraint if exists detalle_ventas_pkey;
alter table public.detalle_ventas add constraint detalle_ventas_pkey primary key (venta_id, linea_id);
alter table public.detalle_ventas drop constraint if exists chk_detalle_subtotal;
alter table public.detalle_ventas add constraint chk_detalle_subtotal check (subtotal = round(cantidad * precio_unitario, 2));

create table if not exists public.import_batches (
  batch_id uuid primary key default gen_random_uuid(),
  source_file_id text not null unique,
  source_file_name text not null,
  operating_date date not null,
  content_hash text not null,
  status text not null check (status in ('processing', 'completed', 'rejected')),
  rows_received integer not null default 0,
  rows_loaded integer not null default 0,
  errors jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create or replace function public.process_pos_batch(p_batch jsonb)
returns table(status text, batch_id uuid, message text)
language plpgsql as $$
declare
  v_batch public.import_batches%rowtype;
  v_missing_suc integer;
  v_missing_prod integer;
  v_bad_subtotal integer;
begin
  insert into public.import_batches (source_file_id, source_file_name, operating_date, content_hash, status, rows_received)
  values (p_batch->>'source_file_id', p_batch->>'source_file_name', (p_batch->>'operating_date')::date,
    encode(digest(coalesce(p_batch->'lines', '[]'::jsonb)::text, 'sha256'), 'hex'), 'processing',
    jsonb_array_length(coalesce(p_batch->'lines', '[]'::jsonb)))
  on conflict (source_file_id) do nothing;

  select * into v_batch from public.import_batches where source_file_id = p_batch->>'source_file_id' for update;
  if v_batch.status = 'completed' then
    return query select 'already_completed'::text, v_batch.batch_id, 'Archivo ya confirmado; no se reinsertó.'::text;
    return;
  end if;

  select count(*) into v_missing_suc from jsonb_to_recordset(p_batch->'lines') x(sucursal_id text)
    left join public.sucursales s using (sucursal_id) where s.sucursal_id is null;
  select count(*) into v_missing_prod from jsonb_to_recordset(p_batch->'lines') x(producto_id text)
    left join public.productos p using (producto_id) where p.producto_id is null;
  select count(*) into v_bad_subtotal from jsonb_to_recordset(p_batch->'lines') x(cantidad numeric, precio_unitario numeric, subtotal numeric)
    where subtotal <> round(cantidad * precio_unitario, 2);
  if v_missing_suc > 0 or v_missing_prod > 0 or v_bad_subtotal > 0 then
    update public.import_batches as ib set status = 'rejected', errors = jsonb_build_object(
      'missing_branches', v_missing_suc, 'missing_products', v_missing_prod, 'invalid_subtotals', v_bad_subtotal)
    where ib.batch_id = v_batch.batch_id;
    return query select 'rejected'::text, v_batch.batch_id, 'Falló la validación de referencias o subtotales.'::text;
    return;
  end if;

  insert into public.ventas (venta_id, fecha_hora, sucursal_id, total_venta, medio_pago, canal)
  select venta_id, fecha_hora::timestamptz, sucursal_id, total_venta, medio_pago, canal
  from jsonb_to_recordset(p_batch->'sales') x(venta_id text, fecha_hora text, sucursal_id text, total_venta numeric, medio_pago text, canal text)
  on conflict (venta_id) do update set fecha_hora = excluded.fecha_hora, sucursal_id = excluded.sucursal_id,
    total_venta = excluded.total_venta, medio_pago = excluded.medio_pago, canal = excluded.canal;

  insert into public.detalle_ventas (venta_id, linea_id, fecha_hora, sucursal_id, producto_id, cantidad, precio_unitario, subtotal, medio_pago, canal)
  select venta_id, linea_id, fecha_hora::timestamptz, sucursal_id, producto_id, cantidad, precio_unitario, subtotal, medio_pago, canal
  from jsonb_to_recordset(p_batch->'lines') x(venta_id text, linea_id integer, fecha_hora text, sucursal_id text, producto_id text, cantidad numeric, precio_unitario numeric, subtotal numeric, medio_pago text, canal text)
  on conflict (venta_id, linea_id) do update set fecha_hora = excluded.fecha_hora, sucursal_id = excluded.sucursal_id,
    producto_id = excluded.producto_id, cantidad = excluded.cantidad, precio_unitario = excluded.precio_unitario,
    subtotal = excluded.subtotal, medio_pago = excluded.medio_pago, canal = excluded.canal;

  update public.import_batches as ib set status = 'completed', rows_loaded = jsonb_array_length(p_batch->'lines'), completed_at = now(), errors = null
  where ib.batch_id = v_batch.batch_id;
  return query select 'completed'::text, v_batch.batch_id, 'Carga confirmada.'::text;
end;
$$;

create or replace view public.vw_ventas_diarias as
select v.fecha_hora::date as fecha, s.sucursal, s.ciudad, count(*) as cantidad_ventas,
       sum(v.total_venta) as facturacion, round(avg(v.total_venta), 2) as ticket_promedio
from public.ventas v join public.sucursales s using (sucursal_id) group by 1,2,3;

create or replace view public.vw_ventas_por_producto as
select d.fecha_hora::date as fecha, s.sucursal, s.ciudad, p.producto, p.categoria,
       sum(d.cantidad) as unidades_vendidas, sum(d.subtotal) as facturacion
from public.detalle_ventas d join public.sucursales s using (sucursal_id) join public.productos p using (producto_id)
group by 1,2,3,4,5;