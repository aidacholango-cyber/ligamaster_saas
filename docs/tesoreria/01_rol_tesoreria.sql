-- Ejecutar completo en SQL Editor, después de instalar los módulos de tesorería.
-- No crea ni modifica usuarios Auth, perfiles ni permisos fuera de Tesorería.
begin;
create table if not exists public.lm_usuarios_tesoreria (
 usuario_id uuid primary key references auth.users(id) on delete cascade,
 activo boolean not null default true
);
alter table public.lm_usuarios_tesoreria enable row level security;
revoke all on public.lm_usuarios_tesoreria from public,anon,authenticated;

create or replace function public.lm_es_tesoreria()
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(
  select 1 from public.lm_usuarios_tesoreria where usuario_id=auth.uid() and activo
 );
$$;
revoke all on function public.lm_es_tesoreria() from public,anon,authenticated;
grant execute on function public.lm_es_tesoreria() to authenticated;

-- Guardar la definición instalada y ampliar SOLO los controles de estos RPC
-- financieros. Así se conservan sus validaciones, versiones, moneda e historial,
-- incluyendo cualquier ajuste posterior del administrador instalado en la base.
create table if not exists public.lm_tesoreria_respaldo_funciones (
 firma text primary key,
 definicion text not null,
 respaldado_en timestamptz not null default now()
);
alter table public.lm_tesoreria_respaldo_funciones enable row level security;
revoke all on public.lm_tesoreria_respaldo_funciones from public,anon,authenticated;

do $$
declare firma text; funcion regprocedure; definicion text; opcional boolean;
begin
 foreach firma in array array[
  'public.lm_tesoreria_catalogo(uuid)',
  'public.lm_tesoreria_estado_cuenta(uuid,bigint)',
  'public.lm_tesoreria_leer(uuid,bigint)',
  'public.lm_tesoreria_guardar(uuid,bigint,integer,boolean,jsonb)',
  'public.lm_tesoreria_registrar_movimiento(uuid,uuid,bigint,text,text,bigint,date,text,text,text)',
  'public.lm_tesoreria_anular_movimiento(uuid,text)',
  'public.lm_tesoreria_archivo_permitido(text)',
  'public.lm_tesoreria_partidos_equipo(uuid,bigint)',
  'public.lm_penas_envio_tesoreria(uuid,bigint)'
 ] loop
  opcional:=firma in ('public.lm_tesoreria_partidos_equipo(uuid,bigint)','public.lm_penas_envio_tesoreria(uuid,bigint)');
  funcion:=to_regprocedure(firma);
  if funcion is null then
   if opcional then continue; end if;
   raise exception 'Falta instalar la función %. Instala primero Tesorería manual y Estados de cuenta.',firma;
  end if;
  select pg_get_functiondef(funcion::oid) into definicion;
  if position('public.lm_es_tesoreria()' in definicion)>0 then continue; end if;
  if position('public.lm_es_superadmin()' in definicion)=0 or position('public.lm_administra_liga(' in definicion)=0 then
   raise exception 'La función % tiene una autorización diferente. No se modificó; solicita revisar su definición actual.',firma;
  end if;
  insert into public.lm_tesoreria_respaldo_funciones(firma,definicion) values(firma,definicion) on conflict(firma) do nothing;
  execute replace(definicion,'public.lm_es_superadmin()','(public.lm_es_superadmin() or public.lm_es_tesoreria())');
 end loop;
end;
$$;

create or replace function public.lm_tesoreria_ligas()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.lm_es_tesoreria() then raise exception 'Esta cuenta no tiene acceso a Tesorería.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'nombre',nombre) order by nombre,id) from public.ligas),'[]'::jsonb);
end;
$$;

create or replace function public.lm_tesoreria_operador_catalogo(p_liga_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare catalogo jsonb;
begin
 if not public.lm_es_tesoreria() then raise exception 'Esta cuenta no tiene acceso a Tesorería.'; end if;
 if not exists(select 1 from public.ligas where id=p_liga_id) then raise exception 'La liga no existe.'; end if;
 catalogo:=public.lm_tesoreria_catalogo(p_liga_id);
 return jsonb_set(catalogo,'{campeonatos}',coalesce((select jsonb_agg(x||jsonb_build_object('grupo_campeonato_id',coalesce(to_jsonb(c)->>'grupo_campeonato_id',c.id::text)))
   from jsonb_array_elements(catalogo->'campeonatos') x join public.campeonatos c on c.id::text=x->>'id'
   where c.liga_id::text=p_liga_id::text),'[]'::jsonb));
end;
$$;
revoke all on function public.lm_tesoreria_ligas(),public.lm_tesoreria_operador_catalogo(uuid) from public,anon,authenticated;
grant execute on function public.lm_tesoreria_ligas(),public.lm_tesoreria_operador_catalogo(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
