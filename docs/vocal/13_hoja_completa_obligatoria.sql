-- Requiere el módulo de calificación del árbitro (12).
-- Solo la hoja del vocal: conserva el ingreso manual del administrador.
-- No revalida ni modifica registros anteriores durante la instalación.
begin;
create or replace function public.lm_exigir_hoja_vocal_completa()
returns trigger language plpgsql security definer set search_path='' as $$
declare b public.lm_vocal_borradores%rowtype; p public.campeonato_partidos%rowtype;
  equipo bigint; control text; firma text;
begin
  if auth.uid() is null or not coalesce(public.lm_es_vocal(),false) then return null; end if;
  -- Las funciones actuales guardan jugadores, informes, controles y firmas en
  -- pasos de la misma transacción. Comprobar la fila final evita rechazar esos
  -- pasos intermedios y bloquea el guardado parcial al finalizar la transacción.
  select * into b from public.lm_vocal_borradores where partido_id=new.partido_id;
  if not found then return null; end if;
  select * into p from public.campeonato_partidos where id=b.partido_id;
  if nullif(trim(b.vocal),'') is null or nullif(trim(b.arbitro),'') is null then
    raise exception 'Completa los nombres del vocal y del árbitro antes de guardar.';
  end if;
  if nullif(trim(b.informe_vocal),'') is null or nullif(trim(b.informe_arbitral),'') is null then
    raise exception 'Completa el informe vocal y el informe arbitral antes de guardar.';
  end if;
  if nullif(trim(p.cancha),'') is null then raise exception 'Selecciona la cancha antes de guardar.'; end if;
  if b.calificacion_arbitro is null or b.calificacion_arbitro not in ('malo','bueno','excelente') then
    raise exception 'Selecciona la calificación del árbitro antes de guardar.';
  end if;
  foreach equipo in array array[p.equipo_local_id,p.equipo_visitante_id] loop
    foreach control in array array['balon','capitan','camerinos'] loop
      if b.controles_equipo->(equipo::text)->control is distinct from 'true'::jsonb then
        raise exception 'Marca Balón, Capitán y Camerinos de los dos equipos antes de guardar.';
      end if;
    end loop;
    if not exists(select 1 from jsonb_array_elements(b.jugadores) x
      join public.campeonato_jugadores cj on cj.id=(x->>'id')::uuid
      where cj.equipo_id=equipo) then
      raise exception 'Ingresa los jugadores participantes de ambos equipos antes de guardar.';
    end if;
  end loop;
  foreach firma in array array['capitan_local','capitan_visitante','vocal','arbitro'] loop
    if not exists(select 1 from jsonb_array_elements(
      case when jsonb_typeof(b.firmas->firma)='array' then b.firmas->firma else '[]'::jsonb end) trazo
      where jsonb_typeof(trazo)='array' and jsonb_array_length(trazo)>=2) then
      raise exception 'Completa las firmas de ambos capitanes, del vocal y del árbitro antes de guardar.';
    end if;
  end loop;
  return null;
end; $$;
revoke all on function public.lm_exigir_hoja_vocal_completa() from public,anon,authenticated;
drop trigger if exists lm_hoja_vocal_completa on public.lm_vocal_borradores;
create constraint trigger lm_hoja_vocal_completa
  after insert or update on public.lm_vocal_borradores
  deferrable initially deferred for each row
  execute function public.lm_exigir_hoja_vocal_completa();
commit;
