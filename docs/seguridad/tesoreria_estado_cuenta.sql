-- Tesorería acumulada. Ejecutar después de tesoreria_manual.sql.
-- No cambia vocalía ni sus cobros: utiliza exclusivamente el desglose publicado.
begin;
create table if not exists public.lm_tesoreria_movimientos (
  id uuid primary key,
  partido_id uuid not null,
  equipo_id bigint not null,
  tipo text not null check(tipo in ('aporte_equipo','pago_arbitro')),
  moneda text not null,
  centavos bigint not null check(centavos between 1 and 999999999),
  fecha date not null,
  referencia text not null default '',
  beneficiario text not null default '',
  comprobante text,
  creado_por uuid not null references auth.users(id),
  creado_en timestamptz not null default now(),
  anulado_en timestamptz,
  anulado_por uuid references auth.users(id),
  motivo_anulacion text,
  foreign key(partido_id,equipo_id) references public.lm_tesoreria_cobros(partido_id,equipo_id)
);
alter table public.lm_tesoreria_movimientos enable row level security;
revoke all on public.lm_tesoreria_movimientos from public,anon,authenticated;
create index if not exists lm_tesoreria_movimientos_por_equipo_partido
  on public.lm_tesoreria_movimientos(partido_id,equipo_id,fecha,creado_en);

create or replace function public.lm_tesoreria_catalogo(p_liga_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.lm_es_superadmin()
    or public.lm_administra_liga(p_liga_id::text),false) then
    raise exception 'Solo el administrador de esta liga puede abrir tesorería.';
  end if;
  return jsonb_build_object(
    'campeonatos',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,
      'nombre',c.nombre,'categoria',c.categoria) order by c.nombre,c.categoria)
      from public.campeonatos c where c.liga_id::text=p_liga_id::text),'[]'::jsonb),
    'equipos',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre)
      order by e.nombre) from public.equipos e where e.liga_id::text=p_liga_id::text),'[]'::jsonb)
  );
end; $$;

create or replace function public.lm_tesoreria_estado_cuenta(p_campeonato_id uuid,p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare liga uuid; administrador boolean;
begin
  select c.liga_id into liga from public.campeonatos c where c.id=p_campeonato_id;
  if not found then raise exception 'El campeonato no existe.'; end if;
  administrador:=auth.uid() is not null and coalesce(public.lm_es_superadmin()
    or public.lm_administra_liga(liga::text),false);
  if not administrador and not exists(select 1 from public.equipos e
    join public.perfiles p on p.id=auth.uid() and p.rol='club'
    where e.id=p_equipo_id and e.delegado_id=auth.uid() and e.liga_id::text=liga::text) then
    raise exception 'No tienes acceso a la tesorería de este equipo.';
  end if;
  if not exists(select 1 from public.equipos e where e.id=p_equipo_id
    and e.liga_id::text=liga::text) then raise exception 'El equipo no pertenece a esta liga.'; end if;
  return jsonb_build_object('puede_editar',administrador,'equipo_id',p_equipo_id,
    'liga',(select nombre from public.ligas where id=liga),
    'equipo',(select nombre from public.equipos where id=p_equipo_id),
    'campeonato',(select nombre from public.campeonatos where id=p_campeonato_id),
    'categoria',(select categoria from public.campeonatos where id=p_campeonato_id),
    'cobros',coalesce((select jsonb_agg(jsonb_build_object(
      'partido_id',p.id,'jornada',p.jornada,'numero_partido',p.numero_partido,'estado',p.estado,
      'fecha',coalesce(p.fecha_hora,t.publicado_en),'publicado_en',t.publicado_en,
      'local',el.nombre,'visitante',ev.nombre,'cobro',t.publicado,
      'movimientos',coalesce((select jsonb_agg(to_jsonb(m) order by m.fecha,m.creado_en,m.id)
        from public.lm_tesoreria_movimientos m where m.partido_id=p.id
          and m.equipo_id=p_equipo_id),'[]'::jsonb)
    ) order by coalesce(p.fecha_hora,t.publicado_en),p.numero_partido,p.id)
      from public.campeonato_partidos p
      left join public.lm_tesoreria_cobros t on t.partido_id=p.id and t.equipo_id=p_equipo_id
      join public.equipos el on el.id=p.equipo_local_id
      join public.equipos ev on ev.id=p.equipo_visitante_id
      where p.campeonato_id=p_campeonato_id
        and p_equipo_id in(p.equipo_local_id,p.equipo_visitante_id)),'[]'::jsonb));
end; $$;

create or replace function public.lm_tesoreria_vocal_puede_cobrar(p_partido_id uuid,p_equipo_id bigint)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and coalesce(public.lm_es_vocal(),false) and exists(
    select 1 from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id
    where p.id=p_partido_id and p_equipo_id in(p.equipo_local_id,p.equipo_visitante_id)
      and p.estado='programado' and c.activo=true and c.estado not in('finalizado','archivado')
      and not exists(select 1 from public.campeonato_resultados r
        where r.partido_id=p.id and r.estado='confirmado')
      and not exists(select 1 from public.campeonato_fases f
        where f.id=p.fase_id and f.estado='finalizada')
  );
$$;

create or replace function public.lm_tesoreria_cobranza_vocal(p_partido_id uuid,p_equipo_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare liga uuid; cobro jsonb;
begin
  select c.liga_id into liga from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id
    where p.id=p_partido_id and p_equipo_id in(p.equipo_local_id,p.equipo_visitante_id)
      ;
  if not found or auth.uid() is null or not coalesce(public.lm_es_vocal(),false) then
    raise exception 'Solo el vocal puede consultar la recaudación de este partido.';
  end if;
  select publicado into cobro from public.lm_tesoreria_cobros
    where partido_id=p_partido_id and equipo_id=p_equipo_id;
  return jsonb_build_object('liga_id',liga,'partido_id',p_partido_id,'equipo_id',p_equipo_id,
    'cobro',cobro,'puede_registrar',public.lm_tesoreria_vocal_puede_cobrar(p_partido_id,p_equipo_id),
    'movimientos',coalesce((select jsonb_agg(to_jsonb(m) order by m.fecha,m.creado_en)
      from public.lm_tesoreria_movimientos m where m.partido_id=p_partido_id
        and m.equipo_id=p_equipo_id),'[]'::jsonb));
end; $$;

create or replace function public.lm_tesoreria_registrar_movimiento(
  p_id uuid,p_partido_id uuid,p_equipo_id bigint,p_tipo text,p_moneda text,p_centavos bigint,
  p_fecha date,p_referencia text,p_beneficiario text,p_comprobante text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare liga uuid; cobro jsonb; anterior public.lm_tesoreria_movimientos%rowtype;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para registrar movimientos.'; end if;
  -- Mismo orden de bloqueo que el cierre de vocalía y la publicación del cobro.
  perform 1 from public.campeonato_partidos where id=p_partido_id for update;
  select c.liga_id into liga from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id where p.id=p_partido_id;
  if not found or auth.uid() is null or not coalesce(public.lm_es_superadmin()
    or public.lm_administra_liga(liga::text)
    or public.lm_tesoreria_vocal_puede_cobrar(p_partido_id,p_equipo_id),false) then
    raise exception 'Solo el administrador o el vocal de esta jornada pueden registrar movimientos.';
  end if;
  select publicado into cobro from public.lm_tesoreria_cobros
    where partido_id=p_partido_id and equipo_id=p_equipo_id for update;
  if cobro is null then raise exception 'Publica primero el cobro del equipo en este partido.'; end if;
  if p_moneda is distinct from cobro->>'moneda' then
    raise exception 'La moneda del cobro cambió. Actualiza tesorería y vuelve a registrar el movimiento.';
  end if;
  if p_id is null or p_tipo is null or p_tipo not in ('aporte_equipo','pago_arbitro')
    or p_centavos is null or p_centavos not between 1 and 999999999
    or p_fecha is null or p_fecha>current_date
    or coalesce(length(p_referencia),0)>300 or coalesce(length(p_beneficiario),0)>150 then
    raise exception 'Revisa el tipo, monto, fecha y referencia del movimiento.';
  end if;
  if p_tipo='pago_arbitro' and nullif(trim(p_beneficiario),'') is null then
    raise exception 'Indica el nombre del árbitro que recibió el dinero.';
  end if;
  if p_comprobante is not null and (split_part(p_comprobante,'/',1)<>liga::text
    or not (split_part(p_comprobante,'/',2)=p_id::text
      or (split_part(p_comprobante,'/',2)=p_partido_id::text
        and split_part(p_comprobante,'/',3)=p_equipo_id::text
        and split_part(p_comprobante,'/',4)=p_id::text))
    or not exists(select 1 from storage.objects where bucket_id='tesoreria_comprobantes'
      and name=p_comprobante)) then raise exception 'El comprobante no es válido.'; end if;
  -- Idempotencia: repetir una solicitud no registra un segundo pago.
  select * into anterior from public.lm_tesoreria_movimientos where id=p_id;
  if found then
    if anterior.partido_id=p_partido_id and anterior.equipo_id=p_equipo_id
      and anterior.tipo=p_tipo and anterior.centavos=p_centavos and anterior.fecha=p_fecha
      and anterior.referencia=coalesce(trim(p_referencia),'')
      and anterior.beneficiario=coalesce(trim(p_beneficiario),'')
      and anterior.comprobante is not distinct from p_comprobante
      and anterior.creado_por=auth.uid() then return anterior.id; end if;
    raise exception 'La referencia de guardado ya existe con otros datos.';
  end if;
  insert into public.lm_tesoreria_movimientos(id,partido_id,equipo_id,tipo,moneda,
    centavos,fecha,referencia,beneficiario,comprobante,creado_por)
    values(p_id,p_partido_id,p_equipo_id,p_tipo,cobro->>'moneda',p_centavos,
      p_fecha,coalesce(trim(p_referencia),''),coalesce(trim(p_beneficiario),''),p_comprobante,auth.uid());
  return p_id;
end; $$;

create or replace function public.lm_tesoreria_anular_movimiento(p_id uuid,p_motivo text)
returns void language plpgsql security definer set search_path='' as $$
declare liga uuid;
begin
  select c.liga_id into liga from public.lm_tesoreria_movimientos m
    join public.campeonato_partidos p on p.id=m.partido_id
    join public.campeonatos c on c.id=p.campeonato_id where m.id=p_id;
  if not found or auth.uid() is null or not coalesce(public.lm_es_superadmin()
    or public.lm_administra_liga(liga::text),false) then raise exception 'No puedes anular este movimiento.'; end if;
  if coalesce(length(trim(p_motivo)),0) not between 1 and 300 then
    raise exception 'Escribe el motivo de la anulación (máximo 300 caracteres).'; end if;
  update public.lm_tesoreria_movimientos set anulado_en=now(),anulado_por=auth.uid(),
    motivo_anulacion=trim(p_motivo) where id=p_id and anulado_en is null;
end; $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('tesoreria_comprobantes','tesoreria_comprobantes',false,5242880,
  array['image/png','image/jpeg','image/webp']) on conflict(id) do update set
    public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
-- Las rutas usan liga/UUID-de-movimiento/archivo. Solo su administrador puede acceder.
create or replace function public.lm_tesoreria_archivo_permitido(p_nombre text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.ligas l
    where l.id::text=split_part(p_nombre,'/',1)
      and coalesce(public.lm_es_superadmin() or public.lm_administra_liga(l.id::text),false));
$$;
create or replace function public.lm_tesoreria_archivo_vocal_permitido(p_nombre text)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  return exists(select 1 from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id
    where c.liga_id::text=split_part(p_nombre,'/',1)
      and p.id::text=split_part(p_nombre,'/',2)
      and public.lm_tesoreria_vocal_puede_cobrar(p.id,split_part(p_nombre,'/',3)::bigint));
exception when invalid_text_representation or numeric_value_out_of_range then return false;
end; $$;
drop policy if exists lm_tesoreria_comprobantes_leer on storage.objects;
create policy lm_tesoreria_comprobantes_leer on storage.objects for select to authenticated
  using(bucket_id='tesoreria_comprobantes' and (public.lm_tesoreria_archivo_permitido(name)
    or public.lm_tesoreria_archivo_vocal_permitido(name)));
drop policy if exists lm_tesoreria_comprobantes_subir on storage.objects;
create policy lm_tesoreria_comprobantes_subir on storage.objects for insert to authenticated
  with check(bucket_id='tesoreria_comprobantes' and (public.lm_tesoreria_archivo_permitido(name)
    or public.lm_tesoreria_archivo_vocal_permitido(name)));

revoke all on function public.lm_tesoreria_catalogo(uuid),
  public.lm_tesoreria_estado_cuenta(uuid,bigint),
  public.lm_tesoreria_registrar_movimiento(uuid,uuid,bigint,text,text,bigint,date,text,text,text),
  public.lm_tesoreria_anular_movimiento(uuid,text),
  public.lm_tesoreria_archivo_permitido(text) from public,anon,authenticated;
revoke all on function public.lm_tesoreria_vocal_puede_cobrar(uuid,bigint),
  public.lm_tesoreria_cobranza_vocal(uuid,bigint),
  public.lm_tesoreria_archivo_vocal_permitido(text) from public,anon,authenticated;
grant execute on function public.lm_tesoreria_catalogo(uuid),
  public.lm_tesoreria_estado_cuenta(uuid,bigint),
  public.lm_tesoreria_registrar_movimiento(uuid,uuid,bigint,text,text,bigint,date,text,text,text),
  public.lm_tesoreria_anular_movimiento(uuid,text),
  public.lm_tesoreria_archivo_permitido(text) to authenticated;
grant execute on function public.lm_tesoreria_vocal_puede_cobrar(uuid,bigint),
  public.lm_tesoreria_cobranza_vocal(uuid,bigint),
  public.lm_tesoreria_archivo_vocal_permitido(text) to authenticated;
notify pgrst,'reload schema';
commit;
