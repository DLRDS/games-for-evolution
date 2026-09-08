-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · CORREÇÃO — tipo das colunas de time e confirmados
--
-- PROBLEMA
--   ERROR: operator does not exist: text[] ? text   (código 42883)
--   ao abrir o detalhe de um grupo no painel.
--
-- CAUSA
--   O operador "?" pertence ao jsonb. As colunas matches.team1,
--   matches.team2 e sessions.confirmed são arrays de texto (text[]),
--   não jsonb. Eu escrevi a consulta assumindo jsonb.
--
-- CORREÇÃO
--   Envolver em to_jsonb() antes de usar "?" e jsonb_array_length().
--   to_jsonb funciona tanto para text[] quanto para jsonb, então a
--   função passa a valer nos dois casos, sem depender do tipo exato.
--
-- Rode este arquivo inteiro. É seguro rodar mais de uma vez.
-- ══════════════════════════════════════════════════════════════════

create or replace function admin_grupo(p_key text, p_grupo text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare v jsonb;
begin
  if not admin_ok(p_key) then return jsonb_build_object('erro','chave invalida'); end if;

  select jsonb_build_object(
    'grupo', (select jsonb_build_object(
                'codigo', g.id, 'nome', g.name,
                'criado_em', g.created_at, 'criado_por', g.created_by)
              from groups g where g.id = p_grupo),

    'jogadores', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.name, 'elo', p.elo, 'papel', p.role,
        'tem_conta', (p.user_id is not null),
        'partidas', (select count(*) from matches m
                       where m.group_id = p_grupo
                         and (to_jsonb(m.team1) ? p.id
                           or to_jsonb(m.team2) ? p.id))
      ) order by p.elo desc nulls last)
      from players p where p.group_id = p_grupo), '[]'::jsonb),

    'sessoes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'data', s.date, 'nome', s.name, 'status', s.status,
        'confirmados', coalesce(jsonb_array_length(to_jsonb(s.confirmed)), 0),
        'partidas', (select count(*) from matches m where m.session_id = s.id)
      ) order by s.date desc)
      from sessions s where s.group_id = p_grupo), '[]'::jsonb),

    'partidas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'data', m.date, 'sessao', m.session_id,
        'time1', to_jsonb(m.team1), 'time2', to_jsonb(m.team2),
        'games1', m.games1, 'games2', m.games2, 'vencedor', m.winner
      ) order by m.data_ord desc)
      from (select id, date, session_id, team1, team2, games1, games2, winner,
                   date as data_ord
            from matches where group_id = p_grupo
            order by date desc limit 200) m), '[]'::jsonb)
  ) into v;

  return v;
end;
$fn$;

grant execute on function admin_grupo(text, text) to anon, authenticated;

notify pgrst, 'reload schema';


-- ══════════════════════════════════════════════════════════════════
-- TESTE — troque pelo código de um grupo seu e pela sua chave.
-- O código do grupo aparece na lista do painel.
-- ══════════════════════════════════════════════════════════════════
--
--   select admin_grupo('SUA_CHAVE', 'CODIGO_DO_GRUPO');
--
-- Deve devolver um JSON com grupo, jogadores, sessoes e partidas.
