-- Esquema base para la cafeteria ficticia. Ejecutar antes de importar data/raw/*.csv.
-- La funcion de ingesta y las vistas se crean en los scripts siguientes.

create table if not exists public.sucursales (
  sucursal_id text primary key,
  sucursal text not null,
  direccion text,
  ciudad text not null
);

create table if not exists public.productos (
  producto_id text primary key,
  producto text not null,
  categoria text,
  precio_unitario numeric not null check (precio_unitario >= 0)
);

create table if not exists public.ventas (
  venta_id text primary key,
  fecha_hora timestamptz not null,
  sucursal_id text not null references public.sucursales(sucursal_id),
  total_venta numeric not null check (total_venta >= 0),
  medio_pago text,
  canal text,
  created_at timestamptz not null default now()
);

create table if not exists public.detalle_ventas (
  venta_id text not null references public.ventas(venta_id),
  linea_id integer not null,
  fecha_hora timestamptz not null,
  sucursal_id text not null references public.sucursales(sucursal_id),
  producto_id text not null references public.productos(producto_id),
  cantidad numeric not null check (cantidad > 0),
  precio_unitario numeric not null check (precio_unitario >= 0),
  subtotal numeric not null check (subtotal >= 0),
  medio_pago text,
  canal text,
  constraint detalle_ventas_pkey primary key (venta_id, linea_id),
  constraint chk_detalle_subtotal check (subtotal = round(cantidad * precio_unitario, 2))
);

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

alter table public.sucursales enable row level security;
alter table public.productos enable row level security;
alter table public.ventas enable row level security;
alter table public.detalle_ventas enable row level security;
alter table public.import_batches enable row level security;
