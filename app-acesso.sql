-- ══════════════════════════════════════════════════════════════════
-- LEVEL BT · CONTAS COM ACESSO ANTECIPADO
--
-- O QUE ISTO FAZ
--   Cria a lista de contas que enxergam funções ainda em prova dentro
--   do app — hoje, o botão de alternar entre celular e computador.
--   Quem não está na lista usa o app normalmente e nem vê o botão.
--
-- POR QUE NO BANCO E NÃO NO CÓDIGO
--   O site é público: qualquer um lê o código-fonte. Uma lista de
--   e-mails ali dentro seria leitura aberta. Aqui dentro, ninguém
--   consegue ler a lista — só perguntar "eu estou nela?", e a resposta
--   é sim ou não sobre a própria conta de quem pergunta.
--
-- ⚠ O QUE ISTO NÃO É
--   Isto governa o que APARECE na tela, não o que a pessoa pode fazer.
--   Travas de tela são enfeite: quem souber mexer no navegador liga o
--   botão na marra. Para o caso de uso de hoje — você escolher como vê
--   o seu próprio app — isso basta e não há risco. Mas se um dia a
--   lista passar a liberar algo que mexe em dado de outra pessoa, a
--   trava tem que estar na regra do banco, não aqui.
--
-- Rode este arquivo inteiro. É seguro rodar mais de uma vez.
-- ══════════════════════════════════════════════════════════════════

create table if not exists app_acesso (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nota       text,
  created_at timestamptz not null default now()
);

-- Tabela trancada: ninguém lê a lista direto, nem logado.
alter table app_acesso enable row level security;

-- ── "Eu tenho acesso?" ────────────────────────────────────────────
-- Responde só sobre quem está perguntando. Não existe jeito de listar
-- os outros, nem de perguntar por outra conta: o id vem do próprio
-- login (auth.uid()), não de um argumento.
create or replace function tenho_acesso()
returns boolean
language sql
security definer
set search_path = public, extensions
stable
as $$
  select exists(
    select 1 from app_acesso where user_id = auth.uid()
  );
$$;

grant execute on function tenho_acesso() to authenticated;


-- ══════════════════════════════════════════════════════════════════
-- PASSO 2 · LIBERE A SUA CONTA
-- Rode SÓ o comando abaixo, numa query separada, trocando o e-mail
-- se não for esse. Ele procura a conta pelo e-mail do login e marca.
-- ══════════════════════════════════════════════════════════════════
--
--   insert into app_acesso (user_id, nota)
--   select id, 'Daniel' from auth.users
--    where email = 'coloque-seu-email-de-login-aqui'
--   on conflict (user_id) do nothing
--   returning user_id;
--
-- Se devolver uma linha, deu certo. Se não devolver nada, o e-mail
-- não bate com nenhuma conta — confira em Authentication → Users.
--
-- Para liberar outra pessoa depois, é o mesmo comando com outro
-- e-mail. Para tirar o acesso:
--
--   delete from app_acesso
--    where user_id = (select id from auth.users where email = '...');
--
-- Para conferir quantas contas estão liberadas (só você, no SQL
-- Editor, consegue fazer isto):
--
--   select a.nota, u.email, a.created_at
--     from app_acesso a join auth.users u on u.id = a.user_id
--    order by a.created_at;
-- ══════════════════════════════════════════════════════════════════

notify pgrst, 'reload schema';
