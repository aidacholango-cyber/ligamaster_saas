-- Añade únicamente los dos informes a la planilla existente.
begin;
alter table public.lm_vocal_borradores
  add column if not exists informe_arbitral text not null default '',
  add column if not exists informe_vocal text not null default '';

create or replace function public.lm_vocal_leer_planilla_controles(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_d jsonb; v_b public.lm_vocal_borradores%rowtype;
begin
  v_d := public.lm_vocal_leer_partido(p_partido_id);
  select * into v_b from public.lm_vocal_borradores where partido_id=p_partido_id;
  return jsonb_set(v_d,'{borrador}',
    coalesce(nullif(v_d->'borrador','null'::jsonb),'{}'::jsonb)
    || jsonb_build_object('controles_equipo',coalesce(v_b.controles_equipo,'{}'::jsonb),
      'informe_arbitral',coalesce(v_b.informe_arbitral,''),
      'informe_vocal',coalesce(v_b.informe_vocal,'')));
end; $$;

create or replace function public.lm_vocal_guardar_planilla_informes(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,
  p_version integer,p_controles jsonb,p_finalizar boolean,
  p_informe_arbitral text,p_informe_vocal text
)
returns integer language plpgsql security definer set search_path='' as $$
declare v_version integer;
begin
  if length(coalesce(p_informe_arbitral,''))>5000 or length(coalesce(p_informe_vocal,''))>5000 then
    raise exception 'Cada informe admite un máximo de 5000 caracteres.';
  end if;
  -- Conserva la autorización, bloqueo, versión, controles y publicación existentes.
  v_version := public.lm_vocal_guardar_planilla_controles(
    p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version,p_controles,p_finalizar);
  update public.lm_vocal_borradores
    set informe_arbitral=coalesce(p_informe_arbitral,''),
        informe_vocal=coalesce(p_informe_vocal,'')
    where partido_id=p_partido_id;
  return v_version;
end; $$;
revoke all on function public.lm_vocal_guardar_planilla_informes(uuid,text,text,jsonb,integer,jsonb,boolean,text,text)
from public,anon,authenticated;
grant execute on function public.lm_vocal_guardar_planilla_informes(uuid,text,text,jsonb,integer,jsonb,boolean,text,text)
to authenticated;
notify pgrst, 'reload schema';
commit;
