"use client";

import { useState } from "react";

type Tab = "signal" | "markets" | "league" | "identity";
const marketData = [
  { tag: "MACRO · 119 J", question: "La BCE baissera-t-elle ses taux avant le 31 décembre ?", yes: 63, delta: "+4.2" },
  { tag: "INDICES · 5 J", question: "Le CAC 40 terminera-t-il la semaine au-dessus de 8 200 points ?", yes: 46, delta: "−2.1" },
  { tag: "TECH · 140 J", question: "Apple dépassera-t-elle 4 000 Md$ de capitalisation cette année ?", yes: 57, delta: "+7.0" },
];
const leaders = [["01","MacroKing","+18,9"],["02","ClaraQuant","+14,2"],["03","NordCapital","+9,1"],["04","CyrilG","+6,8"],["05","LucidBear","+5,4"]];

export default function KonsensApp() {
  const [tab, setTab] = useState<Tab>("signal");
  const [credits, setCredits] = useState(18420);
  const [streak, setStreak] = useState(6);
  const [answer, setAnswer] = useState<"OUI"|"NON"|null>(null);
  const [market, setMarket] = useState<(typeof marketData)[number]|null>(null);
  const [notice, setNotice] = useState("");
  const alert = (text:string) => { setNotice(text); window.setTimeout(()=>setNotice(""),2200); };
  const vote = (value:"OUI"|"NON") => { if(answer)return; setAnswer(value);setStreak(v=>v+1);alert(`Conviction ${value} enregistrée`); };
  const buy = (value:"OUI"|"NON") => { setCredits(v=>v-250);setMarket(null);alert(`250 crédits exposés sur ${value}`); };

  return <main className="terminal">
    <header className="masthead">
      <button className="wordmark" onClick={()=>setTab("signal")}><i>K</i><span>KONSENS</span><small>01</small></button>
      <div className="market-clock"><b>EURONEXT</b><span className="pulse"/>OUVERT <time>10:14:38</time></div>
      <button className="player" onClick={()=>setTab("identity")}><span>CG</span><b>4</b></button>
    </header>

    <aside className="index-nav">
      <p>ARENA / 26</p>
      <Nav number="01" label="Signal" active={tab==="signal"} onClick={()=>setTab("signal")}/>
      <Nav number="02" label="Marchés" active={tab==="markets"} onClick={()=>setTab("markets")}/>
      <Nav number="03" label="Ligue" active={tab==="league"} onClick={()=>setTab("league")}/>
      <Nav number="04" label="Identité" active={tab==="identity"} onClick={()=>setTab("identity")}/>
      <div className="season-index"><span>SAISON</span><strong>01</strong><em>J−12</em><div><i/></div><small>ARGENT · POSITION 04</small></div>
    </aside>

    <section className="viewport">
      {tab==="signal" && <Signal credits={credits} streak={streak} answer={answer} vote={vote} openMarket={setMarket} goMarkets={()=>setTab("markets")}/>} 
      {tab==="markets" && <Markets openMarket={setMarket}/>} 
      {tab==="league" && <League alert={alert}/>} 
      {tab==="identity" && <Identity streak={streak}/>} 
    </section>

    <div className="ticker-tape"><div><span>AIR <b>+1.24%</b></span><span>CAC 40 <b>+0.38%</b></span><span>CONSENSUS BCE <b>63%</b></span><span>TON RANG <b>#04 ↗</b></span><span>PROCHAINE CLÔTURE <b>05:42:18</b></span><span>AIR <b>+1.24%</b></span><span>CAC 40 <b>+0.38%</b></span></div></div>
    <nav className="thumb-nav"><Nav number="01" label="Signal" active={tab==="signal"} onClick={()=>setTab("signal")}/><Nav number="02" label="Marchés" active={tab==="markets"} onClick={()=>setTab("markets")}/><Nav number="03" label="Ligue" active={tab==="league"} onClick={()=>setTab("league")}/><Nav number="04" label="Moi" active={tab==="identity"} onClick={()=>setTab("identity")}/></nav>

    {market && <div className="trade-layer" onClick={()=>setMarket(null)}><section className="trade-console" onClick={e=>e.stopPropagation()}><button className="close" onClick={()=>setMarket(null)}>FERMER ×</button><p>{market.tag}</p><h2>{market.question}</h2><div className="trade-meter"><span style={{width:`${market.yes}%`}}/><b>{market.yes}%</b><small>CONSENSUS OUI</small></div><div className="ticket"><span>ORDRE</span><b>250 CRÉDITS</b><small>Simulation · aucun argent réel</small></div><div className="binary-actions"><button onClick={()=>buy("OUI")}>ACHETER OUI <b>{market.yes}</b></button><button onClick={()=>buy("NON")}>ACHETER NON <b>{100-market.yes}</b></button></div></section></div>}
    {notice && <div className="notice"><i/> {notice}</div>}
  </main>;
}

function Signal({credits,streak,answer,vote,openMarket,goMarkets}:{credits:number;streak:number;answer:"OUI"|"NON"|null;vote:(v:"OUI"|"NON")=>void;openMarket:(m:(typeof marketData)[number])=>void;goMarkets:()=>void}){
  return <>
    <div className="edition"><span>ÉDITION DU 10.08.26</span><b>PARIS · 10:14</b></div>
    <section className="hero-signal">
      <div className="hero-copy"><p>TON SIGNAL DU JOUR</p><h1>Lis le monde.<br/><em>Prends position.</em></h1><div className="hero-line"><span/><p>Une conviction aujourd’hui peut<br/>te faire passer sur le podium.</p></div></div>
      <div className="score-orbit"><div className="orbit orbit-a"/><div className="orbit orbit-b"/><div className="orbit-dot"/><span>VALEUR NETTE</span><strong>{credits.toLocaleString("fr-FR")}</strong><small>CRÉDITS</small><b>↗ 6,8%</b></div>
    </section>
    <section className="decision-strip">
      <div className="decision-meta"><p>DÉFI / 01</p><span>+40 XP</span><b>SÉRIE {streak} J</b></div>
      <div className="decision-question"><small>CLÔTURE À 20:00 · INFLATION</small><h2>L’inflation française repassera-t-elle sous 2 % avant octobre ?</h2></div>
      {answer ? <div className="locked-choice"><span>CONVICTION VERROUILLÉE</span><strong>{answer}</strong><small>Consensus révélé à la clôture</small></div> : <div className="binary-actions daily"><button onClick={()=>vote("OUI")}>OUI <b>52</b></button><button onClick={()=>vote("NON")}>NON <b>48</b></button></div>}
    </section>
    <section className="market-preview"><div className="vertical-title"><span>03</span><p>MARCHÉS<br/>EN TENSION</p></div><div className="market-rows">{marketData.map((m,i)=><button className="market-line" key={m.question} onClick={()=>openMarket(m)}><span>0{i+1}</span><div><small>{m.tag}</small><strong>{m.question}</strong></div><div className="line-prob"><b>{m.yes}<sup>%</sup></b><i className={m.delta.startsWith("−")?"down":""}>{m.delta}</i></div><em>↗</em></button>)}<button className="all-markets" onClick={goMarkets}>OUVRIR TOUS LES MARCHÉS <b>→</b></button></div></section>
  </>;
}

function Markets({openMarket}:{openMarket:(m:(typeof marketData)[number])=>void}){return <section className="editorial-page"><header><p>02 / MARCHÉS</p><h1>Le prix d’une<br/><em>conviction.</em></h1><span>Chaque pourcentage est une photographie du consensus. Entre avant les autres, assume après.</span></header><div className="market-canvas">{marketData.concat(marketData).map((m,i)=><button key={i} className={`market-poster poster-${i%3}`} onClick={()=>openMarket(m)}><span>{String(i+1).padStart(2,"0")}</span><small>{m.tag}</small><h2>{m.question}</h2><div><strong>{m.yes}<sup>%</sup></strong><i>{m.delta}</i></div><em>PRENDRE POSITION →</em></button>)}</div></section>}

function League({alert}:{alert:(s:string)=>void}){return <section className="editorial-page league-page"><header><p>03 / LIGUE ARGENT</p><h1>Plus haut.<br/><em>Ou plus juste.</em></h1><span>Les six premiers montent. Les convictions fragiles tombent.</span></header><div className="podium-word">04</div><div className="ranking"><div className="ranking-head"><span>RANG</span><span>JOUEUR</span><span>PERFORMANCE</span></div>{leaders.map(([rank,name,score])=><div className={name==="CyrilG"?"rank-line current":"rank-line"} key={name}><span>{rank}</span><strong>{name}</strong><div><b>{score}%</b><i style={{width:`${Math.abs(Number(score.replace(",",".")))*3}%`}}/></div>{name==="CyrilG"&&<em>TOI</em>}</div>)}<button className="invite" onClick={()=>alert("Code KNS-2026 copié")}>+ INVITER UN ADVERSAIRE</button></div></section>}

function Identity({streak}:{streak:number}){return <section className="editorial-page identity-page"><header><p>04 / IDENTITÉ</p><h1>CyrilG.<br/><em>Stratège macro.</em></h1><span>Ton historique compose une identité, pas un simple profil.</span></header><div className="identity-mark">CG<span>NIVEAU 07</span></div><div className="stats-band"><div><span>PRÉCISION</span><strong>68<sup>%</sup></strong></div><div><span>SAISON</span><strong>+6,8<sup>%</sup></strong></div><div><span>SÉRIE</span><strong>{streak}<sup>J</sup></strong></div><div><span>RANG</span><strong>#04</strong></div></div><blockquote>« Conviction macro.<br/>Risque maîtrisé. »<small>Tu bats 72 % de l’arène sur les questions économiques.</small></blockquote></section>}

function Nav({number,label,active,onClick}:{number:string;label:string;active:boolean;onClick:()=>void}){return <button className={active?"active":""} onClick={onClick}><span>{number}</span><b>{label}</b><i/></button>}
