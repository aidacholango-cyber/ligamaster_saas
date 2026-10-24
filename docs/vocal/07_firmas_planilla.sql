-- Firmas dibujadas: se conservan con la misma versión y cierre de la planilla.
-- Requiere los módulos de controles e informes ya instalados.
begin;
alter table public.lm_vocal_borradores add column if not exists firmas jsonb not null default '{}'::jsonb;

create or replace function public.lm_vocal_leer_planilla_controles(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_d jsonb; v_b public.lm_vocal_borradores%rowtype;
begin
  v_d:=public.lm_vocal_leer_partido(p_partido_id);
  select * into v_b from public.lm_vocal_borradores where partido_id=p_partido_id;
  return jsonb_set(v_d,'{borrador}',coalesce(nullif(v_d->'borrador','null'::jsonb),'{}'::jsonb)
    ||jsonb_build_object('controles_equipo',coalesce(v_b.controles_equipo,'{}'::jsonb),
      'informe_arbitral',coalesce(v_b.informe_arbitral,''),'informe_vocal',coalesce(v_b.informe_vocal,''),
      'firmas',coalesce(v_b.firmas,'{}'::jsonb)));
end; $$;

create or replace function public.lm_vocal_guardar_planilla_firmas(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,
  p_version integer,p_controles jsonb,p_finalizar boolean,
  p_informe_arbitral text,p_informe_vocal text,p_firmas jsonb
) returns integer language plpgsql security definer set search_path='' as $$
declare v_clave text; v_firma jsonb; v_trazo jsonb; v_punto jsonb; v_total integer:=0; v_version integer;
begin
  if not coalesce(public.lm_es_vocal(),false) then raise exception 'Se requiere una cuenta de vocal activa.'; end if;
  if p_firmas is null or jsonb_typeof(p_firmas)<>'object' or length(p_firmas::text)>524288 then
    raise exception 'Las firmas no son válidas o superan el tamaño permitido.';
  end if;
  for v_clave,v_firma in select key,value from jsonb_each(p_firmas) loop
    if v_clave not in ('capitan_local','capitan_visitante','vocal','arbitro')
      or jsonb_typeof(v_firma)<>'array' then raise exception 'El cuadro de firma no es válido.'; end if;
    if jsonb_array_length(v_firma)>200 then raise exception 'Limpia la firma y vuelve a dibujarla.'; end if;
    for v_trazo in select value from jsonb_array_elements(v_firma) loop
      if jsonb_typeof(v_trazo)<>'array' then raise exception 'El trazo de firma no es válido.'; end if;
      if jsonb_array_length(v_trazo) not between 1 and 2000 then raise exception 'El trazo de firma supera el límite permitido.'; end if;
      v_total:=v_total+jsonb_array_length(v_trazo);
      if v_total>12000 then raise exception 'Las firmas superan el límite de trazos permitido.'; end if;
      for v_punto in select value from jsonb_array_elements(v_trazo) loop
        if jsonb_typeof(v_punto)<>'array' then raise exception 'Las coordenadas de firma no son válidas.'; end if;
        if jsonb_array_length(v_punto)<>2 or jsonb_typeof(v_punto->0) is distinct from 'number'
          or jsonb_typeof(v_punto->1) is distinct from 'number' then raise exception 'Las coordenadas de firma no son válidas.'; end if;
        if (v_punto->>0)::numeric not between 0 and 1 or (v_punto->>1)::numeric not between 0 and 1
          then raise exception 'La firma debe permanecer dentro de su cuadro.'; end if;
      end loop;
    end loop;
  end loop;
  -- Reutiliza autorización, versión, controles, informes y publicación existentes.
  v_version:=public.lm_vocal_guardar_planilla_informes(p_partido_id,p_vocal,p_arbitro,p_jugadores,
    p_version,p_controles,p_finalizar,p_informe_arbitral,p_informe_vocal);
  update public.lm_vocal_borradores set firmas=p_firmas where partido_id=p_partido_id;
  return v_version;
end; $$;
revoke all on function public.lm_vocal_guardar_planilla_firmas(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb)
from public,anon,authenticated;
grant execute on function public.lm_vocal_guardar_planilla_firmas(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb)
to authenticated;
notify pgrst, 'reload schema';
commit;
