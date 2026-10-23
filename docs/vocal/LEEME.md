# Panel del vocal

Esta primera etapa permite elegir fecha, cancha y partido de todas las ligas; escribir vocal y árbitro; ingresar jugadores por camiseta viendo foto y nombre; y guardar TA, TR y goles en una planilla independiente.

Durante el partido los cambios se guardan automáticamente cada tres segundos cuando vocal y árbitro están completos. Al pulsar «Terminar partido y publicar», las tarjetas y goles se transfieren a la planilla oficial y se confirma el resultado en una sola transacción. Si el administrador ya preparó un acta oficial, el cierre del vocal se detiene para no sobrescribirla. Las reglas existentes de confirmación siguen vigentes. Esta pantalla calcula el marcador a partir de los goles ingresados; no incluye todavía captura de autogoles, prórroga ni tanda de penales. En móvil los equipos se muestran uno debajo del otro; en escritorio aparecen a izquierda y derecha.

## Instalación

Para esta actualización, ejecutar **INSTALAR_VOCAL_COMPLETO.sql** después de crear la cuenta. Este archivo reúne los tres scripts y la activación en una transacción. Las pantallas de consulta deportiva revisan cambios cada cinco segundos mientras están visibles; es actualización automática por consulta periódica, no una suscripción push.

1. Ejecutar `01_panel_vocal.sql` en el SQL Editor del proyecto Supabase. Es una transacción que agrega dos tablas y cuatro funciones nuevas. No modifica las tablas, políticas ni funciones existentes de los otros roles.
2. En Authentication → Users → Add user → Create new user, crear el correo interno `vocal2026@ligamaster.invalid`, con la contraseña solicitada por el propietario y la confirmación de correo activada. No enviar invitación: este correo interno no recibe mensajes.
3. Ejecutar `02_activar_cuenta.sql`. Habilita únicamente el UUID correspondiente a ese correo. No cambia `perfiles.rol` ni amplía las políticas de jugadores.
4. Reiniciar Flutter. Seleccionar rol **Vocal**, usuario **vocal2026** y la contraseña configurada. También se admite el correo completo.

La contraseña se almacena exclusivamente mediante Supabase Auth; no forma parte de Flutter, SQL ni este documento. El alias está previsto para esta cuenta; las futuras cuentas podrán iniciar sesión mediante su correo.

## Alcance de acceso

- Cuenta activa de `lm_vocales`: consulta de todos los partidos por fecha y de datos deportivos mínimos de sus jugadores.
- Sin cédulas, teléfonos, direcciones ni correo de jugadores.
- Guarda su planilla y puede publicar el primer resultado oficial de un partido abierto. No puede reabrir ni sustituir un resultado oficial existente ni cambiar la programación.
- Nuevas tablas con RLS y sin acceso directo de `anon`/`authenticated`; las funciones comprueban el usuario en el servidor.
- Se validan inscripción, equipo, campeonato, calificación, jugadores duplicados, TA 0–2, TR booleana y goles 0–99.
- Bloqueo de guardado si el partido, fase o campeonato está cerrado o el resultado confirmado.
- Control de versión para no sobrescribir lo guardado desde otra sesión.

## Verificación tras instalar

1. Abrir una fecha con partidos programados y comprobar cancha, horario, categoría y liga.
2. Buscar una camiseta de cada equipo y verificar foto/nombre antes de ingresar.
3. Intentar repetir al jugador: debe aparecer «Ya ingresado».
4. Escribir vocal/árbitro, cambiar TA/TR/goles, guardar y reabrir: deben persistir.
5. Abrir el mismo partido en dos sesiones; guardar en una y después en la otra: la segunda debe avisar del conflicto.
6. Verificar que la cuenta del vocal no puede abrir directamente los paneles administrativos ni consultar cédulas.
7. Confirmar que los otros tres roles conservan su inicio de sesión y operaciones habituales.

La instalación SQL y estas pruebas requieren acceso al proyecto Supabase. No se deben describir como completadas solo por pasar el análisis de Dart.
