-- Solo añade Balón, Capitán y Camerinos a la planilla del vocal.
begin;
alter table public.lm_vocal_borradores
  add column if not exists controles_equipo jsonb not null default '{}'::jsonb;

create or replace function public.lm_vocal_leer_planilla_controles(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_d jsonb; v_controles jsonb;
begin
  -- Conserva la validación y los datos de la consulta existente.
  v_d := public.lm_vocal_leer_partido(p_partido_id);
  select controles_equipo into v_controles from public.lm_vocal_borradores
    where partido_id=p_partido_id;
  return jsonb_set(v_d,'{borrador}',
    coalesce(nullif(v_d->'borrador','null'::jsonb),'{}'::jsonb)
      || jsonb_build_object('controles_equipo',coalesce(v_controles,'{}'::jsonb)));
end; $$;

create or replace function public.lm_vocal_guardar_planilla_controles(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,
  p_version integer,p_controles jsonb,p_finalizar boolean
)
returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_equipo text; v_valores jsonb;
  v_clave text; v_valor jsonb; v_version integer;
begin
  if not coalesce(public.lm_es_vocal(),false) then
    raise exception 'Se requiere una cuenta de vocal activa.';
  end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido no existe.'; end if;
  if p_controles is null or jsonb_typeof(p_controles)<>'object' then
    raise exception 'Los controles de los equipos no son válidos.';
  end if;
  for v_equipo,v_valores in select key,value from jsonb_each(p_controles) loop
    if v_equipo not in (v_p.equipo_local_id::text,v_p.equipo_visitante_id::text)
      or jsonb_typeof(v_valores)<>'object' then
      raise exception 'Los controles no corresponden a los equipos del partido.';
    end if;
    for v_clave,v_valor in select key,value from jsonb_each(v_valores) loop
      if v_clave not in ('balon','capitan','camerinos') or jsonb_typeof(v_valor)<>'boolean' then
        raise exception 'Marca únicamente Balón, Capitán y Camerinos.';
      end if;
    end loop;
  end loop;
  -- Reutiliza el guardado, control de versión y publicación existentes.
  if coalesce(p_finalizar,false) then
    v_version := public.lm_vocal_finalizar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
  else
    v_version := public.lm_vocal_guardar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
  end if;
  update public.lm_vocal_borradores set controles_equipo=p_controles
    where partido_id=p_partido_id;
  return v_version;
end; $$;

revoke all on function public.lm_vocal_leer_planilla_controles(uuid),
  public.lm_vocal_guardar_planilla_controles(uuid,text,text,jsonb,integer,jsonb,boolean)
from public,anon,authenticated;
grant execute on function public.lm_vocal_leer_planilla_controles(uuid),
  public.lm_vocal_guardar_planilla_controles(uuid,text,text,jsonb,integer,jsonb,boolean)
to authenticated;
notify pgrst, 'reload schema';
commit;
