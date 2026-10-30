-- Valida automáticamente titulares. Sin reloj ni selección de tiempos.
-- Conserva guardado, firmas, publicación y funciones originales de vocal/admin.
begin;
create or replace function public.lm_nacimiento_regla(p_valor text)
returns date language plpgsql immutable set search_path='' as $$
declare fecha date;
begin
  if p_valor ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then
    fecha:=to_date(p_valor,'DD/MM/YYYY');
    if to_char(fecha,'DD/MM/YYYY')<>p_valor then return null; end if;
    return fecha;
  end if;
  return p_valor::date;
exception when others then return null;
end; $$;

create or replace function public.lm_validar_juvenil_vocalia()
returns trigger language plpgsql security definer set search_path='' as $$
declare categoria text; fecha date; fila jsonb; nacimiento date; juvenil boolean;
  equipo bigint; total integer; juveniles integer; filas jsonb:='[]';
begin
  select c.categoria,(p.fecha_hora at time zone 'America/Guayaquil')::date
    into categoria,fecha from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id where p.id=new.partido_id;
  if categoria not in ('Fútbol Senior','Femenino','Sub 40') then return new; end if;
  if jsonb_array_length(new.jugadores)>0 and fecha is null then
    raise exception 'Programa la fecha del partido para validar la edad del juvenil.';
  end if;
  for fila in select value from jsonb_array_elements(new.jugadores) loop
    select cj.equipo_id,public.lm_nacimiento_regla(j.fecha_nacimiento::text)
      into equipo,nacimiento from public.campeonato_jugadores cj
      join public.jugadores j on j.id=cj.jugador_id where cj.id=(fila->>'id')::uuid;
    if nacimiento is null or nacimiento>fecha then
      raise exception 'Un jugador no tiene fecha de nacimiento válida. Corrige su ficha.';
    end if;
    if categoria='Sub 40' and extract(year from fecha)-extract(year from nacimiento)<38 then
      raise exception 'Sub 40 solo admite jugadores de 39 años en adelante y la excepción de 38 años.';
    end if;
    juvenil:=case when categoria='Sub 40' then extract(year from fecha)-extract(year from nacimiento)=38
      else extract(year from age(fecha,nacimiento))<18 end;
    filas:=filas||jsonb_build_array(fila||jsonb_build_object('equipo_id',equipo,'juvenil',juvenil));
  end loop;
  for equipo in select distinct (x->>'equipo_id')::bigint from jsonb_array_elements(filas) x loop
    select count(*),count(*) filter(where (x->>'juvenil')::boolean) into total,juveniles
      from jsonb_array_elements(filas) x where (x->>'equipo_id')::bigint=equipo
        and coalesce(x->>'tipo','titular')='titular';
    if total>10 and juveniles=0 then
      raise exception 'Para jugar con 11 titulares debe estar el juvenil: menor de 18; en Sub 40, uno de 38. Sin él se permiten 10 titulares.';
    end if;
    if categoria='Sub 40' then
      if juveniles>1 then
        raise exception 'Sub 40 permite máximo un jugador de 38 años en cancha a la vez.';
      end if;
      select count(*) into juveniles from jsonb_array_elements(filas) x
        where (x->>'equipo_id')::bigint=equipo and (x->>'juvenil')::boolean
          and not exists(select 1 from jsonb_array_elements(filas) s
            where (s->>'equipo_id')::bigint=equipo and s->>'sale_id'=x->>'id');
      if juveniles>1 then
        raise exception 'Sub 40 permite máximo un jugador de 38 años en cancha a la vez. Indica quién sale.';
      end if;
    end if;
  end loop;
  return new;
end; $$;
-- Se comprueba también al guardar desde funciones anteriores o ingreso manual.
-- No modifica ni revalida retroactivamente las planillas ya cerradas.
drop trigger if exists lm_regla_juvenil_vocalia on public.lm_vocal_borradores;
create trigger lm_regla_juvenil_vocalia before insert or update of jugadores
  on public.lm_vocal_borradores for each row execute function public.lm_validar_juvenil_vocalia();

create or replace function public.lm_vocal_regla_datos(p_partido_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare categoria text;
begin
  if auth.uid() is null or not (coalesce(public.lm_es_vocal(),false)
    or coalesce(public.lm_admin_puede_cargar_vocalia(p_partido_id),false)) then
    raise exception 'No tienes permiso para consultar esta planilla.';
  end if;
  select c.categoria into categoria from public.campeonato_partidos p
    join public.campeonatos c on c.id=p.campeonato_id where p.id=p_partido_id;
  if not found then raise exception 'El partido no existe.'; end if;
  return jsonb_build_object('categoria',categoria,
    'nacimientos',coalesce((select jsonb_object_agg(cj.id::text,j.fecha_nacimiento)
      from public.campeonato_partidos p join public.campeonato_jugadores cj
        on cj.campeonato_id=p.campeonato_id and cj.equipo_id in(p.equipo_local_id,p.equipo_visitante_id)
      join public.jugadores j on j.id=cj.jugador_id where p.id=p_partido_id),'{}'::jsonb));
end; $$;
revoke all on function public.lm_nacimiento_regla(text),public.lm_validar_juvenil_vocalia(),
  public.lm_vocal_regla_datos(uuid) from public,anon,authenticated;
grant execute on function public.lm_vocal_regla_datos(uuid),public.lm_nacimiento_regla(text) to authenticated;

-- Permite inscribir la excepción de 38; la hoja controla el máximo en cancha.
create or replace function public.lm_validar_edad_sub40()
returns trigger language plpgsql set search_path='' as $$
declare nacimiento date; edad integer;
begin
  if new.categoria is distinct from 'Sub 40' then return new; end if;
  if tg_op='UPDATE' then
    if new.fecha_nacimiento is not distinct from old.fecha_nacimiento
      and new.categoria is not distinct from old.categoria then return new; end if;
  end if;
  nacimiento:=public.lm_nacimiento_regla(new.fecha_nacimiento::text);
  if nacimiento is null or nacimiento>current_date or nacimiento<date '1900-01-01' then
    raise exception 'Escribe una fecha de nacimiento válida.';
  end if;
  edad:=extract(year from current_date)::integer-extract(year from nacimiento)::integer;
  if edad<38 then
    raise exception 'No puede ingresar en Sub 40: tiene % años por año de nacimiento. Se admiten desde 39 años y la excepción de 38 años.',edad;
  end if;
  return new;
end; $$;
drop trigger if exists lm_validar_edad_sub40 on public.jugadores;
create trigger lm_validar_edad_sub40 before insert or update on public.jugadores
  for each row execute function public.lm_validar_edad_sub40();
notify pgrst,'reload schema';
commit;
