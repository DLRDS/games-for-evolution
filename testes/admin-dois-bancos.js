// ══════════════════════════════════════════════════════════════════
// LEVEL BT · PAINEL — um painel, dois bancos
//
// O app e a transmissão viraram projetos separados no Supabase. O
// painel continua um só e fala com os dois. O que importa aqui é que
// um banco fora do ar NUNCA derrube o outro.
//
// Rode com:  node testes/admin-dois-bancos.js   (precisa de jsdom)
// ══════════════════════════════════════════════════════════════════
const fs=require('fs'),path=require('path'),{JSDOM}=require('jsdom');
const ARQ=path.join(__dirname,'..','admin.html');
const html=fs.readFileSync(ARQ,'utf8');

let ok=0,bad=0;
const t=(n,c)=>{try{if(c()){ok++;console.log('  ok  '+n)}else{bad++;console.log('FALHA '+n)}}
  catch(e){bad++;console.log('ERRO  '+n+' → '+e.message)}};

const GRUPOS={
  totais:{grupos:2,usuarios:5,jogadores:9,sessoes:4,partidas:12},
  grupos:[{codigo:'ABC123',nome:'Galera da Praia',jogadores:4,sessoes:2,partidas:7},
          {codigo:'XYZ789',nome:'Quarta de Manhã',jogadores:5,sessoes:2,partidas:5}],
  transmissoes:[]
};
const LIVES={
  totais:{transmissoes:3,no_ar:1},
  transmissoes:[{token:'tk1',torneio:'Copa Verão',quadra:'Quadra 2',categoria:'Mista A',
                 fase:'Final',dupla_a:['Ana','Bia'],dupla_b:['Cris','Dani'],
                 status:'playing',sets:'1-0',games:'4-2',no_ar:true,
                 atualizado:new Date().toISOString()}]
};

// comoLive: 'ok' | 'erro' | 'chave-ruim' | 'sem-config'
function abrir(comoLive){
  const semConfig = comoLive==='sem-config';
  let fonte=html;
  if(!semConfig){
    fonte=fonte.replace("const LIVE_URL='COLE_AQUI_A_URL_DO_PROJETO_DA_TRANSMISSAO';",
                        "const LIVE_URL='https://exemplo-live.supabase.co';");
  }
  return new JSDOM(fonte,{runScripts:'dangerously',url:'https://x/admin.html',pretendToBeVisual:true,
   beforeParse(w){
    w.scrollTo=()=>{};
    w.supabase={createClient:(url)=>({
      rpc:async(fn,args)=>{
        const ehLive = String(url).includes('exemplo-live');
        if(!ehLive) return {data:GRUPOS,error:null};            // banco do app
        if(comoLive==='erro')       throw new Error('Failed to fetch');
        if(comoLive==='chave-ruim') return {data:{erro:'chave invalida'},error:null};
        return {data:LIVES,error:null};
      }
    })};
   }}).window;
}
const esperar=ms=>new Promise(r=>setTimeout(r,ms));
// troca de aba pelo botão, como o usuário faria
function aba(w,qual){ w.document.querySelector('.tab[data-t="'+qual+'"]').click(); return true; }

async function entrar(w,comChaveLive){
  const d=w.document;
  d.getElementById('key').value='chave-do-app';
  d.getElementById('keyLive').value = comChaveLive ? 'chave-da-live' : '';
  d.getElementById('btnEnter').click();
  await esperar(500);
  return d;
}

(async()=>{

console.log('── OS DOIS BANCOS SEPARADOS ──');
t('o painel tem duas conexões', ()=>html.includes('const supaLive'));
t('e pede duas chaves na entrada', ()=>html.includes('id="keyLive"'));
t('o banco da transmissão está marcado para você preencher',
  ()=>html.includes('COLE_AQUI_A_URL_DO_PROJETO_DA_TRANSMISSAO'));
t('os links do placar apontam para o site novo',
  ()=>html.includes("const LIVE_SITE='https://dlrds.github.io/levelbt-live/'"));
t('o painel não procura mais placar.html ao lado',
  ()=>!html.includes("replace(/admin\\.html$/,'placar.html')"));

console.log('\n── TUDO NO LUGAR ──');
let w=abrir('ok'); await esperar(400);
let d=await entrar(w,true);
t('entra com as duas chaves',   ()=>!d.getElementById('board').classList.contains('hidden'));
t('mostra os grupos do app',    ()=>{ aba(w,'grupos');
  return d.getElementById('conteudo').innerHTML.includes('Galera da Praia'); });
t('e as transmissões do outro banco', ()=>{ aba(w,'lives');
  return d.getElementById('conteudo').innerHTML.includes('COPA VERÃO'); });
t('os totais somam os dois',
  ()=>d.getElementById('totais').textContent.includes('2')     // grupos
   && d.getElementById('totais').textContent.includes('3'));   // transmissões

console.log('\n── O BANCO DA TRANSMISSÃO FORA DO AR ──');
w=abrir('erro'); await esperar(400);
d=await entrar(w,true);
t('ainda assim o painel entra',   ()=>!d.getElementById('board').classList.contains('hidden'));
t('os grupos continuam aparecendo', ()=>{ aba(w,'grupos');
  return d.getElementById('conteudo').innerHTML.includes('Galera da Praia'); });
t('a aba de transmissões explica o que houve', ()=>{ aba(w,'lives');
  const h=d.getElementById('conteudo').innerHTML;
  return h.includes('Não consegui ler as transmissões') && h.includes('Failed to fetch'); });

console.log('\n── CHAVE DA TRANSMISSÃO ERRADA ──');
w=abrir('chave-ruim'); await esperar(400);
d=await entrar(w,true);
t('o painel entra do mesmo jeito', ()=>!d.getElementById('board').classList.contains('hidden'));
t('e diz que a chave é a do outro banco', ()=>{ aba(w,'lives');
  return d.getElementById('conteudo').innerHTML.includes('Chave de admin da transmissão inválida'); });

console.log('\n── SEM A CHAVE DA TRANSMISSÃO ──');
w=abrir('ok'); await esperar(400);
d=await entrar(w,false);
t('entra só com a chave do app', ()=>!d.getElementById('board').classList.contains('hidden'));
t('os grupos aparecem normalmente', ()=>{ aba(w,'grupos');
  return d.getElementById('conteudo').innerHTML.includes('Galera da Praia'); });
t('e a aba de transmissões diz que falta a chave', ()=>{ aba(w,'lives');
  return d.getElementById('conteudo').innerHTML.includes('Falta a chave de admin'); });

console.log('\n── PAINEL AINDA NÃO CONFIGURADO ──');
w=abrir('sem-config'); await esperar(400);
d=await entrar(w,true);
t('entra e mostra os grupos', ()=>{ aba(w,'grupos');
  return !d.getElementById('board').classList.contains('hidden')
      && d.getElementById('conteudo').innerHTML.includes('Galera da Praia'); });
t('e avisa que falta preencher LIVE_URL', ()=>{ aba(w,'lives');
  return d.getElementById('conteudo').innerHTML.includes('LIVE_URL'); });

console.log('\n'+(bad? '✗ '+bad+' FALHA(S) · '+ok+' ok' : '✓ TUDO OK · '+ok+' testes'));
process.exit(bad?1:0);
})();
