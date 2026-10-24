-- Ajuste del conteo mostrado. No modifica planillas, resultados ni sanciones.
begin;
create table if not exists public.lm_ajustes_conteo_jugador (
  inscripcion_id uuid primary key references public.campeonato_jugadores(id) on delete restrict,
  ajuste integer not null,
  motivo text not null,
  actualizado_por uuid not null,
  actualizado_en timestamptz not null default now()
);
create table if not exists public.lm_historial_conteo_jugador (
  id bigint generated always as identity primary key,
  inscripcion_id uuid not null,
  automatico integer not null,
  ajuste integer not null,
  motivo text not null,
  usuario_id uuid not null,
  creado_en timestamptz not null default now()
);
alter table public.lm_ajustes_conteo_jugador enable row level security;
alter table public.lm_historial_conteo_jugador enable row level security;
revoke all on public.lm_ajustes_conteo_jugador,public.lm_historial_conteo_jugador from public,anon,authenticated;
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
    where cj.campeonato_id=v_campeonato
  ),'{}'::jsonb);
end; $$;
create or replace function public.lm_corregir_conteo_jugador(
  p_inscripcion_id uuid,p_total integer,p_ajuste_anterior integer,p_motivo text
) returns void language plpgsql security definer set search_path='' as $$
declare v_campeonato uuid; v_liga uuid; v_auto integer; v_ajuste integer; v_anterior integer;
begin
  select cj.campeonato_id,c.liga_id into v_campeonato,v_liga
    from public.campeonato_jugadores cj join public.campeonatos c on c.id=cj.campeonato_id
    where cj.id=p_inscripcion_id for update of cj;
  if not found then raise exception 'La inscripción del jugador no existe.'; end if;
  if auth.uid() is null or not coalesce(public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text),false)
    then raise exception 'Solo el administrador de esta liga puede corregir el conteo.'; end if;
  if p_total is not null and p_total not between 0 and 10000 then raise exception 'Ingresa un total entre 0 y 10000.'; end if;
  if length(trim(coalesce(p_motivo,''))) not between 1 and 300 then raise exception 'Escribe el motivo de la corrección.'; end if;
  select ajuste into v_anterior from public.lm_ajustes_conteo_jugador where inscripcion_id=p_inscripcion_id;
  if p_ajuste_anterior is distinct from coalesce(v_anterior,0) then raise exception 'El conteo fue corregido en otra sesión. Cierra el detalle y actualiza antes de editar.'; end if;
  select count(*)::integer into v_auto from public.campeonato_partidos p
    where p.campeonato_id=v_campeonato
      and exists(select 1 from public.campeonato_resultados r where r.partido_id=p.id and r.estado='confirmado')
      and exists(select 1 from public.campeonato_planillas pl where pl.partido_id=p.id
        and pl.inscripcion_jugador_id=p_inscripcion_id and pl.participo=true);
  v_ajuste:=case when p_total is null then 0 else p_total-v_auto end;
  insert into public.lm_ajustes_conteo_jugador(inscripcion_id,ajuste,motivo,actualizado_por)
    values(p_inscripcion_id,v_ajuste,trim(p_motivo),auth.uid())
    on conflict(inscripcion_id) do update set ajuste=excluded.ajuste,motivo=excluded.motivo,
      actualizado_por=auth.uid(),actualizado_en=now();
  insert into public.lm_historial_conteo_jugador(inscripcion_id,automatico,ajuste,motivo,usuario_id)
    values(p_inscripcion_id,v_auto,v_ajuste,trim(p_motivo),auth.uid());
end; $$;
revoke all on function public.lm_corregir_conteo_jugador(uuid,integer,integer,text) from public,anon,authenticated;
grant execute on function public.lm_corregir_conteo_jugador(uuid,integer,integer,text) to authenticated;
-- Garantiza el acceso de lectura también al instalar este script directamente.
revoke all on function public.lm_conteo_partidos_jugadores(uuid) from public,anon,authenticated;
grant execute on function public.lm_conteo_partidos_jugadores(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
