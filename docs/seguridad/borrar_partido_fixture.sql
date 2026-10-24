-- Añade exclusivamente el borrado manual de un partido sin planillas/resultados.
begin;
create or replace function public.lm_fixture_borrar_partido(p_partido_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_c public.campeonatos%rowtype;
begin
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido ya no existe.'; end if;
  select * into v_c from public.campeonatos where id=v_p.campeonato_id for update;
  if not found then raise exception 'El campeonato no existe.'; end if;
  if auth.uid() is null or not coalesce(
    public.lm_es_superadmin() or public.lm_administra_liga(v_c.liga_id::text),false
  ) then raise exception 'Solo el administrador de esta liga puede borrar el partido.'; end if;
  if v_c.estado in ('finalizado','archivado') or exists(
    select 1 from public.campeonato_fases where id=v_p.fase_id and estado='finalizada'
  ) then raise exception 'El campeonato o la fase está cerrado.'; end if;
  if exists(select 1 from public.campeonato_resultados where partido_id=p_partido_id)
    or exists(select 1 from public.campeonato_planillas where partido_id=p_partido_id)
  then raise exception 'El partido tiene planillas o resultados. Su historial debe conservarse.'; end if;
  delete from public.campeonato_partidos where id=p_partido_id;
end; $$;
revoke all on function public.lm_fixture_borrar_partido(uuid) from public,anon,authenticated;
grant execute on function public.lm_fixture_borrar_partido(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
