-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · RECARREGAR O CACHE DA API
--
-- PROBLEMA
--   O app diz que uma função "não existe", mas ela existe no banco.
--
-- CAUSA
--   O PostgREST (a camada que expõe o banco para o navegador) guarda
--   um cache do schema. Funções criadas depois desse cache ficam
--   invisíveis para o app até ele recarregar — mesmo existindo.
--
-- CORREÇÃO
--   Avisar o PostgREST para reler o schema.
-- ══════════════════════════════════════════════════════════════════

notify pgrst, 'reload schema';


-- ── Conferência: as funções estão publicadas na API? ──────────────
-- Só aparece aqui o que o app consegue enxergar.
select p.proname                             as funcao,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       case when has_function_privilege('anon', p.oid, 'EXECUTE')
            then 'anon pode' else 'ANON SEM PERMISSAO' end as acesso
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname like any (array['bc_%','admin_%'])
order by p.proname;

-- Se mesmo assim o app continuar sem enxergar:
-- Painel → Settings → General → Restart project
