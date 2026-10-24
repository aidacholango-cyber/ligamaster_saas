-- Consulta de solo lectura para vocal y administradores de la liga.
begin;
create or replace function public.lm_hoja_vocalia_leer(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_editable boolean;
begin
  if auth.uid() is null or not (
    coalesce(public.lm_es_vocal(),false)
    or exists(select 1 from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
      where p.id=p_partido_id and coalesce(public.lm_es_superadmin() or public.lm_administra_liga(c.liga_id::text),false))
  ) then raise exception 'No tienes permiso para consultar esta hoja de vocalía.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id;
  if not found then raise exception 'El partido ya no existe.'; end if;
  if not exists(select 1 from public.campeonato_resultados r where r.partido_id=p_partido_id and r.estado='confirmado') then
    raise exception 'La hoja de vocalía estará disponible cuando se confirme el partido.';
  end if;
  if not exists(select 1 from public.lm_vocal_borradores b where b.partido_id=p_partido_id) then
    raise exception 'Este partido no tiene una hoja de vocalía guardada.';
  end if;
  select v_p.estado='programado' and c.estado not in ('finalizado','archivado')
    and not exists(select 1 from public.campeonato_resultados r where r.partido_id=v_p.id and r.estado='confirmado')
    and not exists(select 1 from public.campeonato_fases f where f.id=v_p.fase_id and f.estado='finalizada')
    into v_editable from public.campeonatos c where c.id=v_p.campeonato_id;
  return jsonb_build_object(
    'editable',false,
    'partido',jsonb_build_object('id',v_p.id,'fecha_hora',v_p.fecha_hora,'cancha',v_p.cancha,
      'equipo_local_id',v_p.equipo_local_id,'equipo_visitante_id',v_p.equipo_visitante_id,
      'local',(select nombre from public.equipos where id=v_p.equipo_local_id),
      'visitante',(select nombre from public.equipos where id=v_p.equipo_visitante_id)),
    'jugadores',coalesce((select jsonb_agg(jsonb_build_object(
      'id',cj.id,'equipo_id',cj.equipo_id,'nombres',j.nombres,'apellidos',j.apellidos,
      'camiseta',coalesce(j.num_camiseta,j.numero_camiseta,j.dorsal),
      'foto_url',coalesce(nullif(j.foto_url,''),j.foto_perfil_url),
      'habilitado',cj.estado='inscrito' and ce.estado='inscrito' and j.estado='Calificado'
    ) order by cj.equipo_id,j.apellidos,j.nombres,cj.id)
    from public.campeonato_jugadores cj
    join public.jugadores j on j.id=cj.jugador_id
    join public.campeonato_equipos ce on ce.campeonato_id=cj.campeonato_id and ce.equipo_id=cj.equipo_id
    where cj.campeonato_id=v_p.campeonato_id and cj.equipo_id in(v_p.equipo_local_id,v_p.equipo_visitante_id)), '[]'::jsonb),
    'borrador',(select jsonb_build_object('vocal',b.vocal,'arbitro',b.arbitro,'jugadores',b.jugadores,'version',b.version,'controles_equipo',b.controles_equipo,'informe_arbitral',b.informe_arbitral,'informe_vocal',b.informe_vocal,'firmas',b.firmas)
      from public.lm_vocal_borradores b where b.partido_id=v_p.id)
  );
end; $$;
revoke all on function public.lm_hoja_vocalia_leer(uuid) from public,anon,authenticated;
grant execute on function public.lm_hoja_vocalia_leer(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
