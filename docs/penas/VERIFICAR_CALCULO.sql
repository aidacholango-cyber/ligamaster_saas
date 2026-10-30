-- Solo lectura. Para campeonatos sin correcciones vigentes, el cálculo nuevo
-- debe coincidir con las vistas originales. Debe devolver cero filas.
with anteriores as (
 select c.id,coalesce((select jsonb_agg(to_jsonb(s)||jsonb_build_object(
  'expulsiones_doble_amarilla',d.expulsiones_doble_amarilla,
  'rojas_directas',d.rojas_directas,'sanciones_acumulacion',d.sanciones_acumulacion)
  order by s.equipo,s.apellidos,s.nombres,s.inscripcion_jugador_id)
 from public.lm_control_sanciones s join public.lm_resumen_disciplina d using(inscripcion_jugador_id)
 where s.campeonato_id=c.id),'[]'::jsonb) datos
 from public.campeonatos c where not exists(
  select 1 from public.lm_penas_correcciones pc join public.lm_penas_revisiones pr on pr.partido_id=pc.partido_id
  join public.campeonato_partidos p on p.id=pc.partido_id
  where p.campeonato_id=c.id and pr.origen=public.lm_penas_origen(p.id)
 )
) select id as campeonato_con_diferencias from anteriores where datos is distinct from public.lm_penas_calcular(id);
