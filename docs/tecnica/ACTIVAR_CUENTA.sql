-- Crear primero tecnica2027@ligamaster.invalid en Authentication > Users.
-- Contraseña indicada por el usuario: establecerla en Authentication, no en código.
begin;
do $$
declare usuario uuid;
begin
  select id into usuario from auth.users where lower(email)='tecnica2027@ligamaster.invalid';
  if usuario is null then raise exception 'Primero crea tecnica2027@ligamaster.invalid en Authentication con correo confirmado.'; end if;
  if exists(select 1 from public.perfiles where id=usuario and rol in ('admin','superadmin','club'))
    or exists(select 1 from public.ligas where admin_id=usuario)
    or exists(select 1 from public.equipos where delegado_id=usuario) then raise exception 'Utiliza una cuenta exclusiva para la comisión técnica.'; end if;
  insert into public.lm_comision_tecnica(usuario_id,activo) values(usuario,true)
  on conflict(usuario_id) do update set activo=true;
end; $$;
commit;
