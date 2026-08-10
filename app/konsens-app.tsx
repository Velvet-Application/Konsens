"use client";

import { useMemo, useState } from "react";

type Tab = "home" | "learn" | "invest" | "league";
type Choice = "etf" | "stock" | "prediction";

const options = {
  etf: { name: "ETF Monde", rate: 7, risk: "Modéré", color: "blue", icon: "◎", detail: "Un panier de plus de 1 400 entreprises mondiales." },
  stock: { name: "Action Airbus", rate: 10, risk: "Élevé", color: "violet", icon: "A", detail: "Une seule entreprise : plus de potentiel, mais plus de risque." },
  prediction: { name: "Prédiction BCE", rate: 58.73, risk: "Très élevé", color: "orange", icon: "?", detail: "Tout ou rien selon l’événement. Le gain dépend du prix d’entrée." },
} as const;

const rankings = [[1,"Clara",12480,24.8],[2,"Mehdi",11870,18.7],[3,"Cyril",11260,12.6],[4,"Emma",10940,9.4],[5,"Lucas",10710,7.1]];

export default function KonsensApp() {
  const [tab, setTab] = useState<Tab>("home");
  const [balance, setBalance] = useState(10000);
  const [amount, setAmount] = useState(1000);
  const [choice, setChoice] = useState<Choice>("etf");
  const [months, setMonths] = useState(12);
  const [toast, setToast] = useState("");
  const notify = (value:string) => { setToast(value); window.setTimeout(()=>setToast(""),2200); };
  const invest = () => { if(amount>balance)return notify("Montant supérieur à ton solde");setBalance(v=>v-amount);notify(`${amount.toLocaleString("fr-FR")} € virtuels placés`); };

  return <main className="k-app">
    <header className="k-header">
      <button className="k-logo" onClick={()=>setTab("home")}><span>K</span><b>Konsens</b></button>
      <nav><Nav active={tab==="home"} label="Accueil" onClick={()=>setTab("home")}/><Nav active={tab==="learn"} label="Apprendre" onClick={()=>setTab("learn")}/><Nav active={tab==="invest"} label="Investir" onClick={()=>setTab("invest")}/><Nav active={tab==="league"} label="Classement" onClick={()=>setTab("league")}/></nav>
      <button className="profile-pill"><span>CG</span><b>Niv. 3</b></button>
    </header>

    <section className="k-content">
      {tab==="home"&&<Home balance={balance} goLearn={()=>setTab("learn")} goInvest={()=>setTab("invest")}/>} 
      {tab==="learn"&&<Learn amount={amount} setAmount={setAmount} choice={choice} setChoice={setChoice} months={months} setMonths={setMonths}/>} 
      {tab==="invest"&&<Invest balance={balance} amount={amount} setAmount={setAmount} choice={choice} setChoice={setChoice} months={months} setMonths={setMonths} invest={invest}/>} 
      {tab==="league"&&<League/>}
    </section>

    <nav className="k-mobile-nav"><MobileNav icon="⌂" active={tab==="home"} label="Accueil" onClick={()=>setTab("home")}/><MobileNav icon="◉" active={tab==="learn"} label="Apprendre" onClick={()=>setTab("learn")}/><MobileNav icon="↗" active={tab==="invest"} label="Investir" onClick={()=>setTab("invest")}/><MobileNav icon="♛" active={tab==="league"} label="Classement" onClick={()=>setTab("league")}/></nav>
    {toast&&<div className="k-toast">✓ {toast}</div>}
  </main>;
}

function Home({balance,goLearn,goInvest}:{balance:number;goLearn:()=>void;goInvest:()=>void}){
  return <>
    <section className="welcome-row"><div><span className="hello">Bonjour Cyril 👋</span><h1>Fais grandir ton argent.<br/><em>Sans risquer le tien.</em></h1><p>Konsens reproduit la vraie vie financière avec de l’argent 100 % virtuel.</p></div><div className="level-ring"><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="42"/><circle className="progress" cx="50" cy="50" r="42"/></svg><strong>65%</strong><small>NIVEAU 3</small></div></section>
    <section className="money-panel"><div><span>MON ARGENT VIRTUEL</span><strong>{balance.toLocaleString("fr-FR")} €</strong><small>1 € virtuel = 1 € dans la simulation</small></div><button onClick={goInvest}>Faire travailler mon argent <b>→</b></button></section>
    <section className="daily-lesson"><div className="lesson-badge">3 min</div><div className="lesson-copy"><span>MISSION DU JOUR · +50 XP</span><h2>Un ETF, c’est quoi exactement ?</h2><p>Découvre comment investir dans des centaines d’entreprises en un seul achat.</p><button onClick={goLearn}>Commencer la mission</button></div><div className="basket-visual"><div className="basket"><i>A</i><i></i><i>N</i><i>V</i></div><span>1 ETF</span><small>= un panier d’entreprises</small></div></section>
    <section className="dashboard-row"><div className="journey"><header><div><span>TON PARCOURS</span><h2>Apprenti investisseur</h2></div><b>2/5 notions</b></header><div className="journey-line"><i className="done">✓<small>Budget</small></i><span/><i className="done">✓<small>Risque</small></i><span/><i className="current">3<small>ETF</small></i><span/><i>4<small>Actions</small></i><span/><i>5<small>Prédire</small></i></div></div><div className="mini-rank"><span>TA LIGUE</span><strong>#3</strong><p>Tu as gagné 2 places cette semaine</p><div><i style={{width:"72%"}}/></div></div></section>
  </>;
}

function Learn({amount,setAmount,choice,setChoice,months,setMonths}:{amount:number;setAmount:(n:number)=>void;choice:Choice;setChoice:(c:Choice)=>void;months:number;setMonths:(n:number)=>void}){
  return <section className="learning-page">
    <header className="page-heading"><span>APPRENDRE EN JOUANT</span><h1>Que peut devenir ton argent ?</h1><p>Choisis une somme, compare les solutions et comprends chaque calcul.</p></header>
    <Simulator amount={amount} setAmount={setAmount} choice={choice} setChoice={setChoice} months={months} setMonths={setMonths}/>
    <section className="concepts"><h2>Les mots à connaître</h2><div><Concept icon="€" title="Capital" text="La somme de départ que tu investis."/><Concept icon="%" title="Rendement" text="Ce que ton placement gagne ou perd, en pourcentage."/><Concept icon="◒" title="Risque" text="La possibilité de récupérer moins que ta mise."/><Concept icon="⌛" title="Horizon" text="La durée pendant laquelle tu laisses travailler l’argent."/></div></section>
  </section>;
}

function Invest({balance,amount,setAmount,choice,setChoice,months,setMonths,invest}:{balance:number;amount:number;setAmount:(n:number)=>void;choice:Choice;setChoice:(c:Choice)=>void;months:number;setMonths:(n:number)=>void;invest:()=>void}){
  const result=calculate(amount,choice,months);const item=options[choice];
  return <section className="invest-page"><header className="page-heading"><span>SIMULATION RÉELLE</span><h1>Prépare ton investissement</h1><p>Solde disponible : <b>{balance.toLocaleString("fr-FR")} € virtuels</b></p></header><div className="invest-layout"><div><Simulator compact amount={amount} setAmount={setAmount} choice={choice} setChoice={setChoice} months={months} setMonths={setMonths}/></div><aside className="order-summary"><span>CE QUI PEUT SE PASSER</span><h2>{item.name}</h2><div className="summary-flow"><p><small>Tu places</small><strong>{amount.toLocaleString("fr-FR")} €</strong></p><b>→</b><p><small>Valeur simulée</small><strong>{result.value.toLocaleString("fr-FR",{maximumFractionDigits:0})} €</strong></p></div><div className="potential-gain"><span>GAIN POTENTIEL</span><strong>+{result.gain.toLocaleString("fr-FR",{maximumFractionDigits:0})} €</strong><small>Scénario pédagogique, jamais garanti</small></div><button className="confirm" onClick={invest}>Confirmer le placement virtuel</button><p className="no-money">Aucun argent réel · aucun retrait possible</p></aside></div></section>;
}

function Simulator({amount,setAmount,choice,setChoice,months,setMonths,compact=false}:{amount:number;setAmount:(n:number)=>void;choice:Choice;setChoice:(c:Choice)=>void;months:number;setMonths:(n:number)=>void;compact?:boolean}){
  const calculations=useMemo(()=>Object.keys(options).map(key=>({key:key as Choice,...calculate(amount,key as Choice,months)})),[amount,months]);
  return <section className={compact?"simulator compact":"simulator"}>
    <div className="sim-controls"><label>Je veux utiliser<strong>{amount.toLocaleString("fr-FR")} € virtuels</strong><input aria-label="Somme virtuelle" type="range" min="100" max="5000" step="100" value={amount} onChange={e=>setAmount(Number(e.target.value))}/><div><span>100 €</span><span>5 000 €</span></div></label><label>Je laisse mon argent travailler<strong>{months} mois</strong><input aria-label="Durée" type="range" min="1" max="36" value={months} onChange={e=>setMonths(Number(e.target.value))}/><div><span>1 mois</span><span>3 ans</span></div></label></div>
    <div className="comparison"><header><span>OPTION</span><span>RISQUE</span><span>GAIN POTENTIEL</span></header>{calculations.map(row=>{const item=options[row.key];return <button key={row.key} className={choice===row.key?`compare-row selected ${item.color}`:`compare-row ${item.color}`} onClick={()=>setChoice(row.key)}><i>{item.icon}</i><div><strong>{item.name}</strong><small>{item.detail}</small></div><span className="risk">{item.risk}</span><div className="gain"><strong>+{row.gain.toLocaleString("fr-FR",{maximumFractionDigits:0})} €</strong><small>{row.formula}</small></div><b className="radio">{choice===row.key?"✓":""}</b></button>})}</div>
    <div className="teacher-note"><span>💡</span><p><strong>Le plus rentable n’est pas forcément le meilleur choix.</strong> Un gain potentiel élevé signifie généralement que le risque de perdre est aussi plus élevé.</p></div>
  </section>;
}

function League(){return <section className="league-simple"><header className="page-heading"><span>SAISON 1 · LIGUE DÉCOUVERTE</span><h1>Progresse avec les autres</h1><p>Le classement récompense la performance, mais aussi la régularité et la maîtrise du risque.</p></header><div className="rank-table"><header><span>Rang</span><span>Joueur</span><span>Patrimoine</span><span>Performance</span></header>{rankings.map(([rank,name,value,score])=><div className={name==="Cyril"?"you":""} key={name}><b>{rank}</b><span className="rank-avatar">{String(name).slice(0,1)}</span><strong>{name}{name==="Cyril"&&<small>TOI</small>}</strong><span>{Number(value).toLocaleString("fr-FR")} €</span><em>+{score}%</em></div>)}</div><aside className="league-tip"><span>🏆</span><div><strong>Comment gagner des places ?</strong><p>Diversifie tes placements, évite de tout miser sur une prédiction et reviens suivre tes décisions.</p></div></aside></section>}

function calculate(amount:number,choice:Choice,months:number){if(choice==="prediction"){const price=.63;const units=amount/price;const gain=units-amount;return{gain,value:units,formula:`${amount.toLocaleString("fr-FR")} ÷ 0,63 − mise`}}const annual=options[choice].rate/100;const gain=amount*annual*(months/12);return{gain,value:amount+gain,formula:`${amount.toLocaleString("fr-FR")} × ${options[choice].rate}% × ${months}/12`}}
function Concept({icon,title,text}:{icon:string;title:string;text:string}){return <article><i>{icon}</i><strong>{title}</strong><p>{text}</p></article>}
function Nav({active,label,onClick}:{active:boolean;label:string;onClick:()=>void}){return <button className={active?"active":""} onClick={onClick}>{label}</button>}
function MobileNav({active,label,icon,onClick}:{active:boolean;label:string;icon:string;onClick:()=>void}){return <button className={active?"active":""} onClick={onClick}><i>{icon}</i><span>{label}</span></button>}
