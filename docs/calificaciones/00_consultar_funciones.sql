-- Solo lectura. Compartir el resultado para conservar las validaciones actuales.
select p.proname as funcion, pg_get_functiondef(p.oid) as definicion
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (
  p.proname in ('lm_revisar_jugador','lm_calificar_jugador')
  or (p.prorettype='trigger'::regtype
    and pg_get_functiondef(p.oid) ilike '%califica%')
);

-- Identificar la liga y los campeonatos a los que se delegará acceso.
-- Consulta adicional necesaria para preservar el registro de nombres y fechas.
select t.tgname as disparador, pg_get_functiondef(t.tgfoid) as definicion
from pg_trigger t
where t.tgrelid='public.jugadores'::regclass and not t.tgisinternal;

-- Inventario de campeonatos; la comisión puede ayudar en todos.
select l.id as liga_id,l.nombre as liga,c.id as campeonato_id,
  c.nombre as campeonato,c.categoria
from public.campeonatos c join public.ligas l on l.id=c.liga_id
order by l.nombre,c.nombre,c.categoria;
