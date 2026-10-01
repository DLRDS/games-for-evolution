# Testes

Suítes que rodam o app num navegador de mentira (jsdom) e conferem o que
não pode quebrar. Não precisam de internet nem do Supabase: o banco é
simulado dentro de cada arquivo.

## Como rodar

```bash
npm install jsdom          # uma vez só
node testes/app-regressao.js
node testes/app-visualizacao.js
```

Cada suíte imprime uma linha por verificação e termina em `✓ TUDO OK` ou
`✗ N FALHA(S)`. Sai com código 1 quando falha, então serve em automação.

## O que cada uma cobre

- **app-regressao.js** — as quatro abas, o voltar pela marca, o placar ao
  vivo vindo da transmissão, o botão de transmitir, e o app continuar de
  pé quando o banco ainda não tem as funções novas.
- **app-visualizacao.js** — o layout de celular intacto, o layout de
  computador com menu lateral, o botão de alternar e a trava de acesso.

## Uma pegadinha

O app espera 1,8 s no splash antes de conferir a sessão e o acesso. Os
testes esperam 2,6 s por isso. Olhar antes disso dá falso "não liberado"
e os testes passam sem testar nada.
