-- Basado en el diagnóstico real de storage.objects.
-- Conserva el permiso anterior y añade exclusivamente la comisión autorizada.
-- No modifica archivos, fichas ni las políticas de otros buckets.
begin;
alter policy lm_cedulas_lectura_autorizada on storage.objects
  using (
    bucket_id <> 'cedulas_jugadores'
    or public.lm_puede_leer_cedula(name)
    or public.lm_comision_puede_leer_cedula(name)
  );
commit;
