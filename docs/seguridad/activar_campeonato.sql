-- Ejecutar después de vigencia_campeonatos.sql. No activa campeonatos automáticamente.
begin;
alter table public.campeonatos add column if not exists activo boolean not null default false;
create or replace function public.lm_activar_campeonato(p_campeonato_id uuid,p_activo boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_c public.campeonatos%rowtype; v_grupo uuid;
begin
  select * into v_c from public.campeonatos where id=p_campeonato_id;
  if not found then raise exception 'El campeonato no existe.'; end if;
  if auth.uid() is null or not coalesce((public.lm_es_superadmin() or public.lm_administra_liga(v_c.liga_id::text)),false) then
    raise exception 'Solo el administrador de esta liga puede activar el campeonato.';
  end if;
  if p_activo is null then raise exception 'Selecciona activar o desactivar.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_c.liga_id::text,0));
  -- Relee después de obtener el bloqueo de la liga.
  select * into v_c from public.campeonatos where id=p_campeonato_id;
  v_grupo:=coalesce(v_c.grupo_campeonato_id,v_c.id);
  if p_activo and v_c.estado in ('finalizado','archivado') then
    raise exception 'No se puede activar un campeonato finalizado o archivado.';
  end if;
  if p_activo and (v_c.fecha_inicio is null or v_c.fecha_fin is null) then
    raise exception 'Configura primero las fechas de inicio y fin del campeonato.';
  end if;
  if p_activo then
    update public.campeonatos set activo=false where liga_id=v_c.liga_id and activo=true;
  end if;
  update public.campeonatos set activo=p_activo
    where liga_id=v_c.liga_id and coalesce(grupo_campeonato_id,id)=v_grupo;
end; $$;
revoke all on function public.lm_activar_campeonato(uuid,boolean) from public,anon,authenticated;
grant execute on function public.lm_activar_campeonato(uuid,boolean) to authenticated;
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
    and c.activo=true
    and c.estado not in ('finalizado','archivado')
    and c.fecha_inicio <= p_fecha and c.fecha_fin >= p_fecha
  ),'[]'::jsonb);
end; $$;
notify pgrst, 'reload schema';
commit;
