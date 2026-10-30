-- Complemento para una comisión técnica ya instalada.
-- No cambia el borrado ni los permisos del administrador.
begin;
create or replace function public.lm_tecnica_borrar_partido(p_partido_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare p public.campeonato_partidos%rowtype; fase uuid; hay_datos boolean; tabla text;
begin
  if not public.lm_es_comision_tecnica() then raise exception 'No tienes acceso a la comisión técnica.'; end if;
  select fase_id into fase from public.campeonato_partidos where id=p_partido_id;
  if not found then raise exception 'El partido ya no existe.'; end if;
  -- Mismo orden de bloqueo que la programación.
  perform 1 from public.campeonato_fases where id=fase for update;
  select * into p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido ya no existe.'; end if;
  perform 1 from public.campeonatos where id=p.campeonato_id for share;
  if not exists(select 1 from public.campeonatos where id=p.campeonato_id and activo=true and estado not in ('finalizado','archivado'))
    or exists(select 1 from public.campeonato_fases where id=p.fase_id and estado='finalizada') then raise exception 'El campeonato o la fase está cerrado.'; end if;
  if exists(select 1 from public.campeonato_resultados where partido_id=p.id)
    or exists(select 1 from public.campeonato_planillas where partido_id=p.id) then
    raise exception 'El partido tiene planillas o resultados y no se puede eliminar desde la comisión técnica.';
  end if;
  -- Los complementos de vocalía/tesorería pueden instalarse por separado.
  foreach tabla in array array['lm_vocal_borradores','lm_tesoreria_cobros','lm_tesoreria_historial','lm_tesoreria_movimientos'] loop
    if to_regclass('public.'||tabla) is not null then
      execute format('select exists(select 1 from public.%I where partido_id=$1)',tabla) into hay_datos using p.id;
      if hay_datos then raise exception 'El partido tiene una hoja de vocalía o movimientos de tesorería y no se puede eliminar desde la comisión técnica.'; end if;
    end if;
  end loop;
  delete from public.campeonato_partidos where id=p.id;
end;
$$;
revoke all on function public.lm_tecnica_borrar_partido(uuid) from public,anon,authenticated;
grant execute on function public.lm_tecnica_borrar_partido(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
