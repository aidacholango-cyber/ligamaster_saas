-- Instalar después de 01_acceso_y_consulta.sql.
-- Correcciones separadas: no cambia hojas, planillas, resultados, firmas ni cobros.
begin;
create table if not exists public.lm_penas_revisiones (
 partido_id uuid primary key references public.campeonato_partidos(id) on delete restrict,
 revision integer not null,
 origen text not null,
 observaciones text not null,
 actualizado_por uuid not null references auth.users(id),
 actualizado_en timestamptz not null default now()
);
create table if not exists public.lm_penas_correcciones (
 partido_id uuid not null references public.lm_penas_revisiones(partido_id) on delete cascade,
 inscripcion_jugador_id uuid not null references public.campeonato_jugadores(id) on delete restrict,
 amarillas integer not null check(amarillas between 0 and 2),
 roja_directa boolean not null,
 suspension_manual integer check(suspension_manual between 0 and 100),
 primary key(partido_id,inscripcion_jugador_id)
);
create table if not exists public.lm_penas_historial (
 id bigint generated always as identity primary key,
 partido_id uuid not null references public.campeonato_partidos(id) on delete restrict,
 revision integer not null,
 origen text not null,
 datos jsonb not null,
 enviado boolean not null,
 usuario_id uuid not null references auth.users(id),
 creado_en timestamptz not null default now(),
 unique(partido_id,revision)
);
alter table public.lm_penas_revisiones enable row level security;
alter table public.lm_penas_correcciones enable row level security;
alter table public.lm_penas_historial enable row level security;
revoke all on public.lm_penas_revisiones,public.lm_penas_correcciones,public.lm_penas_historial from public,anon,authenticated;
revoke all on sequence public.lm_penas_historial_id_seq from public,anon,authenticated;

create or replace function public.lm_penas_puede_gestionar(p_partido uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(
  select 1 from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
  where p.id=p_partido and exists(select 1 from public.campeonato_resultados r where r.partido_id=p.id and r.estado='confirmado')
   and exists(select 1 from public.lm_vocal_borradores b where b.partido_id=p.id)
   and ((c.activo=true and public.lm_es_comision_penas()) or coalesce(public.lm_es_superadmin() or public.lm_administra_liga(c.liga_id::text),false))
 );
$$;
create or replace function public.lm_penas_origen(p_partido uuid)
returns text language sql stable security definer set search_path='' as $$
 select md5(jsonb_build_object('fecha',p.fecha_hora,'estado',p.estado,
  'resultado',(select to_jsonb(r) from public.campeonato_resultados r where r.partido_id=p.id),
  'version',(select b.version from public.lm_vocal_borradores b where b.partido_id=p.id),
  'planillas',coalesce((select jsonb_agg(to_jsonb(pl) order by pl.inscripcion_jugador_id) from public.campeonato_planillas pl where pl.partido_id=p.id),'[]'::jsonb))::text)
 from public.campeonato_partidos p where p.id=p_partido;
$$;

-- Recorre los mismos partidos confirmados y aplica las mismas reglas que las
-- vistas originales enviadas por el usuario. Solo superpone correcciones vigentes.
create or replace function public.lm_penas_calcular(p_campeonato uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 with recursive revisiones_vigentes as materialized (
  select pr.partido_id from public.lm_penas_revisiones pr
  join public.campeonato_partidos p on p.id=pr.partido_id
  where p.campeonato_id=p_campeonato and pr.origen=public.lm_penas_origen(p.id)
 ), base as (
  select cj.id inscripcion_jugador_id,p.id partido_id,p.fecha_hora,
   coalesce(pl.participo,false) participo,
   coalesce(pc.amarillas,pl.amarillas,0)::bigint amarillas,
   coalesce(pc.roja_directa,pl.roja_directa,false) roja_directa,
   pc.suspension_manual,
   count(*) over(partition by cj.id,p.fecha_hora) coincidencias_fecha
  from public.campeonato_jugadores cj
  join public.campeonato_partidos p on p.campeonato_id=cj.campeonato_id and cj.equipo_id in(p.equipo_local_id,p.equipo_visitante_id)
  join public.campeonato_resultados r on r.partido_id=p.id and r.estado='confirmado'
  left join public.campeonato_planillas pl on pl.partido_id=p.id and pl.inscripcion_jugador_id=cj.id
  left join revisiones_vigentes pr on pr.partido_id=p.id
  left join public.lm_penas_correcciones pc on pc.partido_id=pr.partido_id and pc.inscripcion_jugador_id=cj.id
  where cj.campeonato_id=p_campeonato and p.estado not in('aplazado','cancelado')
 ), ordenados as (
  select b.*,row_number() over(partition by inscripcion_jugador_id order by fecha_hora,partido_id) numero,
   sum(amarillas) over(partition by inscripcion_jugador_id order by fecha_hora,partido_id rows unbounded preceding)::bigint amarillas_acumuladas,
   bool_or(fecha_hora is null or coincidencias_fecha>1) over(partition by inscripcion_jugador_id) fechas_por_revisar
  from base b
 ), eventos as (
  select o.*,coalesce(suspension_manual::bigint,
   case when amarillas=2 then 1 else 0 end+case when roja_directa then 2 else 0 end+
   amarillas_acumuladas/5-(amarillas_acumuladas-amarillas)/5) generados from ordenados o
 ), recorrido as (
  select inscripcion_jugador_id,numero,generados pendientes,generados total_generados,0::bigint cumplidos,0::bigint participaciones_suspendido
  from eventos where numero=1
  union all
  select e.inscripcion_jugador_id,e.numero,
   r.pendientes-case when r.pendientes>0 and not e.participo then 1 else 0 end+e.generados,
   r.total_generados+e.generados,
   r.cumplidos+case when r.pendientes>0 and not e.participo then 1 else 0 end,
   r.participaciones_suspendido+case when r.pendientes>0 and e.participo then 1 else 0 end
  from recorrido r join eventos e on e.inscripcion_jugador_id=r.inscripcion_jugador_id and e.numero=r.numero+1
 ), ultimo as (
  select distinct on(inscripcion_jugador_id) * from recorrido order by inscripcion_jugador_id,numero desc
 ), tarjetas as (
  select inscripcion_jugador_id,count(*) filter(where amarillas=2) expulsiones_doble_amarilla,
   count(*) filter(where roja_directa) rojas_directas from base group by inscripcion_jugador_id
 ), salida as (
  select cj.id inscripcion_jugador_id,cj.campeonato_id,c.nombre campeonato,c.categoria,c.liga_id,cj.equipo_id,eq.nombre equipo,cj.jugador_id,j.nombres,j.apellidos,
   e.amarillas_acumuladas amarillas_total,e.amarillas_acumuladas%5 amarillas_ciclo_actual,
   u.total_generados partidos_suspension_generados,
   case when not e.fechas_por_revisar then u.cumplidos end partidos_cumplidos,
   case when not e.fechas_por_revisar then u.pendientes end partidos_pendientes,
   case when not e.fechas_por_revisar then u.participaciones_suspendido end participaciones_suspendido,
   e.fechas_por_revisar,
   case when e.fechas_por_revisar then 'revisar_fechas' when u.participaciones_suspendido>0 then 'revisar_participacion' when u.pendientes>0 then 'suspendido' when u.total_generados>0 then 'cumplido' else 'sin_suspension' end estado,
   t.expulsiones_doble_amarilla,t.rojas_directas,e.amarillas_acumuladas/5 sanciones_acumulacion
  from ultimo u join eventos e on e.inscripcion_jugador_id=u.inscripcion_jugador_id and e.numero=u.numero
  join tarjetas t on t.inscripcion_jugador_id=u.inscripcion_jugador_id
  join public.campeonato_jugadores cj on cj.id=u.inscripcion_jugador_id
  join public.campeonatos c on c.id=cj.campeonato_id join public.equipos eq on eq.id=cj.equipo_id join public.jugadores j on j.id=cj.jugador_id
  where e.amarillas_acumuladas>0 or u.total_generados>0 or t.rojas_directas>0
 ) select coalesce(jsonb_agg(to_jsonb(s) order by equipo,apellidos,nombres,inscripcion_jugador_id),'[]'::jsonb) from salida s;
$$;

-- La función/vistas anteriores no se reemplazan. Los usuarios existentes pasan
-- por la misma autorización anterior antes de obtener el resumen corregido.
create or replace function public.lm_leer_sanciones_revisadas(p_campeonato_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare anteriores jsonb;
begin
 if public.lm_es_comision_penas() then
  if not exists(select 1 from public.campeonatos where id=p_campeonato_id and activo=true) then raise exception 'El campeonato no está activo.'; end if;
 else
  anteriores:=public.lm_leer_sanciones(p_campeonato_id);
  if not exists(select 1 from public.lm_penas_correcciones pc
    join public.lm_penas_revisiones pr on pr.partido_id=pc.partido_id
    join public.campeonato_partidos p on p.id=pc.partido_id
    where p.campeonato_id=p_campeonato_id and pr.origen=public.lm_penas_origen(p.id)) then
   return anteriores;
  end if;
 end if;
 return public.lm_penas_calcular(p_campeonato_id);
end;
$$;

create or replace function public.lm_penas_revision_leer(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p public.campeonato_partidos%rowtype; revision_actual public.lm_penas_revisiones%rowtype; origen_actual text;
begin
 if not public.lm_penas_puede_gestionar(p_partido_id) then raise exception 'No tienes permiso para revisar esta hoja confirmada.'; end if;
 select * into p from public.campeonato_partidos where id=p_partido_id;
 select * into revision_actual from public.lm_penas_revisiones where partido_id=p.id;
 origen_actual:=public.lm_penas_origen(p.id);
 return jsonb_build_object('revision',coalesce(revision_actual.revision,0),'origen',origen_actual,
  'observaciones',coalesce(revision_actual.observaciones,''),'desactualizada',revision_actual.origen is not null and revision_actual.origen<>origen_actual,
  'jugadores',coalesce((select jsonb_agg(jsonb_build_object('id',cj.id,'equipo_id',cj.equipo_id,'equipo',eq.nombre,
    'nombre',j.nombres||' '||j.apellidos,'camiseta',coalesce(j.num_camiseta,j.numero_camiseta,j.dorsal),
    'participo',coalesce(pl.participo,false),'ta_original',coalesce(pl.amarillas,0),'tr_original',coalesce(pl.roja_directa,false),
    'manual',pc.inscripcion_jugador_id is not null,'ta',coalesce(pc.amarillas,pl.amarillas,0),
    'tr',coalesce(pc.roja_directa,pl.roja_directa,false),'suspension_manual',pc.suspension_manual)
    order by eq.nombre,j.apellidos,j.nombres,cj.id)
   from public.campeonato_jugadores cj join public.jugadores j on j.id=cj.jugador_id join public.equipos eq on eq.id=cj.equipo_id
   left join public.campeonato_planillas pl on pl.partido_id=p.id and pl.inscripcion_jugador_id=cj.id
   left join public.lm_penas_correcciones pc on pc.partido_id=p.id and pc.inscripcion_jugador_id=cj.id and revision_actual.origen=origen_actual
   where cj.campeonato_id=p.campeonato_id and cj.equipo_id in(p.equipo_local_id,p.equipo_visitante_id)),'[]'::jsonb),
  'envio',(select jsonb_build_object('revision',h.revision,'fecha',h.creado_en) from public.lm_penas_historial h where h.partido_id=p.id and h.enviado order by h.revision desc limit 1)
 );
end;
$$;

create or replace function public.lm_penas_revision_guardar(p_partido_id uuid,p_revision integer,p_origen text,p_observaciones text,p_correcciones jsonb,p_enviar boolean)
returns integer language plpgsql security definer set search_path='' as $$
declare p public.campeonato_partidos%rowtype; actual integer; nueva integer; item jsonb; jugador uuid; paquete jsonb;
begin
 if not public.lm_penas_puede_gestionar(p_partido_id) then raise exception 'No tienes permiso para revisar esta hoja confirmada.'; end if;
 select * into p from public.campeonato_partidos where id=p_partido_id for update;
 -- Revalidar después de esperar un bloqueo de reapertura/confirmación.
 if not public.lm_penas_puede_gestionar(p_partido_id) then raise exception 'El partido cambió. Vuelve a abrir la revisión.'; end if;
 if p_origen is distinct from public.lm_penas_origen(p.id) then raise exception 'La hoja o el resultado cambió. Vuelve a cargar antes de revisar.'; end if;
 select revision into actual from public.lm_penas_revisiones where partido_id=p.id for update;
 if p_revision is distinct from coalesce(actual,0) then raise exception 'Otra persona modificó la revisión. Actualiza antes de guardar.'; end if;
 if p_enviar is null then raise exception 'Indica si deseas enviar la revisión.'; end if;
 if length(trim(coalesce(p_observaciones,''))) not between 1 and 4000 then raise exception 'Escribe el motivo o las observaciones de la revisión.'; end if;
 if jsonb_typeof(p_correcciones) is distinct from 'array' then raise exception 'La lista de correcciones no es válida.'; end if;
 if jsonb_array_length(p_correcciones)>1000 then raise exception 'Demasiadas correcciones.'; end if;
 nueva:=coalesce(actual,0)+1;
 insert into public.lm_penas_revisiones(partido_id,revision,origen,observaciones,actualizado_por)
 values(p.id,nueva,p_origen,trim(p_observaciones),auth.uid()) on conflict(partido_id) do update
 set revision=nueva,origen=p_origen,observaciones=trim(p_observaciones),actualizado_por=auth.uid(),actualizado_en=now();
 delete from public.lm_penas_correcciones where partido_id=p.id;
 for item in select value from jsonb_array_elements(p_correcciones) loop
  if jsonb_typeof(item) is distinct from 'object' then raise exception 'Corrección no válida.'; end if;
  jugador:=(item->>'id')::uuid;
  if not exists(select 1 from public.campeonato_jugadores where id=jugador and campeonato_id=p.campeonato_id and equipo_id in(p.equipo_local_id,p.equipo_visitante_id)) then raise exception 'El jugador no pertenece a este partido y categoría.'; end if;
  if jsonb_typeof(item->'ta') is distinct from 'number' or coalesce(item->>'ta','')!~'^[0-2]$'
   or jsonb_typeof(item->'tr') is distinct from 'boolean' then raise exception 'Las tarjetas no son válidas.'; end if;
  if item->>'suspension_manual' is not null and (jsonb_typeof(item->'suspension_manual') is distinct from 'number' or (item->>'suspension_manual')!~'^[0-9]{1,3}$' or (item->>'suspension_manual')::integer>100) then raise exception 'La suspensión debe ser automática o de 0 a 100 partidos.'; end if;
  insert into public.lm_penas_correcciones(partido_id,inscripcion_jugador_id,amarillas,roja_directa,suspension_manual)
  values(p.id,jugador,(item->>'ta')::integer,(item->>'tr')::boolean,(item->>'suspension_manual')::integer);
 end loop;
 -- Paquete por jugador/equipo, sin montos. No inserta ni modifica cobros.
 paquete:=jsonb_build_object('observaciones',trim(p_observaciones),'jugadores',(
  select coalesce(jsonb_agg(x),'[]'::jsonb) from jsonb_array_elements(public.lm_penas_revision_leer(p.id)->'jugadores') x
  where (x->>'ta')::integer>0 or (x->>'tr')::boolean or x->>'suspension_manual' is not null or (x->>'manual')::boolean
 ),'correcciones',p_correcciones);
 insert into public.lm_penas_historial(partido_id,revision,origen,datos,enviado,usuario_id) values(p.id,nueva,p_origen,paquete,p_enviar,auth.uid());
 return nueva;
end;
$$;

create or replace function public.lm_penas_envio_tesoreria(p_partido_id uuid,p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare liga text; h public.lm_penas_historial%rowtype; actual integer;
begin
 select c.liga_id::text into liga from public.campeonato_partidos p join public.campeonatos c on c.id=p.campeonato_id
 where p.id=p_partido_id and p_equipo_id in(p.equipo_local_id,p.equipo_visitante_id);
 if liga is null or auth.uid() is null or not coalesce(public.lm_es_superadmin() or public.lm_administra_liga(liga),false) then raise exception 'Solo la administración de esta liga puede consultar los envíos para tesorería.'; end if;
 select * into h from public.lm_penas_historial where partido_id=p_partido_id and enviado order by revision desc limit 1;
 if not found then return null; end if;
 select revision into actual from public.lm_penas_revisiones where partido_id=p_partido_id;
 return jsonb_build_object('revision',h.revision,'fecha',h.creado_en,'observaciones',h.datos->>'observaciones',
  'desactualizada',h.origen is distinct from public.lm_penas_origen(p_partido_id),
  'hay_revision_posterior',actual>h.revision,
  'jugadores',coalesce((select jsonb_agg(x) from jsonb_array_elements(h.datos->'jugadores') x where (x->>'equipo_id')::bigint=p_equipo_id),'[]'::jsonb));
end;
$$;
revoke all on function public.lm_penas_puede_gestionar(uuid),public.lm_penas_origen(uuid),public.lm_penas_calcular(uuid),public.lm_leer_sanciones_revisadas(uuid),public.lm_penas_revision_leer(uuid),public.lm_penas_revision_guardar(uuid,integer,text,text,jsonb,boolean),public.lm_penas_envio_tesoreria(uuid,bigint) from public,anon,authenticated;
grant execute on function public.lm_leer_sanciones_revisadas(uuid),public.lm_penas_revision_leer(uuid),public.lm_penas_revision_guardar(uuid,integer,text,text,jsonb,boolean),public.lm_penas_envio_tesoreria(uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;
