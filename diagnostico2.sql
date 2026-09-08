-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · DIAGNÓSTICO 2 — PERMISSÕES
--
-- O diagnóstico anterior mostrou que as funções existem.
-- Este verifica se o NAVEGADOR (papel "anon") pode executá-las.
-- Uma função pode existir e ainda assim ser inacessível pelo app.
--
-- Rode e me mande o resultado.
-- ══════════════════════════════════════════════════════════════════

-- ── 1. O anon pode executar cada função? ──────────────────────────
select
  p.proname                                            as funcao,
  case when has_function_privilege('anon',  p.oid, 'EXECUTE')
       then 'ok' else 'SEM PERMISSAO' end              as anon,
  case when has_function_privilege('authenticated', p.oid, 'EXECUTE')
       then 'ok' else 'SEM PERMISSAO' end              as logado
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('bc_create','bc_read','bc_write',
                    'admin_overview','admin_grupo','admin_ok',
                    'admin_set_grupo','admin_set_jogador','admin_apagar')
order by p.proname;


-- ── 2. As funções são SECURITY DEFINER? (precisam ser) ────────────
select p.proname as funcao,
       case when p.prosecdef then 'ok (definer)' else 'ERRADO (invoker)' end as tipo
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public'
  and p.proname in ('bc_create','bc_read','bc_write','admin_overview','admin_grupo')
order by p.proname;


-- ── 3. Teste real: cria uma transmissão de mentira ────────────────
-- Se isto funcionar aqui mas falhar no app, o problema é permissão ou rede.
select * from bc_create();


-- ── 4. Teste do painel — TROQUE pela sua chave ────────────────────
-- select (admin_overview('COLE_SUA_CHAVE_AQUI')->'totais') as totais;


-- ── 5. Limpa os testes ────────────────────────────────────────────
-- delete from broadcasts where payload = '{}'::jsonb;
