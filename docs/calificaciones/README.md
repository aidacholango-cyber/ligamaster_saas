# Comisión de calificaciones

Cuenta solicitada:

- Usuario en la aplicación: `calificaciones2027`.
- Correo interno para Authentication > Users > Add user:
  `calificaciones2027@ligamaster.invalid`.
- Establecer la contraseña solicitada directamente en Supabase Auth y marcar
  el correo como confirmado. La contraseña no se incorpora al código ni al SQL.
- Elegir el rol **Calificaciones** en el inicio de sesión.

## Instalación

1. Ejecutar completo `INSTALAR.sql` en Supabase SQL Editor. Contiene los módulos
   01, 03 y 02 en el orden requerido, dentro de una sola transacción.
2. Crear la cuenta indicada en Authentication > Users > Add user, con la
   contraseña solicitada y el correo confirmado. No asignarle rol de administrador.
3. Ejecutar `04_activar_cuenta.sql`. Debe mostrar `comision_activada = true`.
4. Iniciar sesión con el rol Calificaciones y el usuario indicado.
5. Ejecutar `06_lectura_cedulas.sql` para autorizar la lectura de cédulas
   privadas de jugadores inscritos en los campeonatos activos. No modifica
   las políticas existentes ni hace público el bucket.
6. Ejecutar `08_corregir_lectura_restrictiva.sql`: integra el permiso de la
   comisión en la política restrictiva existente `lm_cedulas_lectura_autorizada`.
   Conserva `lm_puede_leer_cedula(name)` para los usuarios anteriores y añade
   únicamente la alternativa validada de la comisión.

No se han ejecutado estos archivos contra la base de datos desde este proyecto.
Las funciones de revisión y calificación originales del administrador no se
reemplazan. El trigger conserva las validaciones originales y acepta, además,
acciones de la comisión activa sobre jugadores inscritos.

La comisión ayuda en todas las ligas y campeonatos, actuales y futuros,
sin recibir el rol de administrador. El administrador conserva sus funciones originales.
La comisión no puede crear/borrar equipos, jugadores, partidos ni cobros.
El panel reutiliza la ficha de jugadores existente mediante un modo separado;
las rutas y RPC del administrador se conservan.

No se cambia ningún nombre histórico de revisión o calificación.
Las nuevas acciones conservan el nombre del administrador responsable de la
liga, según lo solicitado. El ID autenticado y `lm_comision_auditoria` registran
la cuenta auxiliar que realmente realizó la acción, sin suplantar la sesión del
administrador. Una nueva revisión invalida la calificación anterior como antes.

## Comprobación

- Con la comisión: abrir un equipo participante, ver ficha, revisar con
  observaciones y calificar. Revisar que la ficha se actualice al guardar.
- Con el administrador: comprobar que su panel y las mismas acciones funcionan.
- Con un delegado: las RPC `lm_comision_*` deben rechazar lecturas y escrituras.
- Jugadores no inscritos o de otra categoría/equipo no deben admitirse al
  cambiar manualmente los parámetros de la RPC.
- La comisión no puede usar funciones de tesorería, programación o gestión de
  equipos por el solo hecho de pertenecer a la comisión.
- Las ligas/campeonatos/equipos nuevos inscritos aparecen automáticamente.

Para desactivar la ayuda sin borrar datos ni historial, ejecutar en SQL Editor:

```sql
update public.lm_comision_calificaciones set activo=false
where usuario_id=(select id from auth.users
  where lower(email)='calificaciones2027@ligamaster.invalid');
```
