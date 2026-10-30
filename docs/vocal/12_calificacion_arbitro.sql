-- Una sola calificación del árbitro por partido, registrada por el vocal.
-- Requiere 11_regla_juvenil.sql y los módulos de firmas existentes.
begin;
alter table public.lm_vocal_borradores
  add column if not exists calificacion_arbitro text
    check(calificacion_arbitro in ('malo','bueno','excelente')),
  add column if not exists calificacion_arbitro_por uuid references auth.users(id),
  add column if not exists calificacion_arbitro_en timestamptz;

create or replace function public.lm_vocal_regla_datos(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare categoria text;
begin
  if auth.uid() is null or not (coalesce(public.lm_es_vocal(),false)
    or coalesce(public.lm_admin_puede_cargar_vocalia(p_partido_id),false)) then
    raise exception 'No tienes permiso para consultar esta planilla.';
  end if;
  select c.categoria into categoria from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id where p.id=p_partido_id;
  if not found then raise exception 'El partido no existe.'; end if;
  return jsonb_build_object('categoria',categoria,
    'calificacion_arbitro',(select b.calificacion_arbitro from public.lm_vocal_borradores b where b.partido_id=p_partido_id),
    'nacimientos',coalesce((select jsonb_object_agg(cj.id::text,j.fecha_nacimiento)
      from public.campeonato_partidos p join public.campeonato_jugadores cj
        on cj.campeonato_id=p.campeonato_id and cj.equipo_id in(p.equipo_local_id,p.equipo_visitante_id)
      join public.jugadores j on j.id=cj.jugador_id where p.id=p_partido_id),'{}'::jsonb));
end; $$;

create or replace function public.lm_vocal_guardar_con_calificacion(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,p_version integer,
  p_controles jsonb,p_finalizar boolean,p_informe_arbitral text,p_informe_vocal text,
  p_firmas jsonb,p_calificacion text
) returns integer language plpgsql security definer set search_path='' as $$
declare version integer;
begin
  if auth.uid() is null or not coalesce(public.lm_es_vocal(),false) then
    raise exception 'Solo el vocal puede calificar al árbitro.';
  end if;
  if p_calificacion is null or p_calificacion not in ('malo','bueno','excelente') then
    raise exception 'Selecciona Malo, Bueno o Excelente.';
  end if;
  -- Misma transacción, permisos, versión y cierre de la planilla original.
  version:=public.lm_vocal_guardar_planilla_firmas(p_partido_id,p_vocal,p_arbitro,
    p_jugadores,p_version,p_controles,p_finalizar,p_informe_arbitral,p_informe_vocal,p_firmas);
  update public.lm_vocal_borradores set calificacion_arbitro=p_calificacion,
    calificacion_arbitro_por=auth.uid(),calificacion_arbitro_en=now()
    where partido_id=p_partido_id and calificacion_arbitro is distinct from p_calificacion;
  return version;
end; $$;
revoke all on function public.lm_vocal_regla_datos(uuid),
  public.lm_vocal_guardar_con_calificacion(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb,text)
  from public,anon,authenticated;
grant execute on function public.lm_vocal_regla_datos(uuid),
  public.lm_vocal_guardar_con_calificacion(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb,text)
  to authenticated;
notify pgrst,'reload schema';
commit;
