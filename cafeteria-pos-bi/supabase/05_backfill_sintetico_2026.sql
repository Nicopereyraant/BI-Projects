-- Backfill sintetico para el proyecto ficticio Cafeteria BI.
-- Periodo local: 2026-08-30 a 2026-11-15 (America/Argentina/Buenos_Aires).
-- Los IDs HGEN- permiten identificar estas ventas. El script es idempotente:
-- ON CONFLICT DO NOTHING evita duplicar cabeceras y detalles al repetirlo.
-- Para grandes cargas, ejecutar por semanas cambiando las dos fechas en dias.
-- Las ventas de prueba existentes se preservan.

WITH dias AS (
  SELECT gs::date AS dia
  FROM generate_series(date '2026-08-30', date '2026-11-15', interval '1 day') AS gs
), base AS (
  SELECT d.dia, s.sucursal_id, n.num,
    'HGEN-' || to_char(d.dia, 'YYYYMMDD') || '-S' || lpad(s.sucursal_id, 2, '0') || '-' || lpad(n.num::text, 4, '0') AS venta_id
  FROM dias d
  CROSS JOIN public.sucursales s
  CROSS JOIN LATERAL generate_series(
    1, 105 + get_byte(decode(md5(d.dia::text || ':' || s.sucursal_id), 'hex'), 0) % 21
  ) AS n(num)
), semillas AS (
  SELECT b.*,
    decode(md5(b.venta_id), 'hex') AS h
  FROM base b
), ventas_generadas AS (
  SELECT venta_id, dia, sucursal_id,
    (
      dia::timestamp + make_interval(
        hours => CASE
          WHEN get_byte(h, 0) % 100 < 5 THEN 7
          WHEN get_byte(h, 0) % 100 < 28 THEN 8 + get_byte(h, 1) % 3
          WHEN get_byte(h, 0) % 100 < 48 THEN 11 + get_byte(h, 1) % 3
          WHEN get_byte(h, 0) % 100 < 65 THEN 14 + get_byte(h, 1) % 3
          WHEN get_byte(h, 0) % 100 < 95 THEN 17 + get_byte(h, 1) % 3
          ELSE 20 + get_byte(h, 1) % 2
        END,
        mins => get_byte(h, 2) % 60,
        secs => get_byte(h, 3) % 60
      )
    ) AT TIME ZONE 'America/Argentina/Buenos_Aires' AS fecha_hora,
    CASE WHEN get_byte(h, 4) % 100 < 38 THEN 'Mercado Pago'
         WHEN get_byte(h, 4) % 100 < 70 THEN 'Tarjeta de crédito'
         WHEN get_byte(h, 4) % 100 < 90 THEN 'Tarjeta de débito'
         ELSE 'Efectivo' END AS medio_pago,
    CASE WHEN get_byte(h, 6) % 100 < 60 THEN 'Salón'
         WHEN get_byte(h, 6) % 100 < 88 THEN 'Take Away'
         ELSE 'Delivery' END AS canal,
    2 + CASE WHEN get_byte(h, 5) < 10 THEN 1 ELSE 0 END AS n_lineas
  FROM semillas
), lineas_base AS (
  SELECT v.venta_id, g.linea_id, v.fecha_hora, v.sucursal_id, v.medio_pago, v.canal,
    (ARRAY['1','1','2','2','3','3','4','4','5','6',
           '7','7','8','9','10','11','12','12','13','14','15'])[
      1 + get_byte(decode(md5(v.venta_id || ':' || g.linea_id::text), 'hex'), 0) % 21
    ] AS producto_id,
    1 + CASE WHEN get_byte(decode(md5(v.venta_id || ':q:' || g.linea_id::text), 'hex'), 0) < 46
             THEN 1 ELSE 0 END AS cantidad
  FROM ventas_generadas v
  CROSS JOIN LATERAL generate_series(1, v.n_lineas) AS g(linea_id)
), lineas AS MATERIALIZED (
  SELECT l.*, p.precio_unitario,
    (l.cantidad * p.precio_unitario)::numeric(12,2) AS subtotal
  FROM lineas_base l
  JOIN public.productos p USING (producto_id)
), ventas_insertadas AS (
  INSERT INTO public.ventas
    (venta_id, fecha_hora, sucursal_id, total_venta, medio_pago, canal)
  SELECT venta_id, min(fecha_hora), min(sucursal_id), sum(subtotal),
         min(medio_pago), min(canal)
  FROM lineas
  GROUP BY venta_id
  ON CONFLICT (venta_id) DO NOTHING
  RETURNING venta_id
), detalles_insertados AS (
  INSERT INTO public.detalle_ventas
    (venta_id, linea_id, fecha_hora, sucursal_id, producto_id,
     cantidad, precio_unitario, subtotal, medio_pago, canal)
  SELECT l.venta_id, l.linea_id, l.fecha_hora, l.sucursal_id, l.producto_id,
         l.cantidad, l.precio_unitario, l.subtotal, l.medio_pago, l.canal
  FROM lineas l
  JOIN ventas_insertadas v USING (venta_id)
  ON CONFLICT (venta_id, linea_id) DO NOTHING
  RETURNING venta_id
)
SELECT count(DISTINCT v.venta_id) AS ventas_insertadas,
       (SELECT count(*) FROM detalles_insertados) AS lineas_insertadas
FROM ventas_insertadas v;

-- Validacion global. Se esperan 78 dias, 44835 ventas, 91462 lineas y 0 descuadres.
SELECT count(*) AS ventas,
       sum(total_venta) AS facturacion
FROM public.ventas
WHERE venta_id LIKE 'HGEN-%';

SELECT count(*) AS lineas,
       sum(subtotal) AS facturacion_detalle
FROM public.detalle_ventas
WHERE venta_id LIKE 'HGEN-%';

SELECT count(*) AS descuadres
FROM (
  SELECT v.venta_id
  FROM public.ventas v
  LEFT JOIN public.detalle_ventas d USING (venta_id)
  WHERE v.venta_id LIKE 'HGEN-%'
  GROUP BY v.venta_id, v.total_venta
  HAVING v.total_venta <> coalesce(sum(d.subtotal), 0)
) x;

