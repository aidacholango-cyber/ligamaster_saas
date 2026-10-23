-- Ejecutar después de crear la cuenta en Authentication > Users > Add user.
-- Correo interno: vocal2026@ligamaster.invalid
-- La contraseña se establece en Supabase Auth, nunca en este SQL ni en Flutter.
begin;
do $$
declare v_usuario uuid;
begin
  select id into v_usuario from auth.users where lower(email)='vocal2026@ligamaster.invalid';
  if v_usuario is null then raise exception 'Primero crea el usuario vocal2026@ligamaster.invalid en Authentication.'; end if;
  insert into public.lm_vocales(usuario_id,activo) values(v_usuario,true)
    on conflict(usuario_id) do update set activo=true;
end; $$;
commit;
select exists(select 1 from public.lm_vocales v join auth.users u on u.id=v.usuario_id
  where u.email='vocal2026@ligamaster.invalid' and v.activo) as cuenta_vocal_activada;
