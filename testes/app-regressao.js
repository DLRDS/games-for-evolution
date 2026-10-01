// ══════════════════════════════════════════════════════════════════
// LEVEL BT · APP — o que não pode quebrar
//
// Cobre as quatro abas, o voltar pela marca e o placar ao vivo vindo
// da transmissão. Rode com:   node testes/app-regressao.js
// Precisa do jsdom:           npm install jsdom
// ══════════════════════════════════════════════════════════════════
const fs=require('fs'),path=require('path'),{JSDOM}=require('jsdom');
const APP=path.join(__dirname,'..','index.html');
const html=fs.readFileSync(APP,'utf8');

let ok=0,bad=0;
const t=(n,c)=>{try{if(c()){ok++;console.log('  ok  '+n)}else{bad++;console.log('FALHA '+n)}}
  catch(e){bad++;console.log('ERRO  '+n+' → '+e.message)}};

const GID='ABC123', PID='p1';
const PLACAR={t1:['Ana','Bia'],t2:['Cris','Dani'],torneio:'Copa Verão',cat:'Mista B',fase:'Semi',
  p1:2,p2:3,g1:4,g2:5,s1:0,s2:0,setsFeitos:[],inTb:false,saque:0,status:'playing',v:3};

const seed={
  gfe6_players:[{id:PID,name:'Daniel',elo:1400,role:'dono',group_id:GID,user_id:'u1'}],
  gfe6_sessions:[], gfe6_matches:[], gfe6_challenges:[],
  gfe6_currentPlayer:PID, gfe6_activeGroup:GID, gfe6_myName:'Daniel',
  gfe6_authUserId:'u1', gfe6_onboardingDone:true, gfe6_groupNames:{[GID]:'Galera da praia'}
};

const w=new JSDOM(html,{runScripts:'dangerously',url:'https://x/index.html',pretendToBeVisual:true,
 beforeParse(w){
  for(const k in seed){ try{ w.localStorage.setItem(k,JSON.stringify(seed[k])); }catch(e){} }
  w.innerWidth=430; w.innerHeight=900;
  w.URL.createObjectURL=()=>'blob:x'; w.scrollTo=()=>{};
  w.navigator.serviceWorker={register:()=>Promise.resolve({}),ready:Promise.resolve({})};
  w.matchMedia=()=>({matches:false,addListener(){},removeListener(){}});
  w.chamadas=[];
  w.bancoAntigo=false;
  w.supabase={createClient:()=>({
    auth:{getSession:async()=>({data:{session:{user:{id:'u1',email:'e@x.com',
            user_metadata:{name:'Daniel'}}}}}),
          onAuthStateChange(){return{data:{subscription:{unsubscribe(){}}}}}},
    from:()=>{const q={select:()=>q,order:()=>q,eq:()=>q,in:()=>q,limit:()=>q,
                       then:r=>r({data:[],error:null})};return q;},
    rpc:async(fn,args)=>{
      w.chamadas.push([fn,args]);
      if(w.bancoAntigo) throw new Error('function '+fn+' does not exist');
      if(fn==='bc_ao_vivo')  return {data:[{token:'tk1',torneio:'Copa Verão'}],error:null};
      if(fn==='bc_read')     return {data:JSON.parse(JSON.stringify(PLACAR)),error:null};
      if(fn==='tenho_acesso')return {data:true,error:null};
      return {data:null,error:null};
    }
  })};
 }}).window;
const d=w.document;

setTimeout(async()=>{

console.log('── AS QUATRO ABAS ──');
['home','sessoes','ranking','perfil'].forEach(p=>{
  w.nav(p);
  t('aba '+p+' desenha alguma coisa', ()=>d.getElementById('content').innerHTML.length>400);
});
const telas={};
['home','sessoes','ranking','perfil'].forEach(p=>{ w.nav(p); telas[p]=d.getElementById('content').innerHTML; });
t('cada aba desenha algo diferente da outra',
  ()=>new Set(Object.values(telas)).size===4);
t('a aba ativa fica marcada no menu', ()=>{
  w.nav('ranking');
  return d.getElementById('nav-ranking').classList.contains('on')
      && !d.getElementById('nav-home').classList.contains('on');
});

console.log('\n── VOLTAR PELA MARCA ──');
const marca=d.getElementById('btn-inicio');
t('a marca do topo é botão', ()=>!!marca && marca.tagName==='BUTTON');
t('a marca aparece em todas as abas', ()=>
  ['home','sessoes','ranking','perfil'].every(p=>{ w.nav(p);
    return d.getElementById('topbar').style.display==='flex'; }));
t('o topo diz em que aba você está',
  ()=>{ w.nav('ranking'); return d.getElementById('hd-sub').textContent==='Ranking'; });
t('na Home volta a saudação',
  ()=>{ w.nav('home'); return /Olá|Beach Tennis/.test(d.getElementById('hd-sub').textContent); });
w.setPerfilView('ajustes'); w.nav('perfil');
t('a subtela de ajustes tem seu próprio voltar',
  ()=>d.getElementById('content').innerHTML.includes("setPerfilView('perfil')"));
marca.click();
t('clicar na marca leva para a Home',
  ()=>d.getElementById('nav-home').classList.contains('on'));
t('e fecha a subtela que estava aberta',
  ()=>{ w.nav('perfil'); const dentro=d.getElementById('content').innerHTML;
        w.nav('home'); return !dentro.includes('AJUSTES'); });

console.log('\n── A PONTE COM A TRANSMISSÃO FOI CORTADA ──');
// App e transmissão viraram produtos separados, cada um no seu banco.
// O app não deve mais falar com o banco da transmissão de jeito nenhum.
const fonte=fs.readFileSync(APP,'utf8');
['bc_ao_vivo','bc_read','carregarTransmissoes','cartaoTransmissao',
 'transmissoesNoAr','abrirPlacarTransmissao','ligarTransmissoes'].forEach(nome=>{
  t('o app não menciona mais '+nome, ()=>!fonte.includes(nome));
});
t('nenhuma chamada ao banco da transmissão sobrou',
  ()=>!w.chamadas.some(([fn])=>fn==='bc_ao_vivo'||fn==='bc_read'));
w.nav('home');
t('a Home não mostra cartão de transmissão',
  ()=>!d.getElementById('content').innerHTML.includes('TRANSMISSÃO AO VIVO'));
w.setPerfilView('ajustes'); w.nav('perfil');
t('os Ajustes não oferecem mais transmitir',
  ()=>!d.getElementById('content').innerHTML.includes('Transmitir um jogo'));
w.setPerfilView('perfil');

console.log('\n── O APP SEGUE INTEIRO SEM A PONTE ──');
['home','sessoes','ranking','perfil'].forEach(p=>{
  w.nav(p);
  t('aba '+p+' continua abrindo', ()=>d.getElementById('content').innerHTML.length>400);
});
w.nav('home');
t('a Home ainda mostra a sessão do grupo',
  ()=>d.getElementById('content').innerHTML.length>1500);

console.log('\n'+(bad? '✗ '+bad+' FALHA(S) · '+ok+' ok' : '✓ TUDO OK · '+ok+' testes'));
process.exit(bad?1:0);
},2600);
