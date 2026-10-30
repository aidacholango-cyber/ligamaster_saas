-- Valida exclusivamente fecha de nacimiento/categoría al inscribir o editar.
-- No modifica jugadores existentes ni la revisión/calificación de sus fichas.
begin;
create or replace function public.lm_validar_edad_sub40()
returns trigger language plpgsql set search_path='' as $$
declare nacimiento date; edad integer;
begin
  if new.categoria is distinct from 'Sub 40' then return new; end if;
  if tg_op='UPDATE' then
    if new.fecha_nacimiento is not distinct from old.fecha_nacimiento
      and new.categoria is not distinct from old.categoria then return new; end if;
  end if;
  begin
    if new.fecha_nacimiento::text ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' then
      nacimiento:=to_date(new.fecha_nacimiento::text,'DD/MM/YYYY');
      if to_char(nacimiento,'DD/MM/YYYY')<>new.fecha_nacimiento::text then
        raise exception 'Fecha inválida';
      end if;
    else
      nacimiento:=new.fecha_nacimiento::text::date;
    end if;
  exception when others then
    raise exception 'Escribe una fecha de nacimiento válida.';
  end;
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
commit;
