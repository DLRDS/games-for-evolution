-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · TRANSMISSÃO LIGADA AO GRUPO
--
-- O QUE ISTO FAZ
--   Permite amarrar uma transmissão a um grupo do app. A partir daí,
--   quem está naquele grupo vê o placar ao vivo dentro do app, sem
--   precisar de link nenhum.
--
-- O QUE MUDA
--   · broadcasts ganha a coluna group_id
--   · bc_create(p_group) passa a aceitar o código do grupo (opcional —
--     chamar sem argumento continua funcionando como antes)
--   · bc_ao_vivo(p_group) devolve as transmissões vivas daquele grupo
--
-- SOBRE O ACESSO
--   Quem souber o código do grupo consegue listar as transmissões dele.
--   É o mesmo nível de segredo que já entra no grupo pelo app, então
--   não abre nada novo — mas é bom você saber que é assim.
--
-- Rode DEPOIS de placar-supabase.sql. É seguro rodar mais de uma vez.
-- ══════════════════════════════════════════════════════════════════

alter table broadcasts add column if not exists group_id text;
create index if not exists broadcasts_group_idx on broadcasts (group_id);

-- ── Criar transmissão, agora podendo dizer de que grupo ela é ──────
-- O argumento tem padrão nulo: as chamadas antigas, sem argumento,
-- continuam válidas e simplesmente criam uma transmissão sem grupo.
create or replace function bc_create(p_group text default null)
returns table (token text, control_key text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text := encode(gen_random_bytes(6), 'hex');
  v_key   text := encode(gen_random_bytes(16), 'hex');
begin
  insert into broadcasts (token, control_key, group_id)
  values (v_token, v_key, nullif(btrim(coalesce(p_group,'')), ''));
  return query select v_token, v_key;
end;
$$;

-- ── O que está no ar agora, para este grupo ────────────────────────
-- "No ar" = recebeu atualização nos últimos 3 minutos. Devolve só o
-- necessário para montar o cartão do app; o placar completo continua
-- vindo do bc_read(token), como no overlay.
create or replace function bc_ao_vivo(p_group text)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  select coalesce(jsonb_agg(x order by x->>'atualizado' desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'token',      b.token,
      'atualizado', b.updated_at,
      'torneio',    b.payload->>'torneio',
      'categoria',  b.payload->>'cat',
      'fase',       b.payload->>'fase',
      'quadra',     b.payload->>'quadra',
      'dupla_a',    b.payload->'t1',
      'dupla_b',    b.payload->'t2',
      'status',     coalesce(b.payload->>'status','playing')
    ) as x
    from broadcasts b
    where b.group_id = nullif(btrim(coalesce(p_group,'')), '')
      and b.payload ? 't1'
      and b.updated_at > now() - interval '3 minutes'
    order by b.updated_at desc
    limit 12
  ) t;
$$;

grant execute on function bc_create(text)   to anon, authenticated;
grant execute on function bc_ao_vivo(text)  to anon, authenticated;

notify pgrst, 'reload schema';


-- ══════════════════════════════════════════════════════════════════
-- CONFERÊNCIA
-- ══════════════════════════════════════════════════════════════════
--
--   select * from bc_create('CODIGO_DO_SEU_GRUPO');
--   select bc_ao_vivo('CODIGO_DO_SEU_GRUPO');
--
-- A segunda só devolve algo depois que o placar começar a publicar —
-- ela olha os últimos 3 minutos de atividade.
-- ══════════════════════════════════════════════════════════════════
