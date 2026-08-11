"use client";

import { useEffect, useState } from "react";
import { createClient, type User } from "@supabase/supabase-js";
import FinanceShell from "./finance-shell";
import JourneyV3 from "./journey-v3";
import PredictionV2 from "./prediction-v2";
import LiveFinanceV2 from "./live-finance-v2";
import AcademyV2 from "./academy-v2";
import PremiumV2 from "./premium-v2";
import BlockchainV2 from "./blockchain-v2";
import NotificationCenter from "./notification-center";

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL??"https://mxuevsspybxoovsutsbs.supabase.co",process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY??"sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7");
type Screen="today"|"play"|"invest"|"learn"|"profile"|"network";
type Profile={username:string;role:string;subscription_tier:"free"|"premium";onboarding_completed_at:string|null};
type Wealth={cash_value:number;investments_value:number;bets_value:number;total_value:number};
const empty:Wealth={cash_value:0,investments_value:0,bets_value:0,total_value:1000};

export default function V3Shell(){
 const[user,setUser]=useState<User|null>(null);const[profile,setProfile]=useState<Profile|null>(null);const[wealth,setWealth]=useState<Wealth>(empty);const[screen,setScreen]=useState<Screen>("today");const[ready,setReady]=useState(false);const[refresh,setRefresh]=useState(0);
 useEffect(()=>{let mounted=true;void supabase.auth.getUser().then(({data})=>{if(mounted)setUser(data.user);if(mounted)setReady(true)});const{data}=supabase.auth.onAuthStateChange((_event,session)=>{setUser(session?.user??null);setRefresh(x=>x+1)});return()=>{mounted=false;data.subscription.unsubscribe()}},[]);
 useEffect(()=>{if(!user){setProfile(null);return}let active=true;void(async()=>{const[p,w]=await Promise.all([supabase.from("profiles").select("username,role,subscription_tier,onboarding_completed_at").eq("id",user.id).single(),supabase.rpc("get_my_wealth_snapshot")]);if(!active)return;if(p.data)setProfile(p.data as Profile);const row=Array.isArray(w.data)?w.data[0]:w.data;if(row)setWealth({cash_value:Number(row.cash_value),investments_value:Number(row.investments_value),bets_value:Number(row.bets_value),total_value:Number(row.total_value)})})();return()=>{active=false}},[user,refresh]);
 useEffect(()=>{const update=()=>setRefresh(x=>x+1);window.addEventListener("konsens:trade",update);window.addEventListener("konsens:subscription",update);return()=>{window.removeEventListener("konsens:trade",update);window.removeEventListener("konsens:subscription",update)}},[]);
 if(!ready)return <div className="v3-gate-loading"><img src="/konsens-logo.png" alt="Konsens"/><span>Préparation de ton parcours…</span></div>;
 if(!user||!profile?.onboarding_completed_at)return <FinanceShell/>;
 const premium=profile.subscription_tier==="premium";
 const journeyGo=(to:"play"|"invest"|"learn"|"profile"|"network")=>setScreen(to);
 const notificationGo=(to:"play"|"invest"|"profile")=>setScreen(to);
 return <main className={`v3-app world-${screen}`}><header className="v3-header"><button className="v3-brand" onClick={()=>setScreen("today")}><img src="/konsens-logo.png" alt="Konsens"/><div><b>Konsens</b><span>ENTRAÎNE TON INTELLIGENCE FINANCIÈRE</span></div></button><div className="v3-head-right"><NotificationCenter userId={user.id} onNavigate={notificationGo}/><button className="v3-koin" onClick={()=>setScreen("profile")}><span>{premium?"PREMIUM":"KOINS"}</span><b>{Math.round(wealth.total_value)}</b><small>patrimoine</small></button></div></header>
 <section className="v3-content">{screen==="today"&&<JourneyV3 username={profile.username} cash={wealth.cash_value} premium={premium} go={journeyGo}/>} {screen==="play"&&<PredictionV2 cash={wealth.cash_value} role={profile.role}/>} {screen==="invest"&&<LiveFinanceV2 cash={wealth.cash_value} premium={premium}/>} {screen==="learn"&&<AcademyV2/>} {screen==="network"&&<BlockchainV2 premium={premium} role={profile.role}/>} {screen==="profile"&&<V3Profile username={profile.username} premium={premium} wealth={wealth} role={profile.role} go={setScreen}/>}</section>
 <nav className="v3-nav" aria-label="Navigation Konsens"><Nav active={screen==="today"} icon="◎" label="Aujourd’hui" onClick={()=>setScreen("today")}/><Nav active={screen==="play"} icon="◆" label="Prédire" onClick={()=>setScreen("play")}/><Nav active={screen==="invest"} icon="↗" label="Décider" onClick={()=>setScreen("invest")}/><Nav active={screen==="learn"} icon="▤" label="Apprendre" onClick={()=>setScreen("learn")}/><Nav active={screen==="profile"||screen==="network"} icon="◌" label="Progresser" onClick={()=>setScreen("profile")}/></nav></main>
}

function Nav({active,icon,label,onClick}:{active:boolean;icon:string;label:string;onClick:()=>void}){return <button className={active?"active":""} onClick={onClick}><i>{icon}</i><span>{label}</span></button>}
function V3Profile({username,premium,wealth,role,go}:{username:string;premium:boolean;wealth:Wealth;role:string;go:(s:Screen)=>void}){const[score,setScore]=useState<any>(null);useEffect(()=>{void supabase.rpc("get_my_konsens_score").then(({data})=>{const r=Array.isArray(data)?data[0]:data;if(r)setScore(r)})},[]);return <section className="v3-profile"><header><span>PROGRESSER</span><h1>@{username}</h1><p>Ton profil ne juge pas seulement ce que tu as gagné. Il mesure comment tu apprends, calibres tes convictions et gères le risque.</p></header><section className="v3-score-card"><div><span>KONSENS SCORE</span><strong>{Math.round(Number(score?.total_score??50))}<small>/100</small></strong><b>{score?.archetype??"Explorateur"}</b></div><div><Metric label="Prévision" value={score?.prediction_score}/><Metric label="Risque" value={score?.risk_score}/><Metric label="Connaissance" value={score?.knowledge_score}/><Metric label="Discipline" value={score?.discipline_score}/></div></section><div className="v3-profile-grid"><article><span>PATRIMOINE FICTIF</span><b>{Math.round(wealth.total_value)} K</b><small>{Math.round(wealth.cash_value)} disponibles · {Math.round(wealth.investments_value)} investis · {Math.round(wealth.bets_value)} en prédictions</small></article><button onClick={()=>go("network")}><span>TRANSPARENCE BLOCKCHAIN</span><b>Whale Watch</b><small>{premium?"Alertes Premium actives":"Lecture publique · alertes Premium"}</small></button></div><PremiumV2/>{role==="admin"&&<div className="v3-admin-links"><a href="/monetization">Monétisation</a><a href="/monetization/providers">Fournisseurs</a><a href="/monetization/ads">Publicité</a></div>}<button className="v3-logout" onClick={()=>supabase.auth.signOut()}>Se déconnecter</button></section>}
function Metric({label,value}:{label:string;value:any}){const n=Math.round(Number(value??50));return <div><span>{label}</span><b>{n}</b><i><em style={{width:`${n}%`}}/></i></div>}
