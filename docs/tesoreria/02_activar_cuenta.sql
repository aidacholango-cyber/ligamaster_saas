-- Primero crea el usuario con correo confirmado en Authentication > Users:
-- tesoreria2027@ligamaster.invalid. La contraseña se establece allí.
begin;
do $$
declare usuario uuid;
begin
 select id into usuario from auth.users where lower(email)='tesoreria2027@ligamaster.invalid';
 if usuario is null then raise exception 'Primero crea tesoreria2027@ligamaster.invalid en Authentication con correo confirmado.'; end if;
 if exists(select 1 from public.perfiles where id=usuario and rol in ('admin','superadmin','club'))
   or exists(select 1 from public.ligas where admin_id=usuario)
   or exists(select 1 from public.equipos where delegado_id=usuario) then
  raise exception 'Utiliza una cuenta exclusiva para Tesorería, sin convertir una cuenta administradora o delegada.';
 end if;
 insert into public.lm_usuarios_tesoreria(usuario_id,activo) values(usuario,true)
 on conflict(usuario_id) do update set activo=true;
end;
$$;
commit;
select exists(select 1 from public.lm_usuarios_tesoreria t join auth.users u on u.id=t.usuario_id
 where lower(u.email)='tesoreria2027@ligamaster.invalid' and t.activo) as tesoreria_activada;
