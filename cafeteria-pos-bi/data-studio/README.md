# Informe en Data Studio

[**Abrir Cafetería BI**](https://datastudio.google.com/reporting/e766b5be-9e38-4b20-ab02-e50497bd8e88/page/mKvBG) · El enlace puede requerir que el propietario habilite la visualización.

El informe se conecta directamente a vistas PostgreSQL de Supabase mediante una cuenta de solo lectura. Se construyó en Data Studio a partir del diseño inicial de Power BI. No hay un archivo exportable del informe en este repositorio: la referencia es el enlace y la especificación siguiente.

## Páginas

| Página | Indicadores |
| --- | --- |
| Resumen ejecutivo | Facturación, tickets, ticket promedio, unidades vendidas, evolución diaria, facturación por sucursal y unidades por producto. |
| Comportamiento de ventas | Facturación por medio de pago, franja horaria, canal y categoría de producto. |

## Fuentes SQL

| Vista | Uso principal |
| --- | --- |
| `vw_ventas_diarias` | KPIs de ventas, evolución y sucursales. |
| `vw_ventas_por_producto` | Unidades por producto y facturación por categoría. |
| `vw_ventas_por_medio_pago_canal` | Participación por pago y canal. |
| `vw_ventas_por_franja_horaria` | Facturación por hora del día agrupada en franjas. |

En los indicadores, **tickets** es `SUM(cantidad_ventas)`, **facturación** es `SUM(facturacion)` y **ticket promedio** es `SUM(facturacion) / SUM(cantidad_ventas)` para el filtro aplicado. **Unidades** es `SUM(unidades_vendidas)`. Promediar promedios diarios sin ponderación daría un resultado distinto.

Las vistas usan fechas de Argentina; la [corrección explícita](../supabase/04_fechas_locales.sql) evita que tickets de la noche pasen al día siguiente por la zona UTC de PostgreSQL. El informe ofrece filtros de fecha y sucursal. Un clic sobre un gráfico aplica interacción en su página; no se traslada automáticamente a la otra página.

## Actualización y lectura

Los datos nuevos llegan al informe cuando Data Studio vuelve a consultar las vistas, sujeto a la caché configurada para cada fuente. Un editor puede usar **Actualizar datos** para comprobar una carga reciente. Esto no requiere republicar el reporte.

La serie diaria es completa hasta el **15/11/2026**. El **16/11/2026** contiene 15 tickets de prueba; debe filtrarse o identificarse como día parcial para no atribuir la caída visual al negocio. No se publican credenciales de la conexión PostgreSQL.
