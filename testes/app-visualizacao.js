// Visualização de computador e a trava de acesso.
// ══════════════════════════════════════════════════════════════════
// LEVEL BT · APP — visualização de celular e de computador
// Rode com:  node testes/app-visualizacao.js   (precisa de jsdom)
// ══════════════════════════════════════════════════════════════════
const fs=require('fs'),path=require('path'),{JSDOM}=require('jsdom');
const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
let ok=0,bad=0;
const t=(n,c)=>{try{if(c()){ok++;console.log('  ok  '+n)}else{bad++;console.log('FALHA '+n)}}
  catch(e){bad++;console.log('ERRO  '+n+' → '+e.message)}};

const GID='ABC123', PID='p1';
const seed={
  gfe6_players:[{id:PID,name:'Daniel',elo:1400,role:'dono',group_id:GID,user_id:'u1'}],
  gfe6_sessions:[], gfe6_matches:[], gfe6_challenges:[],
  gfe6_currentPlayer:PID, gfe6_activeGroup:GID, gfe6_myName:'Daniel',
  gfe6_authUserId:'u1', gfe6_onboardingDone:true, gfe6_groupNames:{[GID]:'Galera'}
};
function abrir(largura,liberado,visSalva){
  return new JSDOM(html,{runScripts:'dangerously',url:'https://x/index.html',pretendToBeVisual:true,
   beforeParse(w){
    for(const k in seed){ try{ w.localStorage.setItem(k,JSON.stringify(seed[k])); }catch(e){} }
    if(visSalva){ try{ w.localStorage.setItem('gfe6_visualizacao',visSalva); }catch(e){} }
    w.innerWidth=largura; w.innerHeight=900;
    w.URL.createObjectURL=()=>'blob:x'; w.scrollTo=()=>{};
    w.navigator.serviceWorker={register:()=>Promise.resolve({}),ready:Promise.resolve({})};
    w.matchMedia=()=>({matches:false,addListener(){},removeListener(){}});
    w.supabase={createClient:()=>({
      auth:{getSession:async()=>({data:{session:{user:{id:'u1',email:'eu@exemplo.com',
              user_metadata:{name:'Daniel'}}}}}),
            onAuthStateChange(){return{data:{subscription:{unsubscribe(){}}}}}},
      from:()=>{const q={select:()=>q,order:()=>q,eq:()=>q,in:()=>q,limit:()=>q,
                         then:r=>r({data:[],error:null})};return q;},
      rpc:async(fn)=>{
        if(fn==='tenho_acesso') return liberado===null
          ? {data:null,error:{message:'function tenho_acesso does not exist'}}
          : {data:liberado,error:null};
        return {data:null,error:null};
      }
    })};
   }}).window;
}

// O app espera 1,8s no splash antes de conferir a sessão e o acesso.
// Olhar antes disso daria falso "não liberado" em todo teste.
const ABERTURA=2600;
const esperar=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{

console.log('── O CELULAR CONTINUA COMO ERA ──');
let w=abrir(430,true); await esperar(ABERTURA);
let d=w.document, r=d.documentElement;
t('tela estreita abre no modo celular', ()=>r.classList.contains('modo-cel') && !r.classList.contains('modo-pc'));
t('as 4 abas continuam embaixo',        ()=>!!d.querySelector('nav .nb'));
w.nav('home');
const homeCel=d.getElementById('content').innerHTML;
t('a Home abre normal',                 ()=>homeCel.length>1500);
t('a ordem no celular não muda: nível, atividade, último jogo', ()=>{
  const i1=homeCel.indexOf('pc-nivel'), i2=homeCel.indexOf('pc-ativ'), i3=homeCel.indexOf('pc-ultimo');
  return i1>=0 && i1<i2 && i2<i3;
});

console.log('\n── MODO COMPUTADOR ──');
w=abrir(1440,true); await esperar(ABERTURA);
d=w.document; r=d.documentElement;
t('tela larga abre no modo computador', ()=>r.classList.contains('modo-pc'));
t('o menu lateral é o mesmo nav, só reposicionado',
  ()=>d.querySelectorAll('nav .nb').length===4);
['home','sessoes','ranking','perfil'].forEach(p=>{
  w.nav(p);
  t('aba '+p+' abre no computador', ()=>d.getElementById('content').innerHTML.length>400);
});
w.nav('home');
t('a Home traz as três áreas para o grid', ()=>{
  const h=d.getElementById('content').innerHTML;
  return h.includes('pc-nivel') && h.includes('pc-ativ') && h.includes('pc-ultimo');
});
t('o CSS coloca a atividade na coluna da direita',
  ()=>/grid-template-areas:"nivel ativ" "ultimo ativ"/.test(html));
t('o menu lateral tem largura própria no CSS',
  ()=>/grid-template-columns:248px minmax\(0,1fr\)/.test(html));

console.log('\n── O BOTÃO DE ALTERNAR ──');
const b=d.getElementById('btn-vis');
t('conta liberada enxerga o botão', ()=>!b.classList.contains('hidden'));
t('ele diz o modo e que foi automático', ()=>/COMPUTADOR · AUTO/.test(b.textContent));
b.click();
t('um clique força o celular numa tela larga',
  ()=>r.classList.contains('modo-cel') && !r.classList.contains('modo-pc'));
t('e o rótulo some o AUTO',        ()=>b.textContent==='CELULAR');
t('a escolha fica guardada',       ()=>w.localStorage.getItem('gfe6_visualizacao')==='cel');
b.click();
t('o clique seguinte volta ao computador, ainda fixo', ()=>r.classList.contains('modo-pc') && b.textContent==='COMPUTADOR');
b.click();
t('o terceiro clique volta ao automático', ()=>/· AUTO/.test(b.textContent));
t('e limpa o que estava guardado',  ()=>!w.localStorage.getItem('gfe6_visualizacao'));

console.log('\n── A ESCOLHA SOBREVIVE A FECHAR O APP ──');
w=abrir(430,true,'pc'); await esperar(ABERTURA);
t('celular com computador fixado abre no computador',
  ()=>w.document.documentElement.classList.contains('modo-pc'));
w=abrir(1440,true,'cel'); await esperar(ABERTURA);
t('monitor com celular fixado abre no celular',
  ()=>w.document.documentElement.classList.contains('modo-cel'));

console.log('\n── QUEM NÃO ESTÁ LIBERADO ──');
w=abrir(1440,false); await esperar(ABERTURA);
d=w.document;
t('não vê o botão', ()=>d.getElementById('btn-vis').classList.contains('hidden'));
t('mas o app funciona igual', ()=>{ w.nav('home');
  return d.getElementById('content').innerHTML.length>1500; });
t('e a tela larga ainda abre no computador',
  ()=>d.documentElement.classList.contains('modo-pc'));

console.log('\n── BANCO SEM A FUNÇÃO NOVA ──');
w=abrir(1440,null); await esperar(ABERTURA);
d=w.document;
t('ninguém fica liberado por engano', ()=>d.getElementById('btn-vis').classList.contains('hidden'));
t('e o app não quebra', ()=>{ w.nav('perfil');
  return d.getElementById('content').innerHTML.length>400; });

console.log('\n'+(bad? '✗ '+bad+' FALHA(S) · '+ok+' ok' : '✓ TUDO OK · '+ok+' testes'));
process.exit(bad?1:0);
})();
