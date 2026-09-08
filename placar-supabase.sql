-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · PLACAR DE TRANSMISSÃO
-- Caminho de leitura pública para o overlay do OBS, sem abrir a tabela.
--
-- Como funciona:
--   · bc_create()               → cria uma transmissão e devolve DUAS chaves
--       token       = pública  → vai na URL do overlay (só lê)
--       control_key = secreta  → fica no celular de quem marca (só escreve)
--   · bc_read(token)            → devolve só o placar daquela transmissão
--   · bc_write(control_key, …)  → atualiza o placar daquela transmissão
--
-- A tabela continua trancada: ninguém acessa direto, só pelas funções.
-- Rode isto uma vez no SQL Editor do Supabase.
-- ══════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;

create table if not exists broadcasts (
  id           uuid primary key default gen_random_uuid(),
  token        text unique not null,
  control_key  text unique not null,
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Tabela trancada: nenhuma policy = ninguém lê nem escreve direto.
alter table broadcasts enable row level security;

create index if not exists broadcasts_token_idx       on broadcasts (token);
create index if not exists broadcasts_control_key_idx on broadcasts (control_key);

-- ── Criar uma transmissão ─────────────────────────────────────────
create or replace function bc_create()
returns table (token text, control_key text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text := encode(gen_random_bytes(6), 'hex');   -- 12 caracteres
  v_key   text := encode(gen_random_bytes(16), 'hex');  -- 32 caracteres
begin
  insert into broadcasts (token, control_key) values (v_token, v_key);
  return query select v_token, v_key;
end;
$$;

-- ── Ler o placar (overlay do OBS, sem login) ──────────────────────
create or replace function bc_read(p_token text)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  select payload from broadcasts where token = p_token;
$$;

-- ── Escrever o placar (quem tem a chave de controle) ──────────────
create or replace function bc_write(p_control_key text, p_payload jsonb)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_n int;
begin
  update broadcasts
     set payload = p_payload, updated_at = now()
   where control_key = p_control_key;
  get diagnostics v_n = row_count;
  return v_n > 0;
end;
$$;

-- ── Permissões: só as funções ficam acessíveis ────────────────────
grant execute on function bc_create()                 to anon, authenticated;
grant execute on function bc_read(text)               to anon, authenticated;
grant execute on function bc_write(text, jsonb)       to anon, authenticated;

-- Limpeza opcional: apaga transmissões com mais de 30 dias.
-- delete from broadcasts where created_at < now() - interval '30 days';
