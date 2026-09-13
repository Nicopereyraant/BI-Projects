PROYECTO POS - CAFETERÍA FICTICIA

Datos ficticios generados para portfolio de Data/BI + Automation.

Período: 2026-06-01 a 2026-08-29
Ciudad: CABA
Sucursales: 5

Archivos:
- ventas.csv: una fila por ticket/venta.
- detalle_ventas.csv: una fila por producto dentro de cada ticket.
- productos.csv: catálogo de productos.
- sucursales.csv: catálogo de sucursales.

Supuesto de negocio:
El POS de cada sucursal registra las ventas y permite exportar
diariamente un CSV. n8n simulará la recepción/detección de esos
archivos y realizará la ingesta hacia una base de datos.

Modelo sugerido:
sucursales 1:N ventas
ventas 1:N detalle_ventas
productos 1:N detalle_ventas

Los datos son completamente ficticios.
