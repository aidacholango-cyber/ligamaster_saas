-- Ejecutar después de instalar el módulo y crear el usuario en Authentication.
-- Correo: sanciones2027@ligamaster.invalid. Establecer contraseña allí.
begin;
do $$
declare usuario uuid;
begin
 select id into usuario from auth.users where lower(email)='sanciones2027@ligamaster.invalid';
 if usuario is null then raise exception 'Primero crea sanciones2027@ligamaster.invalid en Authentication, con correo confirmado.'; end if;
 if exists(select 1 from public.perfiles where id=usuario and rol in ('admin','superadmin','club'))
  or exists(select 1 from public.ligas where admin_id=usuario)
  or exists(select 1 from public.equipos where delegado_id=usuario) then raise exception 'Utiliza una cuenta exclusiva para penas y sanciones.'; end if;
 insert into public.lm_comision_penas(usuario_id,activo) values(usuario,true)
 on conflict(usuario_id) do update set activo=true;
end; $$;
commit;
