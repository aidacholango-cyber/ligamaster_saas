-- Crear primero en Authentication > Users > Add user:
-- calificaciones2027@ligamaster.invalid, con correo confirmado.
-- La contraseña se establece allí, nunca en Flutter ni en este SQL.
begin;
do $$
declare usuario uuid;
begin
  if to_regprocedure('public.lm_comision_revisar_jugador(uuid,uuid,text)') is null
    or to_regprocedure('public.lm_comision_calificar_jugador(uuid,uuid)') is null then
    raise exception 'Instala primero los archivos 01, 03 y 02 del módulo.';
  end if;
  select id into usuario from auth.users
    where lower(email)='calificaciones2027@ligamaster.invalid';
  if usuario is null then
    raise exception 'Primero crea calificaciones2027@ligamaster.invalid en Authentication.';
  end if;
  -- No permitir convertir una cuenta administradora o delegada en comisión.
  if exists(select 1 from public.perfiles p where p.id=usuario and p.rol in ('admin','superadmin','club'))
    or exists(select 1 from public.ligas l where l.admin_id=usuario)
    or exists(select 1 from public.equipos e where e.delegado_id=usuario) then
    raise exception 'Esta cuenta tiene otro cargo. Utiliza una cuenta exclusiva de comisión.';
  end if;
  insert into public.lm_comision_calificaciones(usuario_id,activo) values(usuario,true)
    on conflict(usuario_id) do update set activo=true;
end; $$;
commit;
select exists(select 1 from public.lm_comision_calificaciones c
  join auth.users u on u.id=c.usuario_id
  where lower(u.email)='calificaciones2027@ligamaster.invalid' and c.activo)
  as comision_activada;
