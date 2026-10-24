-- Actualiza escudos y limita la comisión a campeonatos activos.
begin;
create or replace function public.lm_comision_equipo_permitido(
  p_campeonato_id uuid, p_equipo_id bigint
) returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.lm_comision_calificaciones a
    cross join public.campeonatos c
    join public.campeonato_equipos ce on ce.campeonato_id=c.id
    join public.equipos e on e.id=ce.equipo_id and e.liga_id::text=c.liga_id::text
    where a.usuario_id=auth.uid() and a.activo
      and c.id=p_campeonato_id and c.activo=true
      and ce.equipo_id=p_equipo_id and ce.estado='inscrito'
  );
$$;

create or replace function public.lm_comision_equipos()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.lm_es_comision_calificaciones() then
    raise exception 'La cuenta no tiene una comisión de calificaciones activa.';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'campeonato_id',c.id,'campeonato',c.nombre,'categoria',c.categoria,'activo',c.activo,
    'liga',l.nombre,'equipo_id',e.id,'equipo',e.nombre,
    'escudo_url',to_jsonb(e)->>'escudo_url','logo_url',to_jsonb(e)->>'logo_url'
  ) order by c.nombre,c.categoria,e.nombre)
    from public.lm_comision_calificaciones a
    cross join public.campeonatos c
    join public.ligas l on l.id::text=c.liga_id::text
    join public.campeonato_equipos ce on ce.campeonato_id=c.id and ce.estado='inscrito'
    join public.equipos e on e.id=ce.equipo_id and e.liga_id::text=c.liga_id::text
    where a.usuario_id=auth.uid() and a.activo and c.activo=true),'[]'::jsonb);
end;
$$;

commit;
