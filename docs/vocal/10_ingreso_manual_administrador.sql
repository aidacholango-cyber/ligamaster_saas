-- Ingreso manual de vocalía reservado al administrador de la liga/superadmin.
-- Añade funciones separadas; no cambia las funciones que utiliza el vocal.
begin;
create or replace function public.lm_admin_puede_cargar_vocalia(p_partido_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(
    select 1 from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id
    where p.id=p_partido_id
      and coalesce(public.lm_es_superadmin() or public.lm_administra_liga(c.liga_id::text),false)
  );
$$;
revoke all on function public.lm_admin_puede_cargar_vocalia(uuid) from public,anon,authenticated;
grant execute on function public.lm_admin_puede_cargar_vocalia(uuid) to authenticated;
create or replace function public.lm_admin_hoja_vocalia_leer(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_editable boolean;
begin
  if not public.lm_admin_puede_cargar_vocalia(p_partido_id) then raise exception 'Solo el administrador de esta liga puede ingresar la vocalía manual.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id;
  if not found then raise exception 'El partido ya no existe.'; end if;
  select v_p.estado='programado' and c.estado not in ('finalizado','archivado')
    and not exists(select 1 from public.campeonato_resultados r where r.partido_id=v_p.id and r.estado='confirmado')
    and not exists(select 1 from public.campeonato_fases f where f.id=v_p.fase_id and f.estado='finalizada')
    into v_editable from public.campeonatos c where c.id=v_p.campeonato_id;
  return jsonb_build_object(
    'editable',coalesce(v_editable,false),
    'partido',jsonb_build_object('id',v_p.id,'fecha_hora',v_p.fecha_hora,'cancha',v_p.cancha,
      'equipo_local_id',v_p.equipo_local_id,'equipo_visitante_id',v_p.equipo_visitante_id,
      'local',(select nombre from public.equipos where id=v_p.equipo_local_id),
      'visitante',(select nombre from public.equipos where id=v_p.equipo_visitante_id)),
    'jugadores',coalesce((select jsonb_agg(jsonb_build_object(
      'id',cj.id,'equipo_id',cj.equipo_id,'nombres',j.nombres,'apellidos',j.apellidos,
      'camiseta',coalesce(j.num_camiseta,j.numero_camiseta,j.dorsal),
      'foto_url',coalesce(nullif(j.foto_url,''),j.foto_perfil_url),
      'habilitado',cj.estado='inscrito' and ce.estado='inscrito' and j.estado='Calificado'
    ) order by cj.equipo_id,j.apellidos,j.nombres,cj.id)
    from public.campeonato_jugadores cj
    join public.jugadores j on j.id=cj.jugador_id
    join public.campeonato_equipos ce on ce.campeonato_id=cj.campeonato_id and ce.equipo_id=cj.equipo_id
    where cj.campeonato_id=v_p.campeonato_id and cj.equipo_id in(v_p.equipo_local_id,v_p.equipo_visitante_id)), '[]'::jsonb),
    'borrador',(select jsonb_build_object('vocal',b.vocal,'arbitro',b.arbitro,'jugadores',b.jugadores,'version',b.version,'controles_equipo',b.controles_equipo,'informe_arbitral',b.informe_arbitral,'informe_vocal',b.informe_vocal,'firmas',b.firmas)
      from public.lm_vocal_borradores b where b.partido_id=v_p.id)
  );
end; $$;
revoke all on function public.lm_admin_hoja_vocalia_leer(uuid) from public,anon,authenticated;
grant execute on function public.lm_admin_hoja_vocalia_leer(uuid) to authenticated;
create or replace function public.lm_admin_vocal_guardar(
  p_partido_id uuid, p_vocal text, p_arbitro text, p_jugadores jsonb, p_version integer
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_actual integer; v_item jsonb;
  v_id uuid; v_ta integer; v_goles integer; v_tr boolean; v_ids uuid[]:='{}'; v_filas jsonb:='[]';
begin
  if not public.lm_admin_puede_cargar_vocalia(p_partido_id) then raise exception 'Solo el administrador de esta liga puede ingresar la vocalía manual.'; end if;
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
revoke all on function public.lm_admin_vocal_guardar(uuid,text,text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.lm_admin_vocal_guardar(uuid,text,text,jsonb,integer) to authenticated;
create or replace function public.lm_admin_vocal_finalizar(
  p_partido_id uuid, p_vocal text, p_arbitro text, p_jugadores jsonb, p_version integer
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_version integer;
  v_local integer; v_visitante integer;
begin
  if not public.lm_admin_puede_cargar_vocalia(p_partido_id) then raise exception 'Solo el administrador de esta liga puede ingresar la vocalía manual.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido no existe.'; end if;
  -- No sobrescribir trabajo oficial preparado por el administrador.
  if exists(select 1 from public.campeonato_resultados where partido_id=p_partido_id)
    or exists(select 1 from public.campeonato_planillas where partido_id=p_partido_id)
  then raise exception 'El partido ya tiene una planilla oficial. El administrador debe revisar esa acta; no se sobrescribieron sus datos.'; end if;
  -- Valida cuenta, versión, partido abierto, inscripción y tarjetas antes de publicar.
  v_version:=public.lm_admin_vocal_guardar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
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
revoke all on function public.lm_admin_vocal_finalizar(uuid,text,text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.lm_admin_vocal_finalizar(uuid,text,text,jsonb,integer) to authenticated;
create or replace function public.lm_admin_vocal_guardar_planilla_controles(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,
  p_version integer,p_controles jsonb,p_finalizar boolean
)
returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_equipo text; v_valores jsonb;
  v_clave text; v_valor jsonb; v_version integer;
begin
  if not public.lm_admin_puede_cargar_vocalia(p_partido_id) then
    raise exception 'Solo el administrador de esta liga puede ingresar la vocalía manual.';
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
    v_version := public.lm_admin_vocal_finalizar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
  else
    v_version := public.lm_admin_vocal_guardar(p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version);
  end if;
  update public.lm_vocal_borradores set controles_equipo=p_controles
    where partido_id=p_partido_id;
  return v_version;
end; $$;
revoke all on function public.lm_admin_vocal_guardar_planilla_controles(uuid,text,text,jsonb,integer,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.lm_admin_vocal_guardar_planilla_controles(uuid,text,text,jsonb,integer,jsonb,boolean) to authenticated;
create or replace function public.lm_admin_vocal_guardar_planilla_informes(
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
  v_version := public.lm_admin_vocal_guardar_planilla_controles(
    p_partido_id,p_vocal,p_arbitro,p_jugadores,p_version,p_controles,p_finalizar);
  update public.lm_vocal_borradores
    set informe_arbitral=coalesce(p_informe_arbitral,''),
        informe_vocal=coalesce(p_informe_vocal,'')
    where partido_id=p_partido_id;
  return v_version;
end; $$;
revoke all on function public.lm_admin_vocal_guardar_planilla_informes(uuid,text,text,jsonb,integer,jsonb,boolean,text,text) from public,anon,authenticated;
grant execute on function public.lm_admin_vocal_guardar_planilla_informes(uuid,text,text,jsonb,integer,jsonb,boolean,text,text) to authenticated;
create or replace function public.lm_admin_vocal_guardar_planilla_firmas(
  p_partido_id uuid,p_vocal text,p_arbitro text,p_jugadores jsonb,
  p_version integer,p_controles jsonb,p_finalizar boolean,
  p_informe_arbitral text,p_informe_vocal text,p_firmas jsonb
) returns integer language plpgsql security definer set search_path='' as $$
declare v_clave text; v_firma jsonb; v_trazo jsonb; v_punto jsonb; v_total integer:=0; v_version integer;
begin
  if not public.lm_admin_puede_cargar_vocalia(p_partido_id) then raise exception 'Solo el administrador de esta liga puede ingresar la vocalía manual.'; end if;
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
  v_version:=public.lm_admin_vocal_guardar_planilla_informes(p_partido_id,p_vocal,p_arbitro,p_jugadores,
    p_version,p_controles,p_finalizar,p_informe_arbitral,p_informe_vocal);
  update public.lm_vocal_borradores set firmas=p_firmas where partido_id=p_partido_id;
  return v_version;
end; $$;
revoke all on function public.lm_admin_vocal_guardar_planilla_firmas(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.lm_admin_vocal_guardar_planilla_firmas(uuid,text,text,jsonb,integer,jsonb,boolean,text,text,jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
