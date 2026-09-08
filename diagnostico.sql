-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · DIAGNÓSTICO
-- Rode isto no SQL Editor e me mande o resultado.
-- Ele diz exatamente o que existe e o que falta.
-- ══════════════════════════════════════════════════════════════════

select
  'TABELAS' as bloco, '' as item, '' as situacao
union all select '', 'groups',      case when to_regclass('public.groups')      is null then 'FALTA' else 'ok' end
union all select '', 'players',     case when to_regclass('public.players')     is null then 'FALTA' else 'ok' end
union all select '', 'sessions',    case when to_regclass('public.sessions')    is null then 'FALTA' else 'ok' end
union all select '', 'matches',     case when to_regclass('public.matches')     is null then 'FALTA' else 'ok' end
union all select '', 'broadcasts',  case when to_regclass('public.broadcasts')  is null then 'FALTA — rode placar-supabase.sql' else 'ok' end
union all select '', 'admin_keys',  case when to_regclass('public.admin_keys')  is null then 'FALTA — rode admin-supabase.sql'  else 'ok' end

union all select 'FUNÇÕES', '', ''
union all select '', 'bc_create',        case when exists(select 1 from pg_proc where proname='bc_create')        then 'ok' else 'FALTA — rode placar-supabase.sql' end
union all select '', 'bc_read',          case when exists(select 1 from pg_proc where proname='bc_read')          then 'ok' else 'FALTA — rode placar-supabase.sql' end
union all select '', 'bc_write',         case when exists(select 1 from pg_proc where proname='bc_write')         then 'ok' else 'FALTA — rode placar-supabase.sql' end
union all select '', 'admin_overview',   case when exists(select 1 from pg_proc where proname='admin_overview')   then 'ok' else 'FALTA — rode admin-supabase.sql'  end
union all select '', 'admin_grupo',      case when exists(select 1 from pg_proc where proname='admin_grupo')      then 'ok' else 'FALTA — rode admin-detalhe.sql'   end
union all select '', 'admin_set_grupo',  case when exists(select 1 from pg_proc where proname='admin_set_grupo')  then 'ok' else 'FALTA — rode admin-detalhe.sql'   end
union all select '', 'admin_apagar',     case when exists(select 1 from pg_proc where proname='admin_apagar')     then 'ok' else 'FALTA — rode admin-detalhe.sql'   end

union all select 'DADOS', '', ''
union all select '', 'grupos',       coalesce((select count(*)::text from groups),'—')
union all select '', 'jogadores',    coalesce((select count(*)::text from players),'—')
union all select '', 'chaves admin', coalesce((select count(*)::text from admin_keys),'—')
;
