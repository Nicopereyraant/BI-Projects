# Contrato del CSV diario

Un archivo por sucursal y fecha: `input/YYYY-MM-DD/pos_YYYY-MM-DD_S-XX.csv`. `XX` identifica la sucursal. Cada fila representa un producto dentro de una venta; el mismo `venta_id` puede aparecer en varias filas.

| Columna | Tipo esperado | Regla |
| --- | --- | --- |
| `venta_id` | Texto | Identificador estable y único del ticket entre archivos. |
| `fecha_hora` | `YYYY-MM-DD HH:mm:ss` | Debe pertenecer a la fecha de la carpeta. Se interpreta en Argentina (`-03:00`). |
| `sucursal_id` | Texto numérico | Debe coincidir con `S-XX` y existir en `sucursales`. |
| `producto_id` | Texto numérico | Debe existir en `productos`. |
| `cantidad` | Número | Mayor que cero. |
| `precio_unitario` | Número | Cero o mayor; punto decimal. |
| `medio_pago` | Texto | Efectivo, Mercado Pago, Tarjeta de crédito o Tarjeta de débito. |
| `canal` | Texto | Salón, Take Away o Delivery. |

Encabezado exacto:

```csv
venta_id,fecha_hora,sucursal_id,producto_id,cantidad,precio_unitario,medio_pago,canal
```

El flujo acepta variantes sin tilde, como `Salon` y `Tarjeta de credito`, y las normaliza. También acepta `Local` como Salón y `Takeaway` como Take Away. Rechaza valores desconocidos o texto con el carácter de reemplazo `�`, que indica un problema de codificación.

## Validaciones

1. Todas las columnas obligatorias deben estar presentes y completas.
2. La fecha de cada fila y el ID de sucursal deben coincidir con la carpeta y el nombre del archivo.
3. Las líneas de un mismo ticket deben compartir fecha, sucursal, medio de pago y canal.
4. n8n asigna `linea_id`, calcula `subtotal = cantidad × precio_unitario` y suma el total por ticket.
5. PostgreSQL comprueba las claves foráneas y que cada subtotal coincida con cantidad por precio.

El lote se marca `completed` o `rejected` en `import_batches`. Un rechazo genera `errores_YYYY-MM-DD_S-XX.json`. [Ver operación y corrección](operacion.md).

Los [cinco ejemplos del 16/11/2026](../data/ejemplos/) tienen 15 tickets y 30 líneas. Son una prueba del flujo, no un día completo de operación.
