-- El informe se conecta a PostgreSQL con el rol looker_ro.
-- Las vistas de public, por defecto, pueden eludir RLS si no se restringen.
-- Este script evita la lectura por la API anon/authenticated y conserva
-- los permisos explícitos del rol de solo lectura.

revoke all privileges on
  public.vw_import_batches,
  public.vw_ventas_diarias,
  public.vw_ventas_por_producto,
  public.vw_ventas_por_medio_pago_canal,
  public.vw_ventas_por_franja_horaria
from public, anon, authenticated;

revoke execute on function public.process_pos_batch(jsonb)
from public, anon, authenticated;

-- Verificación: anon y authenticated deben ser false; looker_ro,
-- true solo para las cuatro vistas comerciales.
select c.relname as vista,
       has_table_privilege('anon', c.oid, 'SELECT') as anon,
       has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated,
       has_table_privilege('looker_ro', c.oid, 'SELECT') as looker
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname like 'vw_%'
order by c.relname;

select has_function_privilege('anon', 'public.process_pos_batch(jsonb)', 'EXECUTE') as anon_exec,
       has_function_privilege('authenticated', 'public.process_pos_batch(jsonb)', 'EXECUTE') as authenticated_exec,
       has_function_privilege('postgres', 'public.process_pos_batch(jsonb)', 'EXECUTE') as postgres_exec;
