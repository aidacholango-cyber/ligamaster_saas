-- Tesorería manual por equipo y partido. Ejecutar completo en SQL Editor.
-- No modifica resultados, tarjetas, fichas ni reglas deportivas.
begin;
create table if not exists public.lm_tesoreria_cobros (
  partido_id uuid not null references public.campeonato_partidos(id) on delete restrict,
  equipo_id bigint not null references public.equipos(id) on delete restrict,
  borrador jsonb,
  publicado jsonb,
  revision integer not null default 1,
  actualizado_por uuid not null,
  actualizado_en timestamptz not null default now(),
  publicado_en timestamptz,
  primary key(partido_id,equipo_id)
);
create table if not exists public.lm_tesoreria_historial (
  id bigint generated always as identity primary key,
  partido_id uuid not null,
  equipo_id bigint not null,
  revision integer not null,
  cobro jsonb not null,
  publicado boolean not null,
  usuario_id uuid not null,
  creado_en timestamptz not null default now()
);
alter table public.lm_tesoreria_cobros enable row level security;
alter table public.lm_tesoreria_historial enable row level security;
revoke all on public.lm_tesoreria_cobros,public.lm_tesoreria_historial from public,anon,authenticated;

create or replace function public.lm_tesoreria_leer(p_partido_id uuid,p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_liga uuid; v_admin boolean;
  v_c public.lm_tesoreria_cobros%rowtype; v_equipo text;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para consultar tesorería.'; end if;
  select * into v_p from public.campeonato_partidos where id=p_partido_id;
  if not found then raise exception 'El partido no existe.'; end if;
  if p_equipo_id is null or p_equipo_id not in (v_p.equipo_local_id,v_p.equipo_visitante_id) then
    raise exception 'El equipo no participa en este partido.';
  end if;
  select liga_id into v_liga from public.campeonatos where id=v_p.campeonato_id;
  v_admin:=coalesce(public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text),false);
  if not v_admin and not coalesce(public.lm_es_vocal(),false) and not exists(
    select 1 from public.equipos e join public.perfiles p on p.id=auth.uid()
    where e.id=p_equipo_id and e.delegado_id=auth.uid() and p.rol='club'
  ) then raise exception 'Solo puedes consultar cobros de tu equipo.'; end if;
  select nombre into v_equipo from public.equipos where id=p_equipo_id;
  select * into v_c from public.lm_tesoreria_cobros where partido_id=p_partido_id and equipo_id=p_equipo_id;
  return jsonb_build_object('equipo',v_equipo,'puede_editar',v_admin,
    'revision',case when v_admin then coalesce(v_c.revision,0) else null end,
    'borrador',case when v_admin then v_c.borrador else null end,
    'publicado',v_c.publicado,'publicado_en',v_c.publicado_en);
end; $$;

create or replace function public.lm_tesoreria_guardar(
  p_partido_id uuid,p_equipo_id bigint,p_revision integer,p_publicar boolean,p_cobro jsonb
) returns integer language plpgsql security definer set search_path='' as $$
declare v_p public.campeonato_partidos%rowtype; v_liga uuid; v_actual integer;
  v_item jsonb; v_items jsonb:='[]'::jsonb; v_tipo text; v_centavos bigint;
  v_moneda text; v_normalizado jsonb; v_total bigint:=0; v_nueva integer;
begin
  if auth.uid() is null then raise exception 'Inicia sesión con tu cuenta de administrador.'; end if;
  -- Bloquea el partido para serializar altas y evitar publicar sobre una versión obsoleta.
  select * into v_p from public.campeonato_partidos where id=p_partido_id for update;
  if not found then raise exception 'El partido no existe.'; end if;
  select liga_id into v_liga from public.campeonatos where id=v_p.campeonato_id;
  if not coalesce(public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text),false) then
    raise exception 'Solo el administrador de esta liga puede ingresar y publicar cobros.';
  end if;
  if p_equipo_id is null or p_equipo_id not in (v_p.equipo_local_id,v_p.equipo_visitante_id) then
    raise exception 'El equipo no participa en este partido.';
  end if;
  if p_publicar is null then raise exception 'Selecciona guardar borrador o publicar.'; end if;
  if p_cobro is null or jsonb_typeof(p_cobro)<>'object' then raise exception 'El cobro no es válido.'; end if;
  v_moneda:=upper(trim(p_cobro->>'moneda'));
  if v_moneda is null or not (v_moneda ~ '^[A-Z]{3}$' or v_moneda in ('$', '€', '£')) then
    raise exception 'Ingresa una moneda de tres letras o un símbolo: $, € o £.';
  end if;
  if jsonb_typeof(p_cobro->'items') is distinct from 'array' then raise exception 'El desglose debe ser una lista.'; end if;
  if jsonb_array_length(p_cobro->'items') not between 1 and 100 then
    raise exception 'Ingresa entre 1 y 100 conceptos, incluso si el monto es cero.';
  end if;
  for v_item in select value from jsonb_array_elements(p_cobro->'items') loop
    v_tipo:=v_item->>'tipo';
    if v_tipo is null or v_tipo not in ('arbitraje','mantenimiento','ta','tr','otro') then
      raise exception 'El concepto de cobro no es válido.';
    end if;
    if jsonb_typeof(v_item->'centavos') is distinct from 'number'
      or coalesce(v_item->>'centavos','') !~ '^[0-9]{1,9}$' then
      raise exception 'El monto debe ser positivo o cero y expresado en centavos enteros.';
    end if;
    v_centavos:=(v_item->>'centavos')::bigint;
    if v_tipo in ('ta','tr') and coalesce(v_item->>'camiseta','') !~ '^[0-9]{1,3}$' then
      raise exception 'Indica el número del jugador sancionado.';
    end if;
    if v_tipo='otro' and length(trim(coalesce(v_item->>'concepto',''))) not between 1 and 150 then
      raise exception 'Describe el cobro adicional (máximo 150 caracteres).';
    end if;
    -- Solo valores manuales: no consulta ni convierte tarjetas en importes.
    v_items:=v_items||jsonb_build_array(jsonb_build_object(
      'tipo',v_tipo,'centavos',v_centavos,
      'camiseta',case when v_tipo in ('ta','tr') then v_item->>'camiseta' else null end,
      'concepto',case when v_tipo='otro' then trim(v_item->>'concepto') else null end));
    v_total:=v_total+v_centavos;
  end loop;
  v_normalizado:=jsonb_build_object('moneda',v_moneda,'items',v_items,'total_centavos',v_total);
  select revision into v_actual from public.lm_tesoreria_cobros
    where partido_id=p_partido_id and equipo_id=p_equipo_id for update;
  if p_revision is distinct from coalesce(v_actual,0) then
    raise exception 'El cobro cambió en otra sesión. Cierra el detalle y actualiza antes de editar.';
  end if;
  v_nueva:=coalesce(v_actual,0)+1;
  insert into public.lm_tesoreria_cobros(partido_id,equipo_id,borrador,publicado,revision,actualizado_por,publicado_en)
    values(p_partido_id,p_equipo_id,case when not p_publicar then v_normalizado end,
      case when p_publicar then v_normalizado end,v_nueva,auth.uid(),case when p_publicar then now() end)
  on conflict(partido_id,equipo_id) do update
    set borrador=case when p_publicar then null else v_normalizado end,
        publicado=case when p_publicar then v_normalizado else public.lm_tesoreria_cobros.publicado end,
        revision=v_nueva,actualizado_por=auth.uid(),actualizado_en=now(),
        publicado_en=case when p_publicar then now() else public.lm_tesoreria_cobros.publicado_en end;
  insert into public.lm_tesoreria_historial(partido_id,equipo_id,revision,cobro,publicado,usuario_id)
    values(p_partido_id,p_equipo_id,v_nueva,v_normalizado,p_publicar,auth.uid());
  return v_nueva;
end; $$;

create or replace function public.lm_tesoreria_partidos_equipo(p_campeonato_id uuid,p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_liga uuid;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para consultar tesorería.'; end if;
  select liga_id into v_liga from public.campeonatos where id=p_campeonato_id;
  if not found then raise exception 'El campeonato no existe.'; end if;
  if not coalesce(public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text),false)
    and not exists(select 1 from public.equipos e join public.perfiles p on p.id=auth.uid()
      where e.id=p_equipo_id and e.delegado_id=auth.uid() and p.rol='club') then
    raise exception 'Solo puedes consultar cobros de tu equipo.';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'jornada',p.jornada,
    'local',el.nombre,'visitante',ev.nombre) order by p.jornada desc,p.numero_partido desc)
    from public.campeonato_partidos p
    join public.equipos el on el.id=p.equipo_local_id
    join public.equipos ev on ev.id=p.equipo_visitante_id
    where p.campeonato_id=p_campeonato_id and p_equipo_id in(p.equipo_local_id,p.equipo_visitante_id)), '[]'::jsonb);
end; $$;
revoke all on function public.lm_tesoreria_leer(uuid,bigint),
  public.lm_tesoreria_guardar(uuid,bigint,integer,boolean,jsonb),
  public.lm_tesoreria_partidos_equipo(uuid,bigint) from public,anon,authenticated;
grant execute on function public.lm_tesoreria_leer(uuid,bigint),
  public.lm_tesoreria_guardar(uuid,bigint,integer,boolean,jsonb),
  public.lm_tesoreria_partidos_equipo(uuid,bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
