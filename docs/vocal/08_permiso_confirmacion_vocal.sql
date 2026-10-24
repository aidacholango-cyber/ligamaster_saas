-- Ajusta exclusivamente el permiso para confirmar desde el flujo del vocal.
-- Conserva las validaciones y el permiso de reapertura originales.
-- No confirma partidos ni modifica planillas, firmas, cobros o resultados existentes.
begin;
CREATE OR REPLACE FUNCTION public.lm_validar_confirmacion_resultado()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  partido public.campeonato_partidos%rowtype;
  tipo_fase text;
  goles_planilla_local bigint;
  goles_planilla_visitante bigint;
begin
  if tg_op = 'UPDATE' then
    if new.partido_id is distinct from old.partido_id then
      raise exception
        'No se puede trasladar el resultado a otro partido.';
    end if;
  end if;

  select p.*
    into partido
  from public.campeonato_partidos p
  where p.id = new.partido_id
  for update;

  if not found then
    raise exception
      'El partido no existe o no tienes acceso.';
  end if;

  if tg_op = 'UPDATE' then
    if old.estado = 'confirmado' then

      if auth.uid() is null or not exists (
        select 1
        from public.campeonatos c
        where c.id = partido.campeonato_id
          and (
            public.lm_es_superadmin()
            or public.lm_administra_liga(c.liga_id::text)
          )
      ) then
        raise exception
          'No tienes permiso para reabrir este resultado.';
      end if;

      if new.estado <> 'borrador' then
        raise exception
          'Primero debes reabrir el resultado para corregirlo.';
      end if;

      if new.motivo_reapertura is null
         or length(btrim(new.motivo_reapertura))
            not between 10 and 1000 then
        raise exception
          'Escribe un motivo de reapertura de entre 10 y 1000 caracteres.';
      end if;

      -- Reabrir y modificar el marcador son pasos separados.
      if (
        to_jsonb(new) - array[
          'estado',
          'confirmado_por',
          'confirmado_en',
          'motivo_reapertura'
        ]
      ) is distinct from (
        to_jsonb(old) - array[
          'estado',
          'confirmado_por',
          'confirmado_en',
          'motivo_reapertura'
        ]
      ) then
        raise exception
          'Reabre primero el resultado y después corrige el marcador.';
      end if;

      new.motivo_reapertura := btrim(new.motivo_reapertura);
      new.confirmado_por := null;
      new.confirmado_en := null;
      return new;
    end if;
  end if;

  new.motivo_reapertura := null;

  if new.estado = 'borrador' then
    new.confirmado_por := null;
    new.confirmado_en := null;
    return new;
  end if;

  if auth.uid() is null then
    raise exception
      'La confirmación requiere una cuenta con sesión iniciada.';
  end if;

  if not exists (
    select 1
    from public.campeonatos c
    where c.id = partido.campeonato_id
      and (
        public.lm_es_superadmin()
        or public.lm_administra_liga(c.liga_id::text)
        or (
          coalesce(public.lm_es_vocal(), false)
          -- Solo dentro del flujo privilegiado de publicación existente.
          -- Una actualización directa con el rol authenticated no basta.
          and current_user = (
            select pg_catalog.pg_get_userbyid(p.proowner)
            from pg_catalog.pg_proc p
            where p.oid = 'public.lm_vocal_finalizar(uuid,text,text,jsonb,integer)'::regprocedure
          )
        )
      )
  ) then
    raise exception
      'No tienes permiso para confirmar este partido.';
  end if;

  if partido.estado <> 'programado' then
    raise exception
      'No se puede confirmar un partido aplazado o cancelado.';
  end if;

  if not exists (
    select 1
    from public.campeonato_planillas pl
    where pl.partido_id = partido.id
      and pl.equipo_id = partido.equipo_local_id
      and pl.participo
  ) or not exists (
    select 1
    from public.campeonato_planillas pl
    where pl.partido_id = partido.id
      and pl.equipo_id = partido.equipo_visitante_id
      and pl.participo
  ) then
    raise exception
      'Registra los jugadores que participaron por ambos equipos.';
  end if;

  select
    coalesce(sum(
      case
        when pl.equipo_id = partido.equipo_local_id
          then pl.goles::bigint
        else pl.autogoles::bigint
      end
    ), 0),
    coalesce(sum(
      case
        when pl.equipo_id = partido.equipo_visitante_id
          then pl.goles::bigint
        else pl.autogoles::bigint
      end
    ), 0)
  into goles_planilla_local, goles_planilla_visitante
  from public.campeonato_planillas pl
  where pl.partido_id = partido.id;

  if goles_planilla_local <>
       new.goles_local::bigint
       + coalesce(new.prorroga_local, 0)::bigint
     or goles_planilla_visitante <>
       new.goles_visitante::bigint
       + coalesce(new.prorroga_visitante, 0)::bigint then
    raise exception
      'Los goles de las planillas no coinciden con el marcador.';
  end if;

  select f.tipo
    into tipo_fase
  from public.campeonato_fases f
  where f.id = partido.fase_id;

  if tipo_fase = 'eliminatoria'
     and (
       new.goles_local::bigint
       + coalesce(new.prorroga_local, 0)::bigint
       =
       new.goles_visitante::bigint
       + coalesce(new.prorroga_visitante, 0)::bigint
     )
     and new.penales_local is null then
    raise exception
      'La eliminatoria sigue empatada. Registra la prórroga y la tanda de penales.';
  end if;

  new.confirmado_por := auth.uid();
  new.confirmado_en := now();

  return new;
end;
$function$
;
commit;
