# Rol independiente de Tesorería

1. Ejecutar `01_rol_tesoreria.sql` en SQL Editor.
2. En Authentication → Users → Add user → Create new user, crear `tesoreria2027@ligamaster.invalid`, con la contraseña solicitada y **Auto Confirm User** activado. No asignar el rol admin ni superadmin en perfiles.
3. Ejecutar `02_activar_cuenta.sql`. Debe devolver `tesoreria_activada = true`.
4. Elegir **Tesorería** al iniciar sesión. Usuario `tesoreria2027` o su correo.

La contraseña se introduce en Authentication y no se incorpora al código ni al SQL. Al ser un correo interno `.invalid`, no recibe invitaciones ni recuperación por correo; es el mismo mecanismo de las comisiones actuales.

La cuenta tiene acceso a Tesorería de las ligas actuales y futuras, como las cuentas de comisión. Primero elige liga y después campeonato, categoría y equipo. Puede ingresar/publicar cobros, editar valores publicados, registrar aportes y entregas al árbitro, consultar comprobantes, anular movimientos con motivo e imprimir estados de cuenta. También recibe los envíos de Penas y sanciones cuando ese módulo está instalado. Las anulaciones y cambios conservan los historiales de los módulos anteriores.

No se concede acceso para administrar ligas, equipos, jugadores, documentos de identidad, fixtures, resultados o sanciones deportivas. El administrador conserva todos sus accesos y sus funciones financieras. Las cuentas previas de vocal y delegado conservan sus reglas.

El instalador agrega `lm_es_tesoreria()` únicamente a las comprobaciones de administrador de una lista cerrada de funciones financieras. Conserva sus cuerpos instalados, incluidas las validaciones, versiones y reglas de importes, y deja una copia privada de las definiciones anteriores. Si encuentra un control de acceso inesperado, cancela la transacción completa. No se amplía `lm_es_superadmin`, `lm_administra_liga`, las políticas de jugadores ni los permisos de lectura directa de campeonatos.

Los comprobantes utilizan las políticas existentes del bucket privado, cuyo helper financiero acepta además la nueva cuenta. El catálogo específico devuelve el grupo de campeonato para evitar consultas directas adicionales con este usuario.

Prerrequisitos: los módulos de Tesorería manual y Estados de cuenta ya instalados. Si Penas y sanciones se instala o reinstala después, volver a ejecutar `01_rol_tesoreria.sql` para integrar su bandeja. También debe repetirse después de reinstalar funciones financieras antiguas: la ampliación es idempotente.

Los SQL y la cuenta Auth necesitan aplicarse en el proyecto real. La validación local no crea usuarios ni ejecuta migraciones en Supabase.
