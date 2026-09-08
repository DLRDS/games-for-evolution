-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · CORREÇÃO — pgcrypto fora do alcance das funções
--
-- PROBLEMA
--   ERROR: function gen_random_bytes(integer) does not exist
--   CONTEXT: PL/pgSQL function bc_create()
--
-- CAUSA
--   No Supabase a extensão pgcrypto fica no schema "extensions".
--   As funções foram criadas com "set search_path = public", então
--   não enxergavam gen_random_bytes. Elas existiam, mas quebravam
--   ao rodar.
--
-- CORREÇÃO
--   Recriar as funções com search_path incluindo "extensions".
--
-- Rode este arquivo inteiro. É seguro rodar mais de uma vez.
-- ══════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;

-- ── bc_create: a que estava quebrando ─────────────────────────────
create or replace function bc_create()
returns table (token text, control_key text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text := encode(gen_random_bytes(6), 'hex');
  v_key   text := encode(gen_random_bytes(16), 'hex');
begin
  insert into broadcasts (token, control_key) values (v_token, v_key);
  return query select v_token, v_key;
end;
$$;

-- ── As outras do placar (por segurança, mesmo search_path) ────────
create or replace function bc_read(p_token text)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
  select payload from broadcasts where token = p_token;
$$;

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

grant execute on function bc_create()            to anon, authenticated;
grant execute on function bc_read(text)          to anon, authenticated;
grant execute on function bc_write(text, jsonb)  to anon, authenticated;


-- ══════════════════════════════════════════════════════════════════
-- TESTE — deve devolver uma linha com token e control_key
-- ══════════════════════════════════════════════════════════════════
select * from bc_create();

-- Depois de conferir, limpe o teste:
-- delete from broadcasts where payload = '{}'::jsonb;
