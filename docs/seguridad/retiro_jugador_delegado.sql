-- Ejecutar completo en Supabase SQL Editor antes de usar el retiro actualizado.
begin;

create or replace function public.lm_retirar_jugador_delegado(
  p_campeonato_id uuid,
  p_jugador_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_j public.jugadores%rowtype;
  v_ctx text;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión con tu cuenta de delegado.';
  end if;

  select * into v_j from public.jugadores
  where id = p_jugador_id for update;
  if not found then
    raise exception 'El jugador ya no existe.';
  end if;

  if not exists (
    select 1 from public.equipos e
    join public.perfiles p on p.id = auth.uid()
    where e.id = v_j.equipo_id
      and e.delegado_id = auth.uid() and p.rol = 'club'
  ) then
    raise exception 'Solo puedes retirar jugadores de tu equipo.';
  end if;

  perform public.lm_exigir_periodo_delegado(
    p_campeonato_id, v_j.equipo_id, v_j.categoria
  );

  v_ctx := current_setting('ligamaster.campeonato_inscripcion', true);
  perform set_config('ligamaster.campeonato_inscripcion', p_campeonato_id::text, true);

  update public.campeonato_jugadores
  set estado = 'retirado'
  where campeonato_id = p_campeonato_id
    and jugador_id = p_jugador_id and equipo_id = v_j.equipo_id;
  if not found then
    raise exception 'El jugador no tiene inscripción en este campeonato.';
  end if;

  perform set_config('ligamaster.campeonato_inscripcion', coalesce(v_ctx, ''), true);
end;
$$;

revoke all on function public.lm_retirar_jugador_delegado(uuid, uuid)
from public, anon, authenticated;
grant execute on function public.lm_retirar_jugador_delegado(uuid, uuid)
to authenticated;

-- Solo lectura de inscripciones de equipos propios; conserva las otras políticas.
drop policy if exists lm_delegado_lectura_inscripciones_propias
on public.campeonato_jugadores;
create policy lm_delegado_lectura_inscripciones_propias
on public.campeonato_jugadores for select to authenticated
using (
  exists (
    select 1 from public.equipos e
    join public.perfiles p on p.id = auth.uid()
    where e.id = campeonato_jugadores.equipo_id
      and e.delegado_id = auth.uid() and p.rol = 'club'
  )
);

notify pgrst, 'reload schema';
commit;
