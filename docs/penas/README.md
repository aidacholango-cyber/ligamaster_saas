# Comisión de penas y sanciones

Instalar en SQL Editor, en este orden:

1. `01_acceso_y_consulta.sql`.
2. `02_revision_y_envio.sql`.
3. Crear `sanciones2027@ligamaster.invalid` en Authentication → Users, con correo confirmado y la contraseña solicitada por el usuario. La contraseña no se guarda en el código ni en SQL.
4. `ACTIVAR_CUENTA.sql`.

Entrar en la app con **Penas y sanciones**, usuario `sanciones2027` o su correo.

La comisión solo consulta hojas de vocalía confirmadas de campeonatos activos y revisa tarjetas/suspensiones. No recibe acceso para programar, borrar partidos, editar jugadores, modificar resultados, firmas, ingresar importes ni registrar pagos. El administrador conserva todos sus permisos y además puede abrir **Revisar sanciones** desde un partido confirmado del fixture para modificar la revisión.

La hoja firmada y la planilla original no se sobrescriben. Las correcciones se guardan por partido e inscripción del jugador, con motivo, autor, versión y respaldo de cada guardado/envío. Las cuentas normales no pueden consultar/escribir esas tablas directamente; los RPC comprueban la cuenta y el partido.

**Guardar revisión** aplica las correcciones al resumen de sanciones. Cada jugador puede seguir en automático o activar una corrección manual de T.A., roja directa y total de partidos de suspensión generados por ese encuentro (0–100). Una suspensión manual reemplaza la generación automática de ese encuentro; no es el total pendiente de toda la temporada. Desactivar la corrección devuelve ese jugador al cálculo automático.

El cálculo conserva las reglas facilitadas: dos amarillas generan un partido, roja directa dos, cada cinco amarillas otro; se descuentan fechas confirmadas posteriores sin participación. Se conservan las alertas de fechas ambiguas y participación durante suspensión. No se inventan participaciones para los jugadores a quienes se añada una sanción manual.

`lm_leer_sanciones` y las vistas `lm_control_sanciones`/`lm_resumen_disciplina` no se modifican. La pantalla utiliza el nuevo lector, que conserva la autorización original para administradores/delegados y superpone las correcciones. Si el nuevo RPC aún no está instalado, la pantalla conserva la consulta anterior. Las demás integraciones que consulten directamente las vistas originales siguen mostrando el dato original; este complemento no reemplaza sus reglas ni bloqueos.

**Enviar a Tesorería** guarda y envía una copia revisada, separada por equipo, sin valores. La administración verá la revisión en Tesorería → equipo → partido y en el detalle de sus cobros. Quien gestiona Tesorería carga los importes manualmente mediante sus accesos actuales; este módulo no crea otro usuario de tesorería ni publica cobros automáticamente. No se suman importes por reenviar: cada consulta muestra el último envío del partido. Una corrección que retira tarjetas también se informa para revisar cobros anteriores.

Si la hoja, resultado, fecha o planilla original cambia, las correcciones anteriores dejan de superponerse y el envío a Tesorería muestra una advertencia. La comisión debe revisar nuevamente. La versión del editor impide sobrescribir revisiones concurrentes; un error de red puede requerir volver a cargar antes de reintentar.

Prerrequisitos: módulos actuales de vocalía (incluida la calificación arbitral), comisión técnica (columna de equipo de vocalía), inscripción por campeonato y las vistas disciplinarias originales. El módulo no cambia las habilitaciones ni sanciones económicas de otros roles.

Opcional: ejecutar `VERIFICAR_CALCULO.sql` después de instalar; es una comparación de solo lectura y debe devolver cero filas en campeonatos sin correcciones. El SQL no se ha ejecutado automáticamente en Supabase desde el entorno local.
