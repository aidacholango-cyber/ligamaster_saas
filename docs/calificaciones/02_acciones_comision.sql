-- Ejecutar después de 01 y 03. Conserva las reglas del trigger original.
-- RPC exclusivas de la comisión: no reemplazan las funciones del administrador.
begin;
create or replace function public.lm_comision_revisar_jugador(
  p_campeonato_id uuid,p_jugador_id uuid,p_observaciones text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare jugador public.jugadores%rowtype; resultado jsonb;
begin
  select * into jugador from public.jugadores where id=p_jugador_id for update;
  if not found then raise exception 'Jugador no disponible.'; end if;
  if not public.lm_comision_equipo_permitido(p_campeonato_id,jugador.equipo_id)
    or not exists(select 1 from public.campeonato_jugadores cj
      join public.campeonatos c on c.id=cj.campeonato_id
      where cj.campeonato_id=p_campeonato_id and cj.jugador_id=jugador.id
        and cj.equipo_id=jugador.equipo_id and cj.estado='inscrito'
        and c.categoria=jugador.categoria) then
    raise exception 'No tienes acceso a este jugador en este campeonato.';
  end if;
  if coalesce(length(trim(p_observaciones)),0) not between 1 and 4000 then
    raise exception 'Escribe las observaciones de la revisión (máximo 4000 caracteres).';
  end if;
  perform pg_catalog.set_config('ligamaster.comision_campeonato',p_campeonato_id::text,true);
  update public.jugadores j set estado='Revisado',
    observaciones=p_observaciones,fecha_revision=clock_timestamp()
  where j.id=p_jugador_id returning to_jsonb(j) into resultado;
  insert into public.lm_comision_auditoria(usuario_id,campeonato_id,jugador_id,accion)
    values(auth.uid(),p_campeonato_id,p_jugador_id,'revision');
  perform pg_catalog.set_config('ligamaster.comision_campeonato','',true);
  return resultado;
end; $$;

create or replace function public.lm_comision_calificar_jugador(
  p_campeonato_id uuid,p_jugador_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare jugador public.jugadores%rowtype; resultado jsonb;
begin
  select * into jugador from public.jugadores where id=p_jugador_id for update;
  if not found then raise exception 'Jugador no disponible.'; end if;
  if not public.lm_comision_equipo_permitido(p_campeonato_id,jugador.equipo_id)
    or not exists(select 1 from public.campeonato_jugadores cj
      join public.campeonatos c on c.id=cj.campeonato_id
      where cj.campeonato_id=p_campeonato_id and cj.jugador_id=jugador.id
        and cj.equipo_id=jugador.equipo_id and cj.estado='inscrito'
        and c.categoria=jugador.categoria) then
    raise exception 'No tienes acceso a este jugador en este campeonato.';
  end if;
  if jugador.estado='Calificado' and jugador.fecha_calificacion is not null
    and jugador.calificado_por_id is not null then return to_jsonb(jugador); end if;
  if jugador.estado<>'Revisado' or jugador.fecha_revision is null then
    raise exception 'Primero revisa al jugador y guarda las observaciones.';
  end if;
  perform pg_catalog.set_config('ligamaster.comision_campeonato',p_campeonato_id::text,true);
  update public.jugadores j set estado='Calificado' where j.id=p_jugador_id
    returning to_jsonb(j) into resultado;
  insert into public.lm_comision_auditoria(usuario_id,campeonato_id,jugador_id,accion)
    values(auth.uid(),p_campeonato_id,p_jugador_id,'calificacion');
  perform pg_catalog.set_config('ligamaster.comision_campeonato','',true);
  return resultado;
end; $$;

revoke all on function public.lm_comision_revisar_jugador(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.lm_comision_calificar_jugador(uuid,uuid) from public,anon,authenticated;
grant execute on function public.lm_comision_revisar_jugador(uuid,uuid,text) to authenticated;
grant execute on function public.lm_comision_calificar_jugador(uuid,uuid) to authenticated;
commit;
