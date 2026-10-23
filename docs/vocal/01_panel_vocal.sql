begin;

-- Módulo independiente: no cambia las políticas de jugadores ni las actas oficiales.
create table if not exists public.lm_vocales (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  activo boolean not null default true
);
create table if not exists public.lm_vocal_borradores (
  partido_id uuid primary key references public.campeonato_partidos(id),
  vocal text not null,
  arbitro text not null,
  jugadores jsonb not null default '[]'::jsonb,
  version integer not null default 1,
  actualizado_por uuid not null references auth.users(id),
  actualizado_en timestamptz not null default now()
);
alter table public.lm_vocales enable row level security;
alter table public.lm_vocal_borradores enable row level security;
revoke all on public.lm_vocales, public.lm_vocal_borradores from public, anon, authenticated;

create or replace function public.lm_es_vocal()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1 from public.lm_vocales where usuario_id=auth.uid() and activo
  );
$$;

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
  ),'[]'::jsonb);
end; $$;

create or replace function public.lm_vocal_leer_partido(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_editable boolean;
begin
  if not coalesce(public.lm_es_vocal(),false) then raise exception 'Se requiere una cuenta de vocal activa.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id;
  if not found then raise exception 'El partido ya no existe.'; end if;
  select v_p.estado='programado' and c.estado not in ('finalizado','archivado')
    and not exists(select 1 from public.campeonato_resultados r where r.partido_id=v_p.id and r.estado='confirmado')
    and not exists(select 1 from public.campeonato_fases f where f.id=v_p.fase_id and f.estado='finalizada')
    into v_editable from public.campeonatos c where c.id=v_p.campeonato_id;
  return jsonb_build_object(
    'editable',coalesce(v_editable,false),
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
    'borrador',(select jsonb_build_object('vocal',b.vocal,'arbitro',b.arbitro,'jugadores',b.jugadores,'version',b.version)
      from public.lm_vocal_borradores b where b.partido_id=v_p.id)
  );
end; $$;

create or replace function public.lm_vocal_guardar(
  p_partido_id uuid, p_vocal text, p_arbitro text, p_jugadores jsonb, p_version integer
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_actual integer; v_item jsonb;
  v_id uuid; v_ta integer; v_goles integer; v_tr boolean; v_ids uuid[]:='{}'; v_filas jsonb:='[]';
begin
  if not coalesce(public.lm_es_vocal(),false) then raise exception 'Se requiere una cuenta de vocal activa.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido ya no existe.'; end if;
  if v_p.estado<>'programado'
    or exists(select 1 from public.campeonatos where id=v_p.campeonato_id and estado in('finalizado','archivado'))
    or exists(select 1 from public.campeonato_fases where id=v_p.fase_id and estado='finalizada')
    or exists(select 1 from public.campeonato_resultados where partido_id=v_p.id and estado='confirmado')
  then raise exception 'El partido está cerrado y no admite cambios del vocal.'; end if;
  if coalesce(length(trim(p_vocal)),0) not between 1 and 150 or coalesce(length(trim(p_arbitro)),0) not between 1 and 150
    then raise exception 'Escribe los nombres del vocal y del árbitro (máximo 150 caracteres).'; end if;
  if p_jugadores is null or jsonb_typeof(p_jugadores)<>'array' then raise exception 'La lista de jugadores no es válida.'; end if;
  if jsonb_array_length(p_jugadores)>100 then raise exception 'La planilla supera el límite de 100 jugadores.'; end if;
  select version into v_actual from public.lm_vocal_borradores where partido_id=v_p.id;
  if p_version is distinct from coalesce(v_actual,0) then raise exception 'Otro vocal guardó cambios. Vuelve a abrir el partido para cargar la versión actual.'; end if;
  for v_item in select value from jsonb_array_elements(p_jugadores) loop
    if coalesce(v_item->>'ta','') !~ '^[0-2]$' or coalesce(v_item->>'goles','') !~ '^[0-9]{1,2}$'
      or jsonb_typeof(v_item->'tr') is distinct from 'boolean' then raise exception 'Revisa las tarjetas y los goles.'; end if;
    v_id:=(v_item->>'id')::uuid; v_ta:=(v_item->>'ta')::integer;
    v_goles:=(v_item->>'goles')::integer; v_tr:=(v_item->>'tr')::boolean;
    if v_id=any(v_ids) then raise exception 'Hay un jugador repetido.'; end if;
    if not exists(select 1 from public.campeonato_jugadores cj
      join public.jugadores j on j.id=cj.jugador_id
      join public.campeonato_equipos ce on ce.campeonato_id=cj.campeonato_id and ce.equipo_id=cj.equipo_id
      where cj.id=v_id and cj.campeonato_id=v_p.campeonato_id
        and cj.equipo_id in(v_p.equipo_local_id,v_p.equipo_visitante_id)
        and cj.estado='inscrito' and ce.estado='inscrito' and j.estado='Calificado')
    then raise exception 'Un jugador no está inscrito y calificado para este partido.'; end if;
    v_ids:=array_append(v_ids,v_id);
    v_filas:=v_filas||jsonb_build_array(jsonb_build_object('id',v_id,'ta',v_ta,'tr',v_tr,'goles',v_goles));
  end loop;
  insert into public.lm_vocal_borradores(partido_id,vocal,arbitro,jugadores,version,actualizado_por)
    values(v_p.id,trim(p_vocal),trim(p_arbitro),v_filas,1,auth.uid())
  on conflict(partido_id) do update set vocal=excluded.vocal,arbitro=excluded.arbitro,
    jugadores=excluded.jugadores,version=public.lm_vocal_borradores.version+1,
    actualizado_por=auth.uid(),actualizado_en=now()
  returning version into v_actual;
  return v_actual;
end; $$;

revoke all on function public.lm_es_vocal(),public.lm_vocal_partidos(date),public.lm_vocal_leer_partido(uuid),public.lm_vocal_guardar(uuid,text,text,jsonb,integer) from public, anon, authenticated;
grant execute on function public.lm_es_vocal(),public.lm_vocal_partidos(date),public.lm_vocal_leer_partido(uuid),public.lm_vocal_guardar(uuid,text,text,jsonb,integer) to authenticated;
commit;
select to_regprocedure('public.lm_vocal_guardar(uuid,text,text,jsonb,integer)') is not null as panel_vocal_instalado;
