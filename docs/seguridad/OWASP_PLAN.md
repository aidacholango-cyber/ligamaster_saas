# Seguridad de LigaMaster — 19 octubre 2026

El alcance es Flutter Web, Supabase Auth, PostgreSQL/RPC, Storage y el hosting
cuando se defina. No se instalan middleware Express ni soluciones para PHP:
esas tecnologías no corresponden al backend actual.

| Riesgo OWASP 2025 | Control correspondiente | Estado |
|---|---|---|
| A01 Acceso | RLS en tablas, permisos de RPC y validación de liga/equipo; bloquear cambio de rol propio | Requiere auditoría actual del servidor y pruebas con dos cuentas |
| A02 Configuración | Cédulas privadas, límites de archivos, redirects y cabeceras del hosting | Bucket privado confirmado; enlace público de prueba rechazado. Falta prueba entre equipos. |
| A03 Dependencias | Conservar lockfile, revisar vulnerabilidades y procedencia, revisión de PR | Pendiente auditoría de versiones contra avisos publicados |
| A04 Criptografía | HTTPS, Auth, ausencia de claves privilegiadas en el cliente | Revisar despliegue e historial; no reemplazar Auth por criptografía casera |
| A05 Inyección | RPC parametrizadas, evitar SQL dinámico y HTML arbitrario | Revisar definiciones activas de las funciones |
| A06 Diseño | Validar inscripciones, actas y archivos en servidor | Funciones locales disponibles; probar abuso y límites reales |
| A07 Autenticación | Mensajes genéricos, límites del proveedor, MFA administrativo, recuperación | Login revisado; configuración Auth pendiente |
| A08 Integridad | Verificación JWT del proveedor, control de versión de actas, cambios revisados | Probar tokens inválidos y concurrencia |
| A09 Registro | Auditoría de acciones sensibles sin tokens ni documentos, alertas y responsable | Historial de actas no sustituye auditoría completa |
| A10 Excepciones | Denegar ante error, mensajes genéricos, transacciones y recuperación | Lector privado falla sin recurrir a URL pública; ampliar pruebas |

## Cédulas sin interrumpir el trabajo

`ImagenCedula` admite los enlaces públicos históricos como referencias del objeto.
Valida proyecto, protocolo, bucket y ruta; no descarga documentos de hosts externos.
No hay migración, borrado ni movimiento de archivos.

La lectura es siempre autenticada desde el 21 octubre 2026; ya no depende de LM_CEDULAS_PRIVADAS. El bucket privado y rechazo de un enlace público de prueba fueron confirmados por la usuaria. No hay fallback público. Se descarta la imagen al cambiar usuario o cerrar el widget. Falta validar lectura entre equipos.

Pasos de migración y verificación:

1. Obtener la configuración activa mediante `auditoria_actual.sql` (solo lectura).
2. Revisar todas las políticas SELECT existentes y las funciones auxiliares.
   Una política permisiva adicional puede ampliar el acceso.
3. Preparar autorización de lectura para delegado propio, administrador competente
   (incluyendo inscripciones invitadas autorizadas) y superadministrador.
4. Ejecutar la aplicación con el indicador privado y comprobar lectura y carga
   con cuentas autorizadas. La selección local de imagen no demuestra el guardado.
5. Solo entonces cerrar el bucket y probar que la URL pública antigua ya no abre,
   que la sesión autorizada sí abre, y que otra cuenta no puede descargar.
6. Probar edición, carga nueva, reemplazo y borrado con registros sintéticos.

No publicar como resuelto mientras el paso 5 no esté verificado. No aplicar una
política inventada sobre producción sin conocer funciones y permisos actuales.

## Evidencia para cerrar cada riesgo

Registrar fecha, rol, operación, resultado esperado/obtenido y evidencia sin datos
personales. Matriz: anónimo; delegado A/B; administrador A/B; superadministrador.
Probar API directa además de botones. Conservar registros y archivos operativos.
Para Auth y hosting faltan ajustes del panel, dominio de despliegue y restauración
de respaldos. No se cambiaron aquí esos ajustes ni la base de producción.

Fuentes: documento docente aportado; https://top10.owasp.org/2025/ ;
https://supabase.com/docs/guides/storage/buckets/fundamentals ;
https://supabase.com/docs/guides/storage/security/access-control .

## Verificación local de esta etapa
- Analizador Dart: sin incidencias en ruta_cedula.dart e imagen_cedula.dart.
- Pantallas integradas: sin errores del analizador; permanecen avisos de estilo.
- Casos del validador ejecutados con Dart directamente: rutas históricas válidas y rechazo de origen/bucket/query/fragmento/rutas ambiguas aprobados.
- flutter test no completó: acceso denegado al lockfile del SDK. No se presenta como prueba Flutter aprobada.
- Descarga autenticada, limpieza visual al cambiar sesión y políticas reales requieren prueba de integración con Supabase.


