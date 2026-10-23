-- Prueba de SELECT/RLS con un delegado real, sin cambiar cuentas ni archivos.
-- Ejecutar completo en SQL Editor como postgres. Toda configuración es local
-- a la transacción y se descarta con ROLLBACK.
BEGIN;

DO $$
DECLARE
  v_usuario uuid;
  v_otro uuid;
  v_propia text;
  v_ajena text;
BEGIN
  SELECT e.delegado_id INTO v_usuario
  FROM public.equipos e JOIN public.perfiles p ON p.id=e.delegado_id
  WHERE e.id=19 AND p.rol='club';
  SELECT e.delegado_id INTO v_otro
  FROM public.equipos e JOIN public.perfiles p ON p.id=e.delegado_id
  WHERE e.id=20 AND p.rol='club';
  IF v_usuario IS NULL OR v_otro IS NULL OR v_usuario=v_otro THEN
    RAISE EXCEPTION 'La prueba requiere delegados distintos de equipos 19 y 20. No se cambió ningún dato.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated' AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'El rol authenticated omite RLS. No es válida esta prueba.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='storage' AND c.relname='objects' AND c.relrowsecurity) THEN
    RAISE EXCEPTION 'Storage objects no tiene RLS habilitado.';
  END IF;
  SELECT name INTO v_propia FROM storage.objects
    WHERE bucket_id='cedulas_jugadores' AND split_part(name,'/',1)='19'
    ORDER BY name LIMIT 1;
  SELECT name INTO v_ajena FROM storage.objects
    WHERE bucket_id='cedulas_jugadores' AND split_part(name,'/',1)='20'
    ORDER BY name LIMIT 1;
  IF v_propia IS NULL OR v_ajena IS NULL THEN
    RAISE EXCEPTION 'Falta un archivo existente para uno de los equipos; no se puede acreditar el bloqueo.';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_usuario::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_usuario,'role','authenticated')::text,true);
  PERFORM set_config('ligamaster.prueba_propia',v_propia,true);
  PERFORM set_config('ligamaster.prueba_ajena',v_ajena,true);
END $$;

SET LOCAL ROLE authenticated;

SELECT
  current_user='authenticated' AS rol_correcto,
  auth.uid() IS NOT NULL AS identidad_establecida,
  public.lm_puede_leer_cedula(current_setting('ligamaster.prueba_propia')) AS permite_propia,
  public.lm_puede_leer_cedula(current_setting('ligamaster.prueba_ajena')) AS permite_ajena,
  (SELECT count(*) FROM storage.objects
    WHERE bucket_id='cedulas_jugadores'
      AND name=current_setting('ligamaster.prueba_propia')) AS propias_visibles,
  (SELECT count(*) FROM storage.objects
    WHERE bucket_id='cedulas_jugadores'
      AND name=current_setting('ligamaster.prueba_ajena')) AS ajenas_visibles;

ROLLBACK;
-- Esperado: true, true, true, false, 1, 0.
-- No prueba firma JWT ni transporte HTTP: comprueba autorización y SELECT/RLS.
-- Si falla una sentencia, ejecutar ROLLBACK; antes de otra consulta.
