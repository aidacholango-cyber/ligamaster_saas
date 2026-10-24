-- Diagnóstico: no cambia fichas, archivos, cuentas ni permisos.
-- La identidad simulada solo dura esta transacción y se descarta con ROLLBACK.
begin;
select set_config('request.jwt.claim.sub',coalesce((select id::text
  from auth.users where lower(email)='calificaciones2027@ligamaster.invalid'),''),true);

select jsonb_build_object(
  'comision_activa',public.lm_es_comision_calificaciones(),
  'permiso_select_storage',has_table_privilege('authenticated','storage.objects','SELECT'),
  'funcion_instalada',to_regprocedure('public.lm_comision_puede_leer_cedula(text)') is not null,
  'politicas', (select jsonb_agg(jsonb_build_object(
    'nombre',policyname,'tipo',permissive,'roles',roles,'operacion',cmd,'condicion',qual))
    from pg_policies where schemaname='storage' and tablename='objects'
      and cmd in ('SELECT','ALL')),
  'documento', (select jsonb_agg(jsonb_build_object(
    'referencia_guardada',coalesce(j.foto_cedula_url,'')<>'',
    'formato_reconocido',position('/storage/v1/object/public/cedulas_jugadores/' in coalesce(j.foto_cedula_url,''))>0,
    'archivo_existe',exists(select 1 from storage.objects o
      where o.bucket_id='cedulas_jugadores' and o.name=split_part(j.foto_cedula_url,
        '/storage/v1/object/public/cedulas_jugadores/',2)),
    'permiso_comision',public.lm_comision_puede_leer_cedula(split_part(j.foto_cedula_url,
        '/storage/v1/object/public/cedulas_jugadores/',2)),
    'inscrito_en_activo',exists(select 1 from public.campeonato_jugadores cj
      join public.campeonatos c on c.id=cj.campeonato_id
      where cj.jugador_id=j.id and cj.estado='inscrito' and c.activo=true)
  )) from public.jugadores j where j.cedula='1702364589')
) as diagnostico;
rollback;
