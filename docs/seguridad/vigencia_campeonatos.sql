-- Ejecutar completo en Supabase SQL Editor. No cambia fechas existentes.
begin;
create or replace function public.lm_campeonatos_vigencia_equipo(p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_liga uuid;
begin
  select e.liga_id into v_liga from public.equipos e
  where e.id=p_equipo_id and auth.uid() is not null
    and (e.delegado_id=auth.uid() or public.lm_es_superadmin()
      or public.lm_administra_liga(e.liga_id::text));
  if not found then raise exception 'No tienes acceso a este equipo.'; end if;
  return coalesce((select jsonb_agg(to_jsonb(c) order by c.nombre,c.categoria)
    from public.campeonatos c where c.liga_id=v_liga), '[]'::jsonb);
end; $$;
revoke all on function public.lm_campeonatos_vigencia_equipo(bigint) from public,anon,authenticated;
grant execute on function public.lm_campeonatos_vigencia_equipo(bigint) to authenticated;

create or replace function public.lm_configurar_fechas_campeonato(
  p_campeonato_id uuid,p_inicio date,p_fin date
) returns void language plpgsql security definer set search_path='' as $$
declare v_c public.campeonatos%rowtype; v_grupo uuid;
begin
  select * into v_c from public.campeonatos where id=p_campeonato_id;
  if not found then raise exception 'El campeonato no existe.'; end if;
  if auth.uid() is null or not coalesce((public.lm_es_superadmin() or public.lm_administra_liga(v_c.liga_id::text)),false) then
    raise exception 'Solo el administrador de la liga puede configurar estas fechas.';
  end if;
  if p_inicio is null or p_fin is null or p_fin<p_inicio then
    raise exception 'Selecciona fechas válidas de inicio y fin.';
  end if;
  -- Serializa la configuración para impedir dos altas simultáneas incompatibles.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_c.liga_id::text,0));
  v_grupo:=coalesce(v_c.grupo_campeonato_id,v_c.id);
  if exists(select 1 from public.campeonatos c
    where c.liga_id=v_c.liga_id and coalesce(c.grupo_campeonato_id,c.id)<>v_grupo
      and c.estado not in ('finalizado','archivado')
      and c.fecha_inicio<=p_fin and c.fecha_fin>=p_inicio) then
    raise exception 'Estas fechas coinciden con otro campeonato de la misma liga.';
  end if;
  -- Las cuatro categorías del mismo campeonato comparten su vigencia.
  update public.campeonatos set fecha_inicio=p_inicio,fecha_fin=p_fin
    where liga_id=v_c.liga_id and coalesce(grupo_campeonato_id,id)=v_grupo;
end; $$;
revoke all on function public.lm_configurar_fechas_campeonato(uuid,date,date) from public,anon,authenticated;
grant execute on function public.lm_configurar_fechas_campeonato(uuid,date,date) to authenticated;
create or replace function public.lm_vocal_partidos(p_fecha date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not coalesce(public.lm_es_vocal(),false) then
    raise exception 'Esta consulta requiere una cuenta de vocal activa.';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id',p.id,'fecha_hora',p.fecha_hora,'cancha',coalesce(p.cancha,'Sin cancha'),
    'local',el.nombre,'visitante',ev.nombre,'equipo_local_id',p.equipo_local_id,
    'equipo_visitante_id',p.equipo_visitante_id,'campeonato',c.nombre,
    'categoria',c.categoria,'liga',l.nombre
  ) order by p.fecha_hora,p.id)
  from public.campeonato_partidos p
  join public.campeonatos c on c.id=p.campeonato_id
  join public.ligas l on l.id=c.liga_id
  join public.equipos el on el.id=p.equipo_local_id
  join public.equipos ev on ev.id=p.equipo_visitante_id
  where (p.fecha_hora at time zone 'America/Guayaquil')::date=p_fecha
    and p.estado='programado'
    and c.estado not in ('finalizado','archivado')
    and c.fecha_inicio <= p_fecha and c.fecha_fin >= p_fecha
  ),'[]'::jsonb);
end; $$;
notify pgrst, 'reload schema';
commit;
