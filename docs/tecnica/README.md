# Comisión técnica

1. Ejecutar `INSTALAR.sql` y después `02_eliminar_partidos.sql` en SQL Editor de Supabase.
2. En Authentication → Users → Add user, crear `tecnica2027@ligamaster.invalid`, establecer la contraseña solicitada y confirmar el correo.
3. Ejecutar `ACTIVAR_CUENTA.sql`.
4. En la app elegir **Comisión técnica**, usuario `tecnica2027` (o su correo) y la contraseña establecida.

El panel muestra campeonatos activos de todas las ligas, sus fases abiertas y equipos inscritos. Permite programar cruces y editar fecha, hora, cancha, jornada y equipo responsable de la vocalía. Los cruces existentes no cambian. Los partidos confirmados quedan bloqueados. El basurero permite eliminar, con confirmación, partidos sin planilla, resultado, borrador de vocalía ni tesorería. No concede permisos de administración, inscripción, calificación, resultados, tesorería ni cancelación. La contraseña no se almacena en Flutter ni en SQL.

El administrador conserva sus permisos y tiene **Asignar vocalía** en cada partido del fixture. El equipo asignado aparece allí y en la hoja de vocalía; el nombre de la persona que llena la hoja se mantiene separado. El turno es por partido y se conserva al editarlo con el formulario anterior. No se reasignan partidos históricos automáticamente.

Las sanciones por incumplir el turno y sus montos las ingresa manualmente el administrador mediante los cobros de Tesorería; este módulo no genera cobros ni registra pagos automáticamente. El importe de ese cobro debe cargarse al equipo sancionado, nunca a sus rivales.

La función de programación es independiente: conserva las validaciones de la definición facilitada para `lm_fixture_guardar_partido`, añade la cuenta técnica, cancha/fecha obligatorias y pertenencia del equipo de vocalía al campeonato. No reemplaza la función original ni amplía `lm_fixture_autorizar` ni sus políticas. La tabla de habilitación tiene RLS y no admite lectura/escritura directa desde cuentas normales.

El SQL debe instalarse en el proyecto real; la validación local de Flutter no ejecuta cambios en Supabase.
