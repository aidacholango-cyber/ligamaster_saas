-- Solo lectura: no contiene datos de jugadores, contraseñas ni tokens.
SELECT jsonb_pretty(jsonb_build_object(
 'tablas', (SELECT jsonb_agg(jsonb_build_object(
   'tabla',c.relname,'rls',c.relrowsecurity,
   'anon_select',has_table_privilege('anon',c.oid,'SELECT'),
   'anon_insert',has_table_privilege('anon',c.oid,'INSERT'),
   'anon_update',has_table_privilege('anon',c.oid,'UPDATE'),
   'anon_delete',has_table_privilege('anon',c.oid,'DELETE'),
   'auth_select',has_table_privilege('authenticated',c.oid,'SELECT'),
   'auth_update',has_table_privilege('authenticated',c.oid,'UPDATE'),
   'opciones',c.reloptions) ORDER BY c.relname)
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m')),
 'politicas', (SELECT jsonb_agg(to_jsonb(p)) FROM pg_policies p
   WHERE schemaname IN ('public','storage')),
 'funciones', (SELECT jsonb_agg(jsonb_build_object(
   'funcion',p.oid::regprocedure::text,'definer',p.prosecdef,
   'config',p.proconfig,'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
   'auth_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'))
   ORDER BY p.proname)
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.prokind='f'),
 'buckets', (SELECT jsonb_agg(jsonb_build_object(
   'id',id,'publico',public,'limite_bytes',file_size_limit,
   'tipos_permitidos',allowed_mime_types)) FROM storage.buckets)
)) AS auditoria_seguridad;
