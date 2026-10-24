-- Ejecutar después de 01 y antes de 02. Basado en el trigger real proporcionado.
-- No amplía lm_administra_equipo: la comisión no se convierte en administrador.
begin;
create table if not exists public.lm_comision_auditoria (
  id bigint generated always as identity primary key,
  usuario_id uuid not null references auth.users(id),
  campeonato_id uuid not null references public.campeonatos(id),
  jugador_id uuid not null references public.jugadores(id),
  accion text not null check(accion in ('revision','calificacion')),
  creado_en timestamptz not null default now()
);
alter table public.lm_comision_auditoria enable row level security;
revoke all on public.lm_comision_auditoria from public,anon,authenticated;
revoke all on sequence public.lm_comision_auditoria_id_seq from public,anon,authenticated;

create or replace function public.lm_controlar_revision_jugador()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  campos_revision text[] := array['estado','observaciones','fecha_revision',
    'revisado_por','revisado_por_id','fecha_calificacion','calificado_por','calificado_por_id'];
  cambio_revision boolean;
  cambio_datos boolean;
  nombre_admin text;
  es_comision boolean := false;
  campeonato_comision uuid;
begin
  if tg_op='INSERT' then
    if coalesce(new.estado,'Inscrito')<>'Inscrito'
      or nullif(btrim(new.observaciones),'') is not null then
      raise exception 'Un jugador nuevo debe ingresar como Inscrito, sin revisión ni calificación.';
    end if;
    new.estado:='Inscrito'; new.observaciones:=null; new.fecha_revision:=null;
    new.revisado_por:=null; new.revisado_por_id:=null;
    new.fecha_calificacion:=null; new.calificado_por:=null; new.calificado_por_id:=null;
    return new;
  end if;
  cambio_revision:=row(new.estado,new.observaciones,new.fecha_revision,
    new.revisado_por,new.revisado_por_id,new.fecha_calificacion,new.calificado_por,new.calificado_por_id)
    is distinct from row(old.estado,old.observaciones,old.fecha_revision,
    old.revisado_por,old.revisado_por_id,old.fecha_calificacion,old.calificado_por,old.calificado_por_id);
  cambio_datos:=(to_jsonb(new)-campos_revision) is distinct from (to_jsonb(old)-campos_revision);
  if cambio_revision then
    campeonato_comision:=nullif(current_setting('ligamaster.comision_campeonato',true),'')::uuid;
    -- Permiso exclusivamente para fichas participantes del campeonato de la RPC.
    es_comision:=campeonato_comision is not null
      and public.lm_comision_equipo_permitido(campeonato_comision,old.equipo_id)
      and exists(select 1 from public.campeonato_jugadores cj
        join public.campeonatos c on c.id=cj.campeonato_id
        where cj.campeonato_id=campeonato_comision and cj.jugador_id=old.id
          and cj.equipo_id=old.equipo_id and cj.estado='inscrito' and c.categoria=old.categoria);
    if not public.lm_administra_equipo(old.equipo_id) and not es_comision then
      raise exception 'Solo el administrador de esta liga puede revisar, calificar y cambiar las observaciones.';
    end if;
    if cambio_datos then
      raise exception 'Guarda primero los datos del jugador y después realiza la revisión.';
    end if;
    -- Se conserva el nombre del administrador responsable de cada liga.
    -- El ID autenticado y la auditoría identifican a quien hizo la acción.
    select coalesce(nullif(btrim(p.nombre),''),nullif(btrim(l.admin_nombre),''))
      into nombre_admin from public.equipos e
      join public.ligas l on l.id::text=e.liga_id::text
      join public.perfiles p on p.id=l.admin_id
      where e.id=old.equipo_id and (p.id=auth.uid() or es_comision) and p.rol='admin';
    if nombre_admin is null then
      raise exception 'Falta el nombre del administrador. Debe registrarlo el superadministrador.';
    end if;
    if new.estado='Revisado' then
      if nullif(btrim(new.observaciones),'') is null then
        raise exception 'Escribe las observaciones. Si todo está correcto, escribe: Sin observaciones.';
      end if;
      if char_length(new.observaciones)>4000 then
        raise exception 'Las observaciones no pueden superar 4000 caracteres.';
      end if;
      new.observaciones:=btrim(new.observaciones); new.fecha_revision:=now();
      new.revisado_por:=nombre_admin; new.revisado_por_id:=auth.uid();
      new.fecha_calificacion:=null; new.calificado_por:=null; new.calificado_por_id:=null;
    elsif new.estado='Calificado' then
      if old.estado<>'Revisado' or old.fecha_revision is null
        or old.revisado_por_id is null or nullif(btrim(old.observaciones),'') is null then
        raise exception 'Primero revisa al jugador y guarda las observaciones.';
      end if;
      if new.observaciones is distinct from old.observaciones then
        raise exception 'Guarda los cambios de observaciones como una nueva revisión antes de calificar.';
      end if;
      new.observaciones:=old.observaciones; new.fecha_revision:=old.fecha_revision;
      new.revisado_por:=old.revisado_por; new.revisado_por_id:=old.revisado_por_id;
      new.fecha_calificacion:=now(); new.calificado_por:=nombre_admin;
      new.calificado_por_id:=auth.uid();
    else
      raise exception 'Para cambiar el seguimiento utiliza Revisado o Calificado.';
    end if;
  elsif cambio_datos then
    new.estado:='Inscrito'; new.observaciones:=null; new.fecha_revision:=null;
    new.revisado_por:=null; new.revisado_por_id:=null;
    new.fecha_calificacion:=null; new.calificado_por:=null; new.calificado_por_id:=null;
  end if;
  return new;
end; $$;
commit;
