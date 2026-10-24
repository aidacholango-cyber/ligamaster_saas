-- Conteo de solo lectura: no cambia participaciones ni resultados existentes.
begin;
create or replace function public.lm_conteo_partidos_jugadores(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_campeonato uuid; v_liga uuid;
begin
  select c.id,c.liga_id into v_campeonato,v_liga
  from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
  where p.id=p_partido_id;
  if not found then raise exception 'El partido no existe.'; end if;
  if auth.uid() is null or not coalesce(
    public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text),false
  ) then raise exception 'Solo el administrador de esta liga puede consultar este conteo.'; end if;

  return coalesce((
    select jsonb_object_agg(cj.id::text,jsonb_build_object(
      'total',jsonb_array_length(coalesce(historial.partidos,'[]'::jsonb)),
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
    where cj.campeonato_id=v_campeonato
  ),'{}'::jsonb);
end; $$;
revoke all on function public.lm_conteo_partidos_jugadores(uuid) from public,anon,authenticated;
grant execute on function public.lm_conteo_partidos_jugadores(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
