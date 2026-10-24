-- Módulo independiente. No modifica perfiles, permisos del administrador,
-- nombres de revisores/calificadores ni políticas existentes.
-- Instalar junto al complemento de escritura una vez revisadas las funciones
-- lm_revisar_jugador y lm_calificar_jugador de la base actual.
begin;

create table if not exists public.lm_comision_calificaciones (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  activo boolean not null default true
);
alter table public.lm_comision_calificaciones enable row level security;
revoke all on public.lm_comision_calificaciones from public, anon, authenticated;

create or replace function public.lm_es_comision_calificaciones()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.lm_comision_calificaciones a
    where a.usuario_id=auth.uid() and a.activo
  );
$$;

create or replace function public.lm_comision_equipo_permitido(
  p_campeonato_id uuid, p_equipo_id bigint
) returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.lm_comision_calificaciones a
    cross join public.campeonatos c
    join public.campeonato_equipos ce on ce.campeonato_id=c.id
    join public.equipos e on e.id=ce.equipo_id and e.liga_id::text=c.liga_id::text
    where a.usuario_id=auth.uid() and a.activo
      and c.id=p_campeonato_id and c.activo=true
      and ce.equipo_id=p_equipo_id and ce.estado='inscrito'
  );
$$;

create or replace function public.lm_comision_equipos()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.lm_es_comision_calificaciones() then
    raise exception 'La cuenta no tiene una comisión de calificaciones activa.';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'campeonato_id',c.id,'campeonato',c.nombre,'categoria',c.categoria,'activo',c.activo,
    'liga',l.nombre,'equipo_id',e.id,'equipo',e.nombre,
    'escudo_url',to_jsonb(e)->>'escudo_url','logo_url',to_jsonb(e)->>'logo_url'
  ) order by c.nombre,c.categoria,e.nombre)
    from public.lm_comision_calificaciones a
    cross join public.campeonatos c
    join public.ligas l on l.id::text=c.liga_id::text
    join public.campeonato_equipos ce on ce.campeonato_id=c.id and ce.estado='inscrito'
    join public.equipos e on e.id=ce.equipo_id and e.liga_id::text=c.liga_id::text
    where a.usuario_id=auth.uid() and a.activo and c.activo=true),'[]'::jsonb);
end;
$$;

create or replace function public.lm_comision_jugadores(
  p_campeonato_id uuid, p_equipo_id bigint
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.lm_comision_equipo_permitido(p_campeonato_id,p_equipo_id) then
    raise exception 'No tienes acceso a este equipo en este campeonato.';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(j) order by j.apellidos,j.nombres,j.id)
    from public.jugadores j
    join public.campeonatos c on c.id=p_campeonato_id
    where j.equipo_id=p_equipo_id and j.categoria=c.categoria
      and exists(select 1 from public.campeonato_jugadores cj
        where cj.campeonato_id=c.id and cj.equipo_id=j.equipo_id
          and cj.jugador_id=j.id and cj.estado='inscrito')),'[]'::jsonb);
end;
$$;

revoke all on function public.lm_es_comision_calificaciones() from public,anon,authenticated;
revoke all on function public.lm_comision_equipo_permitido(uuid,bigint) from public,anon,authenticated;
revoke all on function public.lm_comision_equipos() from public,anon,authenticated;
revoke all on function public.lm_comision_jugadores(uuid,bigint) from public,anon,authenticated;
grant execute on function public.lm_es_comision_calificaciones() to authenticated;
grant execute on function public.lm_comision_equipos() to authenticated;
grant execute on function public.lm_comision_jugadores(uuid,bigint) to authenticated;
commit;
