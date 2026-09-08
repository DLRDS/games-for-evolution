-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · PAINEL DE ADMINISTRAÇÃO
--
-- Dá ao dono da plataforma a visão que o RLS esconde: quantos grupos
-- existem, quais estão vivos, e quais transmissões estão no ar.
--
-- Segurança: nada é aberto ao público. Existe uma CHAVE DE ADMIN
-- secreta; sem ela a função não devolve nada. As tabelas continuam
-- trancadas — o acesso passa só por esta função.
--
-- Este arquivo NÃO depende de ordem: se a tabela de transmissões ainda
-- não existir, o painel simplesmente mostra a lista vazia.
--
-- ── COMO RODAR ────────────────────────────────────────────────────
--   PASSO 1 · cole e rode TODO este arquivo no SQL Editor
--   PASSO 2 · rode o INSERT do final, numa query separada, e guarde a chave
-- ══════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;

-- Data de criação dos grupos (o app não preenchia).
do $$
begin
  if to_regclass('public.groups') is not null then
    alter table groups add column if not exists created_at timestamptz default now();
  end if;
end $$;

-- ── Chave de acesso ao painel ─────────────────────────────────────
create table if not exists admin_keys (
  key        text primary key,
  nome       text,
  created_at timestamptz not null default now()
);
alter table admin_keys enable row level security;   -- ninguém lê direto

-- ── Panorama da plataforma ────────────────────────────────────────
create or replace function admin_overview(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_ok boolean;
  v_grupos jsonb := '[]'::jsonb;
  v_lives  jsonb := '[]'::jsonb;
  v_tot    jsonb;
  v_bc     int   := 0;
  v_ar     int   := 0;
begin
  select exists(select 1 from admin_keys where key = p_key) into v_ok;
  if not v_ok then
    return jsonb_build_object('erro','chave invalida');
  end if;

  -- Grupos, com tamanho e última atividade
  if to_regclass('public.groups') is not null then
    execute $q$
      select coalesce(jsonb_agg(g order by g->>'ultima_sessao' desc nulls last), '[]'::jsonb)
      from (
        select jsonb_build_object(
          'codigo',    gr.id,
          'nome',      gr.name,
          'criado_em', gr.created_at,
          'jogadores', (select count(*) from players  p where p.group_id = gr.id),
          'contas',    (select count(distinct p.user_id) from players p
                          where p.group_id = gr.id and p.user_id is not null),
          'sessoes',   (select count(*) from sessions s where s.group_id = gr.id),
          'partidas',  (select count(*) from matches  m where m.group_id = gr.id),
          'ultima_sessao', (select max(s.date::text) from sessions s where s.group_id = gr.id)
        ) as g
        from groups gr
      ) t
    $q$ into v_grupos;
  end if;

  -- Transmissões (só existe depois do placar-supabase.sql)
  if to_regclass('public.broadcasts') is not null then
    execute $q$
      select coalesce(jsonb_agg(b order by b->>'atualizado' desc), '[]'::jsonb)
      from (
        select jsonb_build_object(
          'token',      br.token,
          'criado_em',  br.created_at,
          'atualizado', br.updated_at,
          'torneio',    br.payload->>'torneio',
          'categoria',  br.payload->>'cat',
          'fase',       br.payload->>'fase',
          'dupla_a',    br.payload->'t1',
          'dupla_b',    br.payload->'t2',
          'status',     coalesce(br.payload->>'status','vazio'),
          'sets',       coalesce(br.payload->>'s1','0') || '-' || coalesce(br.payload->>'s2','0'),
          'games',      coalesce(br.payload->>'g1','0') || '-' || coalesce(br.payload->>'g2','0'),
          'no_ar',      (br.updated_at > now() - interval '3 minutes')
        ) as b
        from broadcasts br
        where br.payload ? 't1'
        order by br.updated_at desc
        limit 60
      ) t
    $q$ into v_lives;

    execute $q$ select count(*) from broadcasts where payload ? 't1' $q$ into v_bc;
    execute $q$ select count(*) from broadcasts
                 where payload ? 't1' and updated_at > now() - interval '3 minutes' $q$ into v_ar;
  end if;

  -- Números gerais
  v_tot := jsonb_build_object(
    'grupos',       coalesce((select count(*) from groups),0),
    'usuarios',     coalesce((select count(distinct user_id) from players where user_id is not null),0),
    'jogadores',    coalesce((select count(*) from players),0),
    'sessoes',      coalesce((select count(*) from sessions),0),
    'partidas',     coalesce((select count(*) from matches),0),
    'transmissoes', v_bc,
    'no_ar',        v_ar
  );

  return jsonb_build_object('totais',v_tot,'grupos',v_grupos,'transmissoes',v_lives);
end;
$fn$;

grant execute on function admin_overview(text) to anon, authenticated;


-- ══════════════════════════════════════════════════════════════════
-- PASSO 2 · CRIE A SUA CHAVE
-- Rode SÓ o comando abaixo, numa query nova, e guarde o que ele devolver.
-- ══════════════════════════════════════════════════════════════════
--
--   insert into admin_keys (key, nome)
--   values (encode(gen_random_bytes(16),'hex'), 'Daniel')
--   returning key;
--
-- Para conferir se a tabela existe:   select * from admin_keys;
-- Para revogar uma chave:             delete from admin_keys where nome = 'Daniel';
-- ══════════════════════════════════════════════════════════════════
