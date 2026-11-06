-- Consulta de partidos desde Penas. La comisión solo consulta; no se modifica el RPC de corrección.
begin;
create or replace function public.lm_penas_conteo_jugadores(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_campeonato uuid; v_liga uuid; v_conteos jsonb; v_editar boolean;
begin
  select c.id,c.liga_id into v_campeonato,v_liga
  from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
  where p.id=p_partido_id;
  if not found then raise exception 'El partido no existe.'; end if;
  if not coalesce(public.lm_penas_puede_gestionar(p_partido_id), false) then
    raise exception 'No tienes permiso para consultar los partidos de esta hoja.';
  end if;
  v_editar := coalesce(public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text), false);
  v_conteos := coalesce((
    select jsonb_object_agg(cj.id::text,jsonb_build_object(
      'total',greatest(0,jsonb_array_length(coalesce(historial.partidos,'[]'::jsonb))+coalesce(aj.ajuste,0)),
      'automatico',jsonb_array_length(coalesce(historial.partidos,'[]'::jsonb)),
      'ajuste',coalesce(aj.ajuste,0),
      'partidos',coalesce(historial.partidos,'[]'::jsonb)))
    from public.campeonato_jugadores cj
    left join lateral (
      select jsonb_agg(jsonb_build_object('id',p.id,'jornada',p.jornada,
        'numero_partido',p.numero_partido,'local',el.nombre,'visitante',ev.nombre)
        order by p.jornada,p.numero_partido,p.id) as partidos
      from public.campeonato_partidos p
      join public.equipos el on el.id=p.equipo_local_id
      join public.equipos ev on ev.id=p.equipo_visitante_id
      where p.campeonato_id=v_campeonato
        and exists(select 1 from public.campeonato_resultados r
          where r.partido_id=p.id and r.estado='confirmado')
        and exists(select 1 from public.campeonato_planillas pl
          where pl.partido_id=p.id and pl.inscripcion_jugador_id=cj.id and pl.participo=true)
    ) historial on true
    left join public.lm_ajustes_conteo_jugador aj on aj.inscripcion_id=cj.id
    where cj.campeonato_id=v_campeonato and exists (select 1 from public.campeonato_partidos hoja where hoja.id=p_partido_id and cj.equipo_id in (hoja.equipo_local_id,hoja.equipo_visitante_id))
  ),'{}'::jsonb);
  return jsonb_build_object('puede_editar',v_editar,'conteos',v_conteos,
    'disciplina',coalesce((
      select jsonb_object_agg(s->>'inscripcion_jugador_id',s)
      from jsonb_array_elements(public.lm_penas_calcular(v_campeonato)) s
      where v_conteos ? (s->>'inscripcion_jugador_id')
    ),'{}'::jsonb));
end; $$;

revoke all on function public.lm_penas_conteo_jugadores(uuid) from public,anon,authenticated;
grant execute on function public.lm_penas_conteo_jugadores(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
