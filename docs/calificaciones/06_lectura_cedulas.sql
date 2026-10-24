-- Permiso adicional de lectura para la comisión. No cambia archivos,
-- bucket, fichas, políticas existentes ni permite subir/borrar documentos.
begin;
create or replace function public.lm_comision_puede_leer_cedula(p_ruta text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null
    and public.lm_es_comision_calificaciones()
    and p_ruta is not null and p_ruta<>''
    and exists(
      select 1 from public.jugadores j
      join public.campeonato_jugadores cj on cj.jugador_id=j.id
        and cj.equipo_id=j.equipo_id and cj.estado='inscrito'
      join public.campeonatos c on c.id=cj.campeonato_id
        and c.activo=true and c.categoria=j.categoria
      join public.campeonato_equipos ce on ce.campeonato_id=c.id
        and ce.equipo_id=j.equipo_id and ce.estado='inscrito'
      join public.equipos e on e.id=j.equipo_id and e.liga_id::text=c.liga_id::text
      -- Coincidencia con la referencia de la ficha, no con cualquier archivo
      -- del equipo. El cliente sigue descargando con sesión autenticada.
      where split_part(j.foto_cedula_url,
        '/storage/v1/object/public/cedulas_jugadores/',2)=p_ruta
    );
$$;
revoke all on function public.lm_comision_puede_leer_cedula(text) from public,anon,authenticated;
grant execute on function public.lm_comision_puede_leer_cedula(text) to authenticated;

drop policy if exists lm_comision_lectura_cedulas on storage.objects;
create policy lm_comision_lectura_cedulas on storage.objects
  for select to authenticated using (
    bucket_id='cedulas_jugadores'
    and public.lm_comision_puede_leer_cedula(name)
  );
commit;
