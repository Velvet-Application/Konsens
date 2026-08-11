"use client";

/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useMemo, useState } from "react";
import { createClient, type User } from "@supabase/supabase-js";
import AcademyV2 from "./academy-v2";
import LiveFinanceV2 from "./live-finance-v2";
import PredictionV2 from "./prediction-v2";
import PremiumV2 from "./premium-v2";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co",
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",
);

type Screen = "wealth" | "play" | "invest" | "learn" | "profile" | "admin";
type Profile = { username:string; first_name:string|null; last_name:string|null; birth_date:string|null; email:string|null; role:string; onboarding_completed_at:string|null; subscription_tier:"free"|"premium"; journey_mode:"balanced"|"play"|"learn"; risk_acknowledged_at:string|null };
type Wealth = { cash_value:number; investments_value:number; bets_value:number; total_value:number };
type Asset = { id:string; symbol:string; name:string; kind:string };
type Market = { id:string; question:string };
type Lesson = { id:string; title:string; duration_minutes:number };

const emptyWealth:Wealth = { cash_value:0, investments_value:0, bets_value:0, total_value:0 };
const fmt = (n:number) => new Intl.NumberFormat("fr-FR", { maximumFractionDigits:0 }).format(n);

function Icon({name}:{name:"home"|"play"|"chart"|"book"|"user"|"lock"|"shield"}){
  const d={home:"M3 11 12 4l9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",play:"M8 5v14l11-7z",chart:"M4 19V9m6 10V5m6 14v-7m4 7H2",book:"M4 5a4 4 0 0 1 4-2h4v17H8a4 4 0 0 0-4 2zm16 0a4 4 0 0 0-4-2h-4v17h4a4 4 0 0 1 4 2z",user:"M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm7 9a7 7 0 0 0-14 0",lock:"M7 11V8a5 5 0 0 1 10 0v3m-9 0h8a2 2 0 0 1 2 2v7H6v-7a2 2 0 0 1 2-2z",shield:"M12 3l8 3v5c0 5-3.4 8.7-8 10-4.6-1.3-8-5-8-10V6z"}[name];
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d={d}/></svg>;
}

function Brand(){return <div className="f-brand"><span className="f-mark"><b>K</b><i/><i/><i/></span><div><strong>Konsens</strong><small>PRÉDIRE · APPRENDRE · INVESTIR</small></div></div>}

export default function FinanceShell(){
  const [user,setUser]=useState<User|null>(null); const [loading,setLoading]=useState(true); const [profile,setProfile]=useState<Profile|null>(null); const [screen,setScreen]=useState<Screen>("wealth");
  const [wealth,setWealth]=useState<Wealth>(emptyWealth); const [assets,setAssets]=useState<Asset[]>([]); const [markets,setMarkets]=useState<Market[]>([]); const [lessons,setLessons]=useState<Lesson[]>([]); const [toast,setToast]=useState(""); const [refresh,setRefresh]=useState(0);
  useEffect(()=>{void supabase.auth.getUser().then(({data})=>{setUser(data.user);setLoading(false)});const{data}=supabase.auth.onAuthStateChange((_event,session)=>{setUser(session?.user??null);setLoading(false)});return()=>data.subscription.unsubscribe()},[]);
  useEffect(()=>{const listener=()=>setRefresh(x=>x+1);window.addEventListener("konsens:trade",listener);window.addEventListener("konsens:subscription",listener);return()=>{window.removeEventListener("konsens:trade",listener);window.removeEventListener("konsens:subscription",listener)}},[]);
  useEffect(()=>{if(!user){setProfile(null);return}let active=true;void(async()=>{await supabase.rpc("refresh_my_premium_status");const [p,w,l,m,a]=await Promise.all([
    supabase.from("profiles").select("username,first_name,last_name,birth_date,email,role,onboarding_completed_at,subscription_tier,journey_mode,risk_acknowledged_at").eq("id",user.id).single(),
    supabase.rpc("get_my_wealth_snapshot"),
    supabase.from("learning_modules").select("id,title,duration_minutes").eq("is_active",true).order("position"),
    supabase.from("markets").select("id,question").eq("status","open"),
    supabase.from("assets").select("id,symbol,name,kind").eq("is_active",true).like("external_ref","market:%")
  ]);if(!active)return;if(p.data)setProfile(p.data as Profile);const ws=Array.isArray(w.data)?w.data[0]:w.data;if(ws)setWealth({cash_value:Number(ws.cash_value),investments_value:Number(ws.investments_value),bets_value:Number(ws.bets_value),total_value:Number(ws.total_value)});setLessons((l.data??[]) as Lesson[]);setMarkets((m.data??[]) as Market[]);setAssets((a.data??[]) as Asset[])})();return()=>{active=false}},[user,refresh]);
  const notify=(message:string)=>{setToast(message);window.setTimeout(()=>setToast(""),2600)};
  if(loading)return <main className="f-loading"><Brand/><span/></main>;
  if(!user)return <Auth/>;
  if(!profile?.onboarding_completed_at)return <Onboarding user={user} done={()=>setRefresh(x=>x+1)}/>;
  const perf=((wealth.total_value-1000)/1000)*100;
  const acknowledge=async()=>{await supabase.from("profiles").update({risk_acknowledged_at:new Date().toISOString()}).eq("id",user.id);notify("Risque pédagogique confirmé");setRefresh(x=>x+1)};
  return <main className="finance-app"><div className="f-ambient f-a"/><div className="f-ambient f-b"/><header className="f-float-head"><button onClick={()=>setScreen("wealth")} className="f-brand-button"><Brand/></button><button onClick={()=>setScreen("profile")} className="f-wealth-pill"><span>{profile.subscription_tier==="premium"?"PREMIUM":"PATRIMOINE"}</span><strong>{fmt(wealth.total_value)} <small>Koins</small></strong><i className={perf>=0?"up":"down"}>{perf>=0?"+":""}{perf.toFixed(1)}%</i></button></header>
  <section className="beta-content finance-content">
    {screen==="wealth"&&<WealthHome profile={profile} wealth={wealth} perf={perf} lessons={lessons} markets={markets} assets={assets} go={setScreen} acknowledge={acknowledge}/>} 
    {screen==="play"&&<PredictionV2 cash={wealth.cash_value} role={profile.role}/>} 
    {screen==="invest"&&<LiveFinanceV2 cash={wealth.cash_value} premium={profile.subscription_tier==="premium"}/>} 
    {screen==="learn"&&<AcademyV2/>} 
    {screen==="profile"&&<ProfileView profile={profile} wealth={wealth} go={setScreen}/>} 
    {screen==="admin"&&profile.role==="admin"&&<Admin/>}
  </section><Dock screen={screen} go={setScreen}/>{toast&&<div className="f-toast">{toast}</div>}</main>
}

function Dock({screen,go}:{screen:Screen;go:(s:Screen)=>void}){const items:[Screen,string,"home"|"play"|"chart"|"book"|"user"][]=[["wealth","Patrimoine","home"],["play","Jouer","play"],["invest","Investir","chart"],["learn","Apprendre","book"],["profile","Profil","user"]];return <nav className="f-dock" aria-label="Navigation principale">{items.map(([id,label,icon])=><button key={id} onClick={()=>go(id)} className={screen===id?"active":""}><Icon name={icon}/><span>{label}</span></button>)}</nav>}

function WealthHome({profile,wealth,perf,lessons,markets,assets,go,acknowledge}:{profile:Profile;wealth:Wealth;perf:number;lessons:Lesson[];markets:Market[];assets:Asset[];go:(s:Screen)=>void;acknowledge:()=>void}){const minutes=lessons.reduce((n,l)=>n+l.duration_minutes,0);return <><section className="f-hero"><div className="f-hero-copy"><span className="eyebrow">TON LABORATOIRE FINANCIER · DONNÉES CONNECTÉES</span><h1>Fais grandir ton patrimoine.<br/><em>Comprends chaque décision.</em></h1><p>1 000 Koins au départ. Aucun argent réel. Les prix de marché servent désormais de référence aux simulations, les prédictions évoluent avec les positions, et Academy t’emmène jusqu’à un vrai niveau de compréhension.</p><div className="hero-actions"><button onClick={()=>go("invest")}>Voir les marchés réels</button><button onClick={()=>go("play")}>Ouvrir les prédictions</button></div></div><article className="wealth-card"><div><span>PATRIMOINE TOTAL</span><b className={perf>=0?"positive":"negative"}>{perf>=0?"+":""}{perf.toFixed(1)}%</b></div><strong>{fmt(wealth.total_value)} <small>Koins</small></strong><div className="wealth-line"><svg viewBox="0 0 420 90" preserveAspectRatio="none"><path d="M0 62 C70 60 105 60 150 59 S250 58 310 58 S370 58 420 58"/></svg><i>Départ 1 000</i></div><div className="wealth-split"><p><span>Disponible</span><b>{fmt(wealth.cash_value)}</b></p><p><span>Investi</span><b>{fmt(wealth.investments_value)}</b></p><p><span>En paris</span><b>{fmt(wealth.bets_value)}</b></p></div></article></section>
  {!profile.risk_acknowledged_at&&<section className="risk-banner"><Icon name="shield"/><div><strong>Le but n’est pas seulement de gagner.</strong><p>Konsens montre la perte, la volatilité, les frais et le coût d’une mauvaise décision. Les Koins n’ont aucune valeur monétaire et ne sont jamais convertibles.</p></div><button onClick={acknowledge}>J’ai compris</button></section>}
  <section className="f-grid"><button className="feature-card play-card" onClick={()=>go("play")}><span>JOUER · MARCHÉ DYNAMIQUE</span><strong>{markets.length?`${markets.length} marchés ouverts`:"Générer le premier marché"}</strong><p>Sources, probabilités, historique, volume, achat et revente en Koins.</p><i>Ouvrir Prediction Market →</i></button><button className="feature-card invest-card" onClick={()=>go("invest")}><span>INVESTIR · PRIX RÉELS</span><strong>{assets.length} actifs connectés</strong><p>Actions, ETF et crypto : cours horodaté et historique réel, ordre toujours simulé.</p><i>Ouvrir le terminal →</i></button><button className="feature-card learn-card" onClick={()=>go("learn")}><span>APPRENDRE · CURSUS</span><strong>{lessons.length} modules · ~{Math.round(minutes/60)} h</strong><p>Chapitres détaillés, exemples, schémas, ressources vidéo, quiz et progression.</p><i>Commencer Academy →</i></button></section>
  <PremiumV2 compact/></>}

function ProfileView({profile,wealth,go}:{profile:Profile;wealth:Wealth;go:(s:Screen)=>void}){return <section className="f-page profile-new"><PageTitle tag="MON ESPACE" title={`@${profile.username}`} text={`${profile.subscription_tier==="premium"?"Konsens Premium":"Konsens Gratuit"} · patrimoine ${fmt(wealth.total_value)} Koins`}/><div className="profile-cards"><article><span>PARCOURS</span><h2>{profile.journey_mode==="play"?"Joueur":profile.journey_mode==="learn"?"Apprenant":"Équilibré"}</h2><p>Finance réelle comme référence, simulation en Koins et formation progressive restent séparées de tout investissement d’argent réel.</p></article><article><span>NETWORK</span><h2>API · Ads · Blockchain</h2><p>Le moteur publicitaire, Konsens Connect et le suivi de portefeuilles publics sont actifs dans la bêta.</p></article></div><PremiumV2/>{profile.role==="admin"&&<button className="admin-entry" onClick={()=>go("admin")}>Ouvrir le centre d’administration →</button>}<button className="logout" onClick={()=>supabase.auth.signOut()}>Se déconnecter</button></section>}

function Admin(){return <section className="f-page"><PageTitle tag="ADMINISTRATION" title="Centre de pilotage" text="Pilote la monétisation puis génère les nouveaux marchés depuis l’onglet Jouer."/><a className="admin-link" href="/monetization">Ouvrir Konsens Monetization →</a></section>}
function PageTitle({tag,title,text}:{tag:string;title:string;text:string}){return <header className="f-page-title"><span>{tag}</span><h1>{title}</h1><p>{text}</p></header>}

function Auth(){const[email,setEmail]=useState("");const[password,setPassword]=useState("");const[mode,setMode]=useState<"signup"|"login">("login");const[status,setStatus]=useState("");const social=async(provider:"google"|"apple")=>{const{error}=await supabase.auth.signInWithOAuth({provider,options:{redirectTo:location.origin}});if(error)setStatus(error.message)};const submit=async(e:React.FormEvent)=>{e.preventDefault();setStatus("Connexion…");const result=mode==="signup"?await supabase.auth.signUp({email,password,options:{emailRedirectTo:location.origin}}):await supabase.auth.signInWithPassword({email,password});setStatus(result.error?.message??(mode==="signup"?"Vérifie ta boîte mail pour confirmer ton inscription.":"Connecté."))};return <main className="finance-auth"><section className="auth-pitch"><Brand/><span>1 000 KOINS OFFERTS</span><h1>Ton argent fictif.<br/><em>De vraies leçons.</em></h1><p>Prédis, investis, apprends. Construis un patrimoine virtuel avec des données de marché réelles et découvre ce que tes décisions peuvent coûter.</p><div className="auth-proof"><b>0 € réel</b><b>Marchés connectés</b><b>Risque visible</b></div></section><section className="auth-panel"><span>BIENVENUE</span><h2>{mode==="login"?"Reprendre mon parcours":"Créer mon portefeuille"}</h2><div className="social"><button onClick={()=>social("apple")}>Continuer avec Apple</button><button onClick={()=>social("google")}>Continuer avec Google</button></div><i>ou</i><form onSubmit={submit}><label>Email<input required type="email" value={email} onChange={e=>setEmail(e.target.value)}/></label><label>Mot de passe<input required minLength={8} type="password" value={password} onChange={e=>setPassword(e.target.value)}/></label><button className="primary">{mode==="login"?"Me connecter":"Créer mon compte"}</button></form>{status&&<p>{status}</p>}<button className="auth-switch" onClick={()=>setMode(mode==="login"?"signup":"login")}>{mode==="login"?"Créer un compte":"J’ai déjà un compte"}</button><small>Les Koins sont une unité virtuelle sans valeur monétaire. Konsens ne permet aucun dépôt, retrait ou conversion en argent.</small></section></main>}

function Onboarding({user,done}:{user:User;done:()=>void}){const[today]=useState(()=>Date.now());const[p,setP]=useState({username:"",first_name:"",last_name:"",birth_date:"",email:user.email??""});const age=useMemo(()=>p.birth_date?Math.floor((today-new Date(p.birth_date).getTime())/31557600000):0,[p.birth_date,today]);const save=async()=>{if(age<18)return;const{error}=await supabase.from("profiles").update({...p,onboarding_completed_at:new Date().toISOString(),journey_mode:"balanced"}).eq("id",user.id);if(!error)done()};return <main className="finance-auth onboarding-new"><section className="auth-pitch"><Brand/><span>TON POINT DE DÉPART</span><h1>1 000 Koins.<br/><em>À toi de décider.</em></h1><p>Tu pourras les conserver, les investir ou les engager dans des prédictions. Ton patrimoine suivra chaque choix.</p></section><section className="auth-panel"><span>PROFIL</span><h2>Créons ton identité Konsens</h2><label>Pseudo public<input value={p.username} onChange={e=>setP({...p,username:e.target.value.replace(/[^a-zA-Z0-9_]/g,"")})}/></label><div className="field-pair"><label>Prénom<input value={p.first_name} onChange={e=>setP({...p,first_name:e.target.value})}/></label><label>Nom<input value={p.last_name} onChange={e=>setP({...p,last_name:e.target.value})}/></label></div><label>Date de naissance<input type="date" value={p.birth_date} onChange={e=>setP({...p,birth_date:e.target.value})}/></label>{p.birth_date&&age<18&&<p>Konsens est actuellement réservé aux personnes majeures.</p>}<button className="primary" disabled={p.username.length<3||!p.first_name||!p.last_name||age<18} onClick={save}>Recevoir mes 1 000 Koins</button></section></main>}
