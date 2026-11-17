# Workflows n8n

| Archivo | Función |
| --- | --- |
| [preparacion_diaria.json](preparacion_diaria.json) | Busca o crea las carpetas `input`, `processed`, `rejected` y las carpetas de la fecha. |
| [cierre_diario.json](cierre_diario.json) | Lee los CSV de sucursales, valida, carga mediante `process_pos_batch`, mueve archivos y notifica por Gmail. |

Son exports **sanitizados** para mostrar el diseño y poder importarlos en otra instancia. Se retiraron referencias a credenciales y se reemplazaron el ID de la carpeta raíz y el correo destinatario. Al importarlos hay que:

1. Asociar las credenciales propias de Google Drive, PostgreSQL y Gmail.
2. Sustituir `REEMPLAZAR_ID_CARPETA_RAIZ` en la configuración de Drive y en el nodo `Set operating context`.
3. Sustituir `CONFIGURAR_DESTINATARIO@example.com` en los nodos Gmail.
4. Confirmar la zona horaria de ambos workflows antes de habilitar un disparador.

La demo se ejecuta manualmente y los workflows originales están desactivados a propósito. El export de preparación que entregó el autor tiene cron `0 2 * * *` y el cierre `30 20 * * *`: ambos contemplan todos los días. La fecha de carpeta se calcula en `America/Argentina/Buenos_Aires`; antes de activar los cron hay que confirmar también la zona horaria de programación de la instancia.

No se incluyen credenciales, contraseñas ni tokens. Los IDs de nodos se conservaron porque mantienen las conexiones internas del workflow.
