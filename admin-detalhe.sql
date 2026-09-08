-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · PAINEL — DETALHE E EDIÇÃO DE GRUPOS
--
-- Acrescenta ao painel: ver tudo de um grupo e poder alterar.
-- Continua protegido pela mesma chave de admin. As tabelas seguem
-- trancadas — tudo passa por estas funções.
--
-- Rode DEPOIS de admin-supabase.sql.
--
-- ⚠ ATENÇÃO: estas funções apagam dados de verdade e não têm desfazer.
-- ══════════════════════════════════════════════════════════════════

-- ── Confere a chave (usada por todas as funções abaixo) ───────────
create or replace function admin_ok(p_key text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$ select exists(select 1 from admin_keys where key = p_key); $$;

-- ── Tudo de um grupo ──────────────────────────────────────────────
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
                         and (m.team1 ? p.id or m.team2 ? p.id))
      ) order by p.elo desc nulls last)
      from players p where p.group_id = p_grupo), '[]'::jsonb),

    'sessoes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'data', s.date, 'nome', s.name, 'status', s.status,
        'confirmados', coalesce(jsonb_array_length(s.confirmed), 0),
        'partidas', (select count(*) from matches m where m.session_id = s.id)
      ) order by s.date desc)
      from sessions s where s.group_id = p_grupo), '[]'::jsonb),

    'partidas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'data', m.date, 'sessao', m.session_id,
        'time1', m.team1, 'time2', m.team2,
        'games1', m.games1, 'games2', m.games2, 'vencedor', m.winner
      ) order by m.date desc)
      from (select * from matches where group_id = p_grupo
            order by date desc limit 200) m), '[]'::jsonb)
  ) into v;

  return v;
end;
$fn$;

-- ── Renomear o grupo ──────────────────────────────────────────────
create or replace function admin_set_grupo(p_key text, p_grupo text, p_nome text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_ok(p_key) then return false; end if;
  update groups set name = p_nome where id = p_grupo;
  return found;
end; $$;

-- ── Editar um jogador (nome, elo, papel) ──────────────────────────
create or replace function admin_set_jogador(
  p_key text, p_id text, p_nome text, p_elo int, p_papel text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_ok(p_key) then return false; end if;
  update players set
    name = coalesce(nullif(p_nome,''), name),
    elo  = coalesce(p_elo, elo),
    role = case when p_papel = '__nenhum__' then null
                when p_papel is null or p_papel = '' then role
                else p_papel end
  where id = p_id;
  return found;
end; $$;

-- ── Apagar (jogador · sessão · partida · grupo inteiro) ───────────
create or replace function admin_apagar(p_key text, p_tipo text, p_id text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $fn$
declare n int := 0;
begin
  if not admin_ok(p_key) then return jsonb_build_object('erro','chave invalida'); end if;

  if p_tipo = 'jogador' then
    delete from players where id = p_id;
    get diagnostics n = row_count;

  elsif p_tipo = 'sessao' then
    delete from matches  where session_id = p_id;
    delete from sessions where id = p_id;
    get diagnostics n = row_count;

  elsif p_tipo = 'partida' then
    delete from matches where id = p_id;
    get diagnostics n = row_count;

  elsif p_tipo = 'grupo' then
    delete from matches    where group_id = p_id;
    delete from sessions   where group_id = p_id;
    delete from players    where group_id = p_id;
    delete from challenges where group_id = p_id;
    delete from groups     where id = p_id;
    get diagnostics n = row_count;

  else
    return jsonb_build_object('erro','tipo desconhecido');
  end if;

  return jsonb_build_object('ok', true, 'apagados', n);
end; $fn$;

grant execute on function admin_ok(text)                                  to anon, authenticated;
grant execute on function admin_grupo(text, text)                         to anon, authenticated;
grant execute on function admin_set_grupo(text, text, text)               to anon, authenticated;
grant execute on function admin_set_jogador(text, text, text, int, text)  to anon, authenticated;
grant execute on function admin_apagar(text, text, text)                  to anon, authenticated;
