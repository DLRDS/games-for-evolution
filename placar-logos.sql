-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · LOGOS DOS PATROCINADORES
--
-- Cria o espaço de arquivos onde as logos ficam guardadas, para que
-- você possa enviar a imagem direto do celular, na página do placar.
--
-- ── LEIA ANTES DE RODAR ───────────────────────────────────────────
-- Este balde é PÚBLICO para leitura (tem que ser: o OBS busca a imagem
-- sem login) e aceita ENVIO SEM LOGIN. Isso significa, sem rodeios:
-- quem olhar o código da página encontra a chave pública do Supabase e
-- consegue enviar imagens para este balde.
--
-- O que limita o estrago:
--   · só entram imagens (png, jpeg, webp) — nada de script ou HTML
--   · cada arquivo no máximo 2 MB
--   · o balde é só de logos; nada do app ou dos grupos passa por aqui
--   · nada aparece na transmissão sozinho: só entra no ar a logo que
--     você escolher na página do placar
--
-- Deixei SVG de fora de propósito. SVG é um documento que pode carregar
-- script dentro; PNG e JPEG não.
--
-- Se um dia isso incomodar, o caminho é exigir login para enviar. Aí o
-- operador do placar precisaria entrar com conta antes do torneio.
-- ══════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('logos', 'logos', true, 2097152,
        array['image/png','image/jpeg','image/webp'])
on conflict (id) do update
  set public             = true,
      file_size_limit    = 2097152,
      allowed_mime_types = array['image/png','image/jpeg','image/webp'];

-- ── Quem pode ler: todo mundo (o OBS não faz login) ───────────────
drop policy if exists "logos leitura publica" on storage.objects;
create policy "logos leitura publica"
  on storage.objects for select
  using (bucket_id = 'logos');

-- ── Quem pode enviar: a página do placar, sem login ───────────────
drop policy if exists "logos envio" on storage.objects;
create policy "logos envio"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'logos');


-- ══════════════════════════════════════════════════════════════════
-- CONFERÊNCIA
-- ══════════════════════════════════════════════════════════════════
--
--   select id, public, file_size_limit, allowed_mime_types
--     from storage.buckets where id = 'logos';
--
-- Para ver o que já foi enviado:
--   select name, created_at from storage.objects
--    where bucket_id = 'logos' order by created_at desc;
--
-- Para apagar uma logo:
--   delete from storage.objects where bucket_id='logos' and name='...';
-- ══════════════════════════════════════════════════════════════════
