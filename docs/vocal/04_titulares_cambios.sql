begin;
create or replace function public.lm_vocal_guardar(
  p_partido_id uuid, p_vocal text, p_arbitro text, p_jugadores jsonb, p_version integer
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_actual integer; v_item jsonb;
  v_id uuid; v_ta integer; v_goles integer; v_tr boolean; v_ids uuid[]:='{}'; v_filas jsonb:='[]';
begin
  if not coalesce(public.lm_es_vocal(),false) then raise exception 'Se requiere una cuenta de vocal activa.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido ya no existe.'; end if;
  if v_p.estado<>'programado'
    or exists(select 1 from public.campeonatos where id=v_p.campeonato_id and estado in('finalizado','archivado'))
    or exists(select 1 from public.campeonato_fases where id=v_p.fase_id and estado='finalizada')
    or exists(select 1 from public.campeonato_resultados where partido_id=v_p.id and estado='confirmado')
  then raise exception 'El partido está cerrado y no admite cambios del vocal.'; end if;
  if coalesce(length(trim(p_vocal)),0) not between 1 and 150 or coalesce(length(trim(p_arbitro)),0) not between 1 and 150
    then raise exception 'Escribe los nombres del vocal y del árbitro (máximo 150 caracteres).'; end if;
  if p_jugadores is null or jsonb_typeof(p_jugadores)<>'array' then raise exception 'La lista de jugadores no es válida.'; end if;
  if jsonb_array_length(p_jugadores)>100 then raise exception 'La planilla supera el límite de 100 jugadores.'; end if;
  select version into v_actual from public.lm_vocal_borradores where partido_id=v_p.id;
  if p_version is distinct from coalesce(v_actual,0) then raise exception 'Otro vocal guardó cambios. Vuelve a abrir el partido para cargar la versión actual.'; end if;
  for v_item in select value from jsonb_array_elements(p_jugadores) loop
    if coalesce(v_item->>'ta','') !~ '^[0-2]$' or coalesce(v_item->>'goles','') !~ '^[0-9]{1,2}$'
      or jsonb_typeof(v_item->'tr') is distinct from 'boolean' then raise exception 'Revisa las tarjetas y los goles.'; end if;
    v_id:=(v_item->>'id')::uuid; v_ta:=(v_item->>'ta')::integer;
    v_goles:=(v_item->>'goles')::integer; v_tr:=(v_item->>'tr')::boolean;
    if v_id=any(v_ids) then raise exception 'Hay un jugador repetido.'; end if;
    if not exists(select 1 from public.campeonato_jugadores cj
      join public.jugadores j on j.id=cj.jugador_id
      join public.campeonato_equipos ce on ce.campeonato_id=cj.campeonato_id and ce.equipo_id=cj.equipo_id
      where cj.id=v_id and cj.campeonato_id=v_p.campeonato_id
        and cj.equipo_id in(v_p.equipo_local_id,v_p.equipo_visitante_id)
        and cj.estado='inscrito' and ce.estado='inscrito' and j.estado='Calificado')
    then raise exception 'Un jugador no está inscrito y calificado para este partido.'; end if;
    v_ids:=array_append(v_ids,v_id);
    v_filas:=v_filas||jsonb_build_array(jsonb_build_object('id',v_id,'ta',v_ta,'tr',v_tr,'goles',v_goles,'tipo',coalesce(v_item->>'tipo','titular'),'sale_id',v_item->>'sale_id'));
  end loop;
  if exists (
    select 1 from jsonb_array_elements(v_filas) x
    where x->>'tipo' not in ('titular','cambio')
  ) then raise exception 'Tipo de jugador inválido.'; end if;
  if exists (
    select 1 from jsonb_array_elements(v_filas) x
    join public.campeonato_jugadores cj on cj.id=(x->>'id')::uuid
    group by cj.equipo_id,x->>'tipo'
    having count(*) > case when x->>'tipo'='cambio' then 6 else 11 end
  ) then raise exception 'Cada equipo admite 11 titulares y 6 cambios.'; end if;
  for v_item in select value from jsonb_array_elements(v_filas) loop
    if v_item->>'sale_id' is not null then
      if v_item->>'tipo'<>'cambio' or not exists (
        select 1 from jsonb_array_elements(v_filas) titular
        join public.campeonato_jugadores s on s.id=(titular->>'id')::uuid
        join public.campeonato_jugadores e on e.id=(v_item->>'id')::uuid
        where titular->>'id'=v_item->>'sale_id'
          and titular->>'tipo'='titular' and s.equipo_id=e.equipo_id
      ) then raise exception 'El jugador que sale debe ser titular del mismo equipo.'; end if;
    end if;
  end loop;
  if exists (
    select 1 from jsonb_array_elements(v_filas) x where x->>'sale_id' is not null
    group by x->>'sale_id' having count(*)>1
  ) then raise exception 'Un titular no puede salir dos veces.'; end if;
  insert into public.lm_vocal_borradores(partido_id,vocal,arbitro,jugadores,version,actualizado_por)
    values(v_p.id,trim(p_vocal),trim(p_arbitro),v_filas,1,auth.uid())
  on conflict(partido_id) do update set vocal=excluded.vocal,arbitro=excluded.arbitro,
    jugadores=excluded.jugadores,version=public.lm_vocal_borradores.version+1,
    actualizado_por=auth.uid(),actualizado_en=now()
  returning version into v_actual;
  return v_actual;
end; $$;
notify pgrst, 'reload schema';
commit;
