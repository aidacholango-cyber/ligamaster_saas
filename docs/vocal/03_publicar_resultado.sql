begin;
alter table public.lm_vocal_borradores add column if not exists publicado_en timestamptz;

create or replace function public.lm_vocal_finalizar(
  p_partido_id uuid, p_vocal text, p_arbitro text, p_jugadores jsonb, p_version integer
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_version integer;
  v_local integer; v_visitante integer;
begin
  if not coalesce(public.lm_es_vocal(),false) then raise exception 'Se requiere una cuenta de vocal activa.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido no existe.'; end if;
  -- No sobrescribir trabajo oficial preparado por el administrador.
  if exists(select 1 from public.campeonato_resultados where partido_id=p_partido_id)
    or exists(select 1 from public.campeonato_planillas where partido_id=p_partido_id)
  then raise exception 'El partido ya tiene una planilla oficial. El administrador debe revisar esa acta; no se sobrescribieron sus datos.'; end if;
  -- Valida cuenta, versión, partido abierto, inscripción y tarjetas antes de publicar.
  v_version:=public.lm_vocal_guardar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
  if not exists(select 1 from jsonb_array_elements(p_jugadores) x
    join public.campeonato_jugadores cj on cj.id=(x->>'id')::uuid where cj.equipo_id=v_p.equipo_local_id)
    or not exists(select 1 from jsonb_array_elements(p_jugadores) x
    join public.campeonato_jugadores cj on cj.id=(x->>'id')::uuid where cj.equipo_id=v_p.equipo_visitante_id)
  then raise exception 'Ingresa los jugadores que participaron de ambos equipos.'; end if;
  insert into public.campeonato_planillas(
    campeonato_id,partido_id,inscripcion_jugador_id,equipo_id,participo,goles,autogoles,amarillas,roja_directa
  ) select v_p.campeonato_id,v_p.id,cj.id,cj.equipo_id,true,(x->>'goles')::integer,0,
    (x->>'ta')::integer,(x->>'tr')::boolean
  from jsonb_array_elements(p_jugadores) x join public.campeonato_jugadores cj on cj.id=(x->>'id')::uuid;
  select coalesce(sum(goles) filter(where equipo_id=v_p.equipo_local_id),0),
    coalesce(sum(goles) filter(where equipo_id=v_p.equipo_visitante_id),0)
    into v_local,v_visitante from public.campeonato_planillas where partido_id=v_p.id;
  insert into public.campeonato_resultados(partido_id,goles_local,goles_visitante,estado)
    values(v_p.id,v_local,v_visitante,'borrador');
  -- Ejecuta las validaciones actuales de confirmación, sin deshabilitar triggers.
  perform public.lm_confirmar_resultado(v_p.id);
  update public.lm_vocal_borradores set publicado_en=now() where partido_id=v_p.id;
  return v_version;
end; $$;
revoke all on function public.lm_vocal_finalizar(uuid,text,text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.lm_vocal_finalizar(uuid,text,text,jsonb,integer) to authenticated;
commit;
select to_regprocedure('public.lm_vocal_finalizar(uuid,text,text,jsonb,integer)') is not null as cierre_vocal_instalado;
