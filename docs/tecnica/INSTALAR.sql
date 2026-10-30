-- Cuenta exclusiva: tecnica2027@ligamaster.invalid (crear en Authentication).
-- No modifica funciones, políticas ni permisos existentes del administrador.
begin;
create table if not exists public.lm_comision_tecnica (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  activo boolean not null default true
);
alter table public.lm_comision_tecnica enable row level security;
revoke all on public.lm_comision_tecnica from public,anon,authenticated;
alter table public.campeonato_partidos add column if not exists equipo_vocal_id bigint references public.equipos(id);

create or replace function public.lm_es_comision_tecnica()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.lm_comision_tecnica where usuario_id=auth.uid() and activo);
$$;

create or replace function public.lm_tecnica_catalogo()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.lm_es_comision_tecnica() then raise exception 'No tienes acceso a la comisión técnica.'; end if;
  return jsonb_build_object(
    'campeonatos',coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('liga',l.nombre) order by l.nombre,c.nombre,c.categoria)
      from public.campeonatos c join public.ligas l on l.id::text=c.liga_id::text where c.activo=true),'[]'::jsonb),
    'fases',coalesce((select jsonb_agg(to_jsonb(f) order by f.orden) from public.campeonato_fases f join public.campeonatos c on c.id=f.campeonato_id where c.activo=true and f.estado<>'finalizada'),'[]'::jsonb),
    'grupos',coalesce((select jsonb_agg(to_jsonb(g)) from public.campeonato_grupos g join public.campeonato_fases f on f.id=g.fase_id join public.campeonatos c on c.id=f.campeonato_id where c.activo=true),'[]'::jsonb),
    'equipos',coalesce((select jsonb_agg(jsonb_build_object('campeonato_id',ce.campeonato_id,'equipo_id',e.id,'nombre',e.nombre) order by e.nombre)
      from public.campeonato_equipos ce join public.campeonatos c on c.id=ce.campeonato_id join public.equipos e on e.id=ce.equipo_id and e.liga_id::text=c.liga_id::text where c.activo=true and ce.estado='inscrito'),'[]'::jsonb),
    'partidos',coalesce((select jsonb_agg(to_jsonb(p)||jsonb_build_object('local',el.nombre,'visitante',ev.nombre,'equipo_vocal',v.nombre,
      'confirmado',exists(select 1 from public.campeonato_resultados r where r.partido_id=p.id and r.estado='confirmado')) order by p.fecha_hora,p.jornada,p.numero_partido)
      from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id join public.equipos el on el.id=p.equipo_local_id join public.equipos ev on ev.id=p.equipo_visitante_id left join public.equipos v on v.id=p.equipo_vocal_id where c.activo=true),'[]'::jsonb)
  );
end;
$$;

-- Conserva las validaciones de la función de programación facilitada por el usuario.
-- La comisión solo puede programar/asignar turnos; no confirma, borra ni cancela.
create or replace function public.lm_tecnica_guardar_partido(
 p_fase uuid,p_grupo uuid,p_local bigint,p_visitante bigint,p_jornada integer,
 p_fecha timestamptz,p_cancha text,p_vocal bigint,p_partido uuid default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare f public.campeonato_fases%rowtype; p public.campeonato_partidos%rowtype; resultado uuid; numero integer; es_tecnica boolean;
begin
  if auth.uid() is null then raise exception 'Inicia sesión.'; end if;
  select * into f from public.campeonato_fases where id=p_fase;
  if not found then raise exception 'La fase no existe.'; end if;
  es_tecnica:=public.lm_es_comision_tecnica();
  if not es_tecnica then perform public.lm_fixture_autorizar(f.campeonato_id); end if;
  -- Serializar creación y cambios de programación igual que el fixture actual.
  select * into f from public.campeonato_fases where id=p_fase for update;
  perform 1 from public.campeonatos where id=f.campeonato_id and activo=true and estado not in ('finalizado','archivado') for share;
  if not found then raise exception 'El campeonato debe estar activo.'; end if;
  if f.estado='finalizada' then raise exception 'La fase está finalizada.'; end if;
  if p_local is null or p_visitante is null or p_local=p_visitante then raise exception 'Selecciona dos equipos diferentes.'; end if;
  if p_jornada is null or p_jornada<1 then raise exception 'La jornada debe ser mayor que cero.'; end if;
  if p_fecha is null then raise exception 'Selecciona fecha y horario.'; end if;
  if p_cancha is null or p_cancha not in ('CANCHA 1','CANCHA 2','CANCHA SUB 12') then raise exception 'Selecciona una cancha válida.'; end if;
  if (f.tipo='grupos')<>(p_grupo is not null) then raise exception 'Selecciona el grupo correspondiente a esta fase.'; end if;
  if p_grupo is not null and not exists(select 1 from public.campeonato_grupos where id=p_grupo and fase_id=p_fase) then raise exception 'El grupo no pertenece a esta fase.'; end if;
  if p_partido is not null then
    select * into p from public.campeonato_partidos where id=p_partido and fase_id=p_fase for update;
    if not found then raise exception 'El partido no pertenece a esta fase.'; end if;
    if (p.equipo_local_id,p.equipo_visitante_id,p.grupo_id) is distinct from (p_local,p_visitante,p_grupo) then raise exception 'En un partido existente solo se modifica la programación.'; end if;
    if p.estado not in ('programado','aplazado') then raise exception 'Este partido ya no admite programación.'; end if;
    if exists(select 1 from public.campeonato_resultados where partido_id=p_partido and estado='confirmado') then raise exception 'El resultado está confirmado.'; end if;
  end if;
  perform 1 from public.campeonato_equipos where campeonato_id=f.campeonato_id and equipo_id in (p_local,p_visitante,p_vocal) for share;
  if (select count(*) from public.campeonato_equipos where campeonato_id=f.campeonato_id and equipo_id in (p_local,p_visitante) and estado='inscrito')<>2 then raise exception 'Ambos equipos deben estar inscritos en esta categoría.'; end if;
  if p_vocal is null or not exists(select 1 from public.campeonato_equipos ce join public.equipos e on e.id=ce.equipo_id join public.campeonatos c on c.id=ce.campeonato_id where ce.campeonato_id=f.campeonato_id and ce.equipo_id=p_vocal and ce.estado='inscrito' and e.liga_id::text=c.liga_id::text) then raise exception 'Selecciona un equipo inscrito para la vocalía.'; end if;
  if p_grupo is not null and (select count(*) from public.campeonato_grupo_equipos where grupo_id=p_grupo and equipo_id in (p_local,p_visitante))<>2 then raise exception 'Ambos equipos deben pertenecer al grupo.'; end if;
  if p_partido is null then
    select coalesce(max(numero_partido),0)+1 into numero from public.campeonato_partidos where fase_id=p_fase;
    insert into public.campeonato_partidos(campeonato_id,fase_id,grupo_id,equipo_local_id,equipo_visitante_id,jornada,numero_partido,fecha_hora,cancha,estado,equipo_vocal_id)
    values(f.campeonato_id,p_fase,p_grupo,p_local,p_visitante,p_jornada,numero,p_fecha,p_cancha,'programado',p_vocal) returning id into resultado;
  else
    update public.campeonato_partidos set jornada=p_jornada,fecha_hora=p_fecha,cancha=p_cancha,equipo_vocal_id=p_vocal where id=p_partido;
    resultado:=p_partido;
  end if;
  return resultado;
end;
$$;
create or replace function public.lm_turno_vocalia(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not (coalesce(public.lm_es_vocal(),false) or exists(
    select 1 from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
    where p.id=p_partido_id and coalesce(public.lm_es_superadmin() or public.lm_administra_liga(c.liga_id::text),false)
  )) then raise exception 'No tienes acceso al turno de vocalía.'; end if;
  return (select jsonb_build_object('equipo',e.nombre) from public.campeonato_partidos p join public.equipos e on e.id=p.equipo_vocal_id where p.id=p_partido_id);
end;
$$;
revoke all on function public.lm_es_comision_tecnica(),public.lm_tecnica_catalogo(),public.lm_tecnica_guardar_partido(uuid,uuid,bigint,bigint,integer,timestamptz,text,bigint,uuid),public.lm_turno_vocalia(uuid) from public,anon,authenticated;
grant execute on function public.lm_es_comision_tecnica(),public.lm_tecnica_catalogo(),public.lm_tecnica_guardar_partido(uuid,uuid,bigint,bigint,integer,timestamptz,text,bigint,uuid),public.lm_turno_vocalia(uuid) to authenticated;
commit;
