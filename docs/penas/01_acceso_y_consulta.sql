-- Módulo separado; no reemplaza funciones ni políticas del administrador.
begin;
create table if not exists public.lm_comision_penas (
 usuario_id uuid primary key references auth.users(id) on delete cascade,
 activo boolean not null default true
);
alter table public.lm_comision_penas enable row level security;
revoke all on public.lm_comision_penas from public,anon,authenticated;
create or replace function public.lm_es_comision_penas()
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.lm_comision_penas where usuario_id=auth.uid() and activo);
$$;
create or replace function public.lm_penas_hojas()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.lm_es_comision_penas() then raise exception 'No tienes acceso a la comisión de penas y sanciones.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'fecha_hora',p.fecha_hora,'jornada',p.jornada,'numero_partido',p.numero_partido,
   'campeonato',c.nombre,'categoria',c.categoria,'liga',l.nombre,'local',el.nombre,'visitante',ev.nombre) order by p.fecha_hora desc,p.numero_partido desc)
 from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
 join public.ligas l on l.id::text=c.liga_id::text join public.equipos el on el.id=p.equipo_local_id join public.equipos ev on ev.id=p.equipo_visitante_id
 where c.activo=true and exists(select 1 from public.campeonato_resultados r where r.partido_id=p.id and r.estado='confirmado')
 and exists(select 1 from public.lm_vocal_borradores b where b.partido_id=p.id)),'[]'::jsonb);
end;
$$;
create or replace function public.lm_penas_hoja_leer(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p public.campeonato_partidos%rowtype; categoria text;
begin
 if not public.lm_es_comision_penas() then raise exception 'No tienes acceso a la comisión de penas y sanciones.'; end if;
 select cp.* into p from public.campeonato_partidos cp join public.campeonatos c on c.id=cp.campeonato_id
 where cp.id=p_partido_id and c.activo=true and exists(select 1 from public.campeonato_resultados r where r.partido_id=cp.id and r.estado='confirmado');
 if not found then raise exception 'La hoja debe pertenecer a un campeonato activo y tener resultado confirmado.'; end if;
 if not exists(select 1 from public.lm_vocal_borradores where partido_id=p.id) then raise exception 'El partido no tiene una hoja de vocalía guardada.'; end if;
 select c.categoria into categoria from public.campeonatos c where c.id=p.campeonato_id;
 return jsonb_build_object('editable',false,'categoria',categoria,
  'partido',to_jsonb(p)||jsonb_build_object('local',(select nombre from public.equipos where id=p.equipo_local_id),'visitante',(select nombre from public.equipos where id=p.equipo_visitante_id)),
  'turno_vocalia',(select jsonb_build_object('equipo',e.nombre) from public.equipos e where e.id=p.equipo_vocal_id),
  'calificacion_arbitro',(select b.calificacion_arbitro from public.lm_vocal_borradores b where b.partido_id=p.id),
  'jugadores',coalesce((select jsonb_agg(jsonb_build_object('id',cj.id,'equipo_id',cj.equipo_id,'nombres',j.nombres,'apellidos',j.apellidos,
    'camiseta',coalesce(j.num_camiseta,j.numero_camiseta,j.dorsal),'foto_url',coalesce(nullif(j.foto_url,''),j.foto_perfil_url),
    'habilitado',cj.estado='inscrito' and ce.estado='inscrito' and j.estado='Calificado') order by cj.equipo_id,j.apellidos,j.nombres)
    from public.campeonato_jugadores cj join public.jugadores j on j.id=cj.jugador_id
    join public.campeonato_equipos ce on ce.campeonato_id=cj.campeonato_id and ce.equipo_id=cj.equipo_id
    where cj.campeonato_id=p.campeonato_id and cj.equipo_id in(p.equipo_local_id,p.equipo_visitante_id)),'[]'::jsonb),
  'borrador',(select to_jsonb(b) from public.lm_vocal_borradores b where b.partido_id=p.id)
 );
end;
$$;
revoke all on function public.lm_es_comision_penas(),public.lm_penas_hojas(),public.lm_penas_hoja_leer(uuid) from public,anon,authenticated;
grant execute on function public.lm_es_comision_penas(),public.lm_penas_hojas(),public.lm_penas_hoja_leer(uuid) to authenticated;
commit;
