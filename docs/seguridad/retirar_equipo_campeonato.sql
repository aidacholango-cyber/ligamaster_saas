-- Retira un equipo exclusivamente del campeonato y categoría seleccionados.
begin;

create or replace function public.lm_retirar_equipo_campeonato(
  p_campeonato_id uuid,
  p_equipo_id bigint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_liga uuid;
  v_ctx text;
begin
  select liga_id into v_liga from public.campeonatos
  where id = p_campeonato_id;
  if not found then
    raise exception 'El campeonato no existe.';
  end if;
  if auth.uid() is null or not coalesce(
    public.lm_es_superadmin() or public.lm_administra_liga(v_liga::text), false
  ) then
    raise exception 'Solo el administrador de esta liga puede retirar el equipo.';
  end if;

  -- Bloquea únicamente la inscripción seleccionada.
  perform 1 from public.campeonato_equipos
  where campeonato_id = p_campeonato_id and equipo_id = p_equipo_id
  for update;
  if not found then
    raise exception 'El equipo no está inscrito en este campeonato.';
  end if;

  v_ctx := current_setting('ligamaster.campeonato_inscripcion', true);
  perform set_config('ligamaster.campeonato_inscripcion', p_campeonato_id::text, true);

  update public.campeonato_jugadores set estado = 'retirado'
  where campeonato_id = p_campeonato_id and equipo_id = p_equipo_id
    and estado = 'inscrito';
  update public.campeonato_equipos set estado = 'retirado'
  where campeonato_id = p_campeonato_id and equipo_id = p_equipo_id;

  perform set_config('ligamaster.campeonato_inscripcion', coalesce(v_ctx, ''), true);
end;
$$;

revoke all on function public.lm_retirar_equipo_campeonato(uuid, bigint)
from public, anon, authenticated;
grant execute on function public.lm_retirar_equipo_campeonato(uuid, bigint)
to authenticated;

notify pgrst, 'reload schema';
commit;
