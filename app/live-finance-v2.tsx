"use client";
/* eslint-disable react-hooks/set-state-in-effect */

import { useEffect, useMemo, useState } from "react";
import { createClient } from "@supabase/supabase-js";

type Asset = { id:string; symbol:string; name:string; kind:string; currency:string; external_ref:string };
type Point = { t:number; price:number };
type Quote = { symbol:string; currency:string; exchange:string; price:number; previousClose:number; change:number; changePct:number; updatedAt:string; points:Point[]; provider:string };
type Position = { id:string; asset_id:string; quantity:number; average_price:number };
type QuoteEnvelope = { quote?:Quote; detail?:string; error?:string };

type PortfolioRow = {
  asset: Asset;
  position: Position;
  quote?: Quote;
  value: number;
  cost: number;
  pnl: number;
  pnlPct: number;
};

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co",
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",
);
const fnBase = (process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co") + "/functions/v1/market-data";

function tradeMessage(raw?: string | null) {
  if (!raw) return "Ordre refusé.";
  if (raw.includes("insufficient_credits")) return "Tu n’as pas assez de Koins disponibles pour cet ordre.";
  if (raw.includes("insufficient_position")) return "Ta position est trop petite pour revendre ce montant.";
  if (raw.includes("market_unavailable")) return "Le cours de référence est momentanément indisponible.";
  if (raw.includes("wallet_missing")) return "Ton portefeuille Konsens n’est pas encore initialisé.";
  return raw;
}

export default function LiveFinanceV2({ cash, premium }: { cash:number; premium:boolean }) {
  const [assets,setAssets] = useState<Asset[]>([]);
  const [selected,setSelected] = useState<Asset|null>(null);
  const [quotes,setQuotes] = useState<Record<string,Quote>>({});
  const [positions,setPositions] = useState<Position[]>([]);
  const [watched,setWatched] = useState<string[]>([]);
  const [filter,setFilter] = useState<"all"|"watched">("all");
  const [range,setRange] = useState("1mo");
  const [amount,setAmount] = useState(100);
  const [status,setStatus] = useState("");
  const [busy,setBusy] = useState(false);

  async function loadQuote(asset:Asset, r:string, show=true) {
    const symbol = asset.external_ref.replace("market:","");
    try {
      if (show) setStatus("Actualisation du marché…");
      const res = await fetch(`${fnBase}?symbol=${encodeURIComponent(symbol)}&range=${r}&interval=${r==="1d"?"15m":"1d"}`);
      const body = (await res.json()) as QuoteEnvelope;
      if (!res.ok || !body.quote) throw new Error(body.detail ?? body.error ?? "Flux indisponible");
      setQuotes(q => ({...q,[asset.id]:body.quote as Quote}));
      if (show) setStatus("");
      return body.quote;
    } catch (e) {
      if (show) setStatus(e instanceof Error ? e.message : "Flux indisponible");
      return undefined;
    }
  }

  async function reloadPositions() {
    const {data:auth} = await supabase.auth.getUser();
    if (!auth.user) return;
    const {data:p} = await supabase.from("positions")
      .select("id,asset_id,quantity,average_price")
      .eq("user_id",auth.user.id)
      .not("asset_id","is",null);
    setPositions(((p ?? []) as Array<{id:string;asset_id:string;quantity:number|string;average_price:number|string}>).map(x => ({...x,quantity:Number(x.quantity),average_price:Number(x.average_price)})));
  }

  useEffect(() => {
    void (async () => {
      const {data:auth} = await supabase.auth.getUser();
      const [a,p,w] = await Promise.all([
        supabase.from("assets").select("id,symbol,name,kind,currency,external_ref").eq("is_active",true).like("external_ref","market:%").order("kind").order("symbol"),
        auth.user ? supabase.from("positions").select("id,asset_id,quantity,average_price").eq("user_id",auth.user.id).not("asset_id","is",null) : Promise.resolve({data:[]}),
        auth.user ? supabase.from("asset_watchlist").select("asset_id").eq("user_id",auth.user.id) : Promise.resolve({data:[]}),
      ]);
      const rows = (a.data ?? []) as Asset[];
      setAssets(rows);
      setSelected(x => x ?? rows[0] ?? null);
      setPositions(((p.data ?? []) as Array<{id:string;asset_id:string;quantity:number|string;average_price:number|string}>).map(x => ({...x,quantity:Number(x.quantity),average_price:Number(x.average_price)})));
      setWatched(((w.data ?? []) as {asset_id:string}[]).map(x => x.asset_id));
    })();
  },[]);

  useEffect(() => {
    if (!selected) return;
    void loadQuote(selected,range);
  },[selected,range]);

  useEffect(() => {
    if (!assets.length) return;
    void Promise.all(assets.slice(0,10).map(a => loadQuote(a,"5d",false)));
  },[assets]);

  const visibleAssets = useMemo(() => filter === "watched" ? assets.filter(a => watched.includes(a.id)) : assets,[assets,watched,filter]);
  const quote = selected ? quotes[selected.id] : undefined;
  const position = selected ? positions.find(p => p.asset_id === selected.id) : undefined;
  const positionValue = position && quote ? position.quantity * quote.price : 0;

  const portfolioRows = useMemo<PortfolioRow[]>(() => positions
    .map(position => {
      const asset = assets.find(a => a.id === position.asset_id);
      if (!asset) return null;
      const q = quotes[asset.id];
      const cost = position.quantity * position.average_price;
      const value = q ? position.quantity * q.price : cost;
      const pnl = value - cost;
      const pnlPct = cost > 0 ? (pnl / cost) * 100 : 0;
      return {asset,position,quote:q,value,cost,pnl,pnlPct};
    })
    .filter((row): row is PortfolioRow => Boolean(row))
    .sort((a,b) => b.value-a.value),[positions,assets,quotes]);

  const portfolioValue = portfolioRows.reduce((n,row) => n+row.value,0);
  const portfolioCost = portfolioRows.reduce((n,row) => n+row.cost,0);
  const portfolioPnl = portfolioValue-portfolioCost;
  const investedCount = portfolioRows.length;

  const toggleWatch = async () => {
    if (!selected) return;
    const {data:auth} = await supabase.auth.getUser();
    if (!auth.user) { setStatus("Reconnecte-toi pour gérer tes suivis."); return; }
    const active = watched.includes(selected.id);
    setWatched(old => active ? old.filter(id => id!==selected.id) : [...old,selected.id]);
    const result = active
      ? await supabase.from("asset_watchlist").delete().eq("user_id",auth.user.id).eq("asset_id",selected.id)
      : await supabase.from("asset_watchlist").insert({user_id:auth.user.id,asset_id:selected.id});
    if (result.error) {
      setWatched(old => active ? [...old,selected.id] : old.filter(id => id!==selected.id));
      setStatus("Impossible de modifier les suivis.");
    } else {
      setStatus(active ? `${selected.symbol} retiré de tes suivis.` : `${selected.symbol} ajouté à tes suivis.`);
    }
  };

  const trade = async (side:"buy"|"sell") => {
    if (!selected || !quote || busy) return;
    const {data:auth} = await supabase.auth.getUser();
    if (!auth.user) { setStatus("Reconnecte-toi pour passer un ordre simulé."); return; }
    setBusy(true);
    await loadQuote(selected,"5d",false);
    setStatus(side === "buy" ? "Achat simulé…" : "Revente simulée…");
    const {data,error} = await supabase.from("trade_orders").insert({
      user_id:auth.user.id,
      asset_id:selected.id,
      market_id:null,
      side,
      outcome:null,
      credits:amount,
      idempotency_key:crypto.randomUUID(),
    }).select("status,rejection_reason,execution_price").single();
    if (error || data?.status !== "executed") {
      setStatus(tradeMessage(data?.rejection_reason ?? error?.message));
      setBusy(false);
      return;
    }
    const execution = Number(data.execution_price ?? quote.price);
    setStatus(side === "buy"
      ? `Achat de ${amount} Koins exécuté à ${execution.toFixed(2)} ${quote.currency || selected.currency}.`
      : `Revente de ${amount} Koins exécutée à ${execution.toFixed(2)} ${quote.currency || selected.currency}.`);
    await reloadPositions();
    window.dispatchEvent(new Event("konsens:trade"));
    setBusy(false);
  };

  return <section className="live-finance">
    <header className="live-finance-head">
      <div><span>PASSERELLE MARCHÉS · BÊTA LIVE</span><h1>Cours réels. Argent fictif.</h1><p>Les Koins simulent l’achat et la revente, mais le prix de référence et l’historique viennent d’un flux de marché externe horodaté. Aucun ordre n’est envoyé à une bourse.</p></div>
      <div className="market-live-pill"><i/>MARCHÉ CONNECTÉ</div>
    </header>

    <section className="finance-commandbar">
      <div><button className={filter==="all"?"active":""} onClick={()=>setFilter("all")}>Tous les marchés</button><button className={filter==="watched"?"active":""} onClick={()=>setFilter("watched")}>★ Mes suivis <b>{watched.length}</b></button></div>
      <aside><span>{assets.length}<small>actifs connectés</small></span><span>{watched.length}<small>suivis</small></span><span>{investedCount}<small>positions</small></span></aside>
    </section>

    {portfolioRows.length > 0 && <section className="finance-portfolio">
      <header><div><span>MON PORTEFEUILLE</span><h2>Suivre mes investissements</h2></div><div className="finance-portfolio-total"><b>{portfolioValue.toFixed(0)} K</b><small className={portfolioPnl>=0?"positive":"negative"}>{portfolioPnl>=0?"+":""}{portfolioPnl.toFixed(1)} K</small></div></header>
      <div className="finance-position-grid">{portfolioRows.map(row => <button key={row.position.id} onClick={()=>setSelected(row.asset)} className={selected?.id===row.asset.id?"active":""}>
        <div><b>{row.asset.symbol}</b><span>{row.asset.name}</span></div>
        <strong>{row.value.toFixed(0)} K</strong>
        <i className={row.pnl>=0?"positive":"negative"}>{row.pnl>=0?"+":""}{row.pnl.toFixed(1)} K · {row.pnlPct>=0?"+":""}{row.pnlPct.toFixed(2)}%</i>
        <small>PRU {row.position.average_price.toFixed(2)} · {row.position.quantity.toFixed(4)} unités</small>
      </button>)}</div>
      <footer><span>Coût simulé : {portfolioCost.toFixed(0)} K</span><span>Valeur actuelle : {portfolioValue.toFixed(0)} K</span><span>Performance latente : {portfolioPnl>=0?"+":""}{portfolioPnl.toFixed(1)} K</span></footer>
    </section>}

    {filter==="watched" && visibleAssets.length===0
      ? <div className="finance-empty-watch"><b>☆</b><h3>Aucun marché suivi</h3><p>Ouvre un actif et ajoute-le à tes suivis. Il remontera ici et dans le widget Finance.</p><button onClick={()=>setFilter("all")}>Explorer les marchés</button></div>
      : <div className="ticker-rail">{visibleAssets.map(a => { const q=quotes[a.id]; return <button key={a.id} onClick={()=>setSelected(a)} className={selected?.id===a.id?"active":""}><b>{a.symbol}{watched.includes(a.id)?<em>★</em>:null}</b><span>{q?q.price.toFixed(2):"…"}</span><i className={(q?.changePct??0)>=0?"up":"down"}>{q?`${q.changePct>=0?"+":""}${q.changePct.toFixed(2)}%`:"chargement"}</i></button>})}</div>}

    {selected && <div className="market-terminal">
      <aside>
        <div className="finance-asset-kicker"><span>{selected.kind.toUpperCase()}</span><button className={watched.includes(selected.id)?"active":""} onClick={toggleWatch}>{watched.includes(selected.id)?"★ SUIVI":"☆ SUIVRE"}</button></div>
        <h2>{selected.name}</h2><b>{quote?`${quote.price.toFixed(2)} ${quote.currency||selected.currency}`:"—"}</b>
        {quote && <i className={quote.changePct>=0?"positive":"negative"}>{quote.changePct>=0?"+":""}{quote.changePct.toFixed(2)}% · {quote.exchange}</i>}
        <p>{quote?`Dernière donnée : ${new Date(quote.updatedAt).toLocaleString("fr-FR")} · ${quote.provider}`:"Connexion au fournisseur…"}</p>
        <div className="position-box"><span>POSITION KONSENS</span><strong>{position&&quote?`${positionValue.toFixed(0)} Koins`:"Aucune position"}</strong>{position&&<small>{position.quantity.toFixed(4)} unités · PRU {position.average_price.toFixed(2)}</small>}</div>
      </aside>
      <main><div className="chart-toolbar"><div>{["1d","5d","1mo","6mo","1y","5y"].map(r=><button key={r} className={range===r?"active":""} onClick={()=>setRange(r)}>{r.toUpperCase()}</button>)}</div><span>HISTORIQUE DU COURS</span></div><PriceChart points={quote?.points??[]}/></main>
    </div>}

    <div className="trade-ticket">
      <div><span>TAILLE DE L’ORDRE · {Math.round(cash)} K disponibles</span>{[25,50,100,250].map(n=><button key={n} className={amount===n?"active":""} onClick={()=>setAmount(n)}>{n} K</button>)}</div>
      <button className="buy" disabled={busy||!quote||cash<amount} onClick={()=>trade("buy")}>{busy?"Ordre en cours…":"Acheter en simulation"}</button>
      <button className="sell" disabled={busy||!quote||positionValue<amount} onClick={()=>trade("sell")}>{busy?"Ordre en cours…":`Revendre ${amount} K`}</button>
    </div>
    {status && <p className="market-status">{status}</p>}

    <section className="finance-discipline"><div><span>DISCIPLINE D’INVESTISSEMENT</span><h3>Observer n’est pas investir.</h3></div><p>La watchlist te permet de suivre un actif sans prendre de position. Utilise-la pour comparer l’évolution réelle du marché à ton intuition avant d’engager des Koins.</p></section>
    <section className="premium-market"><div><span>KONSENS PREMIUM · 4,99 €/MOIS</span><h2>{premium?"Flux enrichis actifs":"Passe du cours à l’analyse."}</h2><p>Premium masque les publicités Konsens et ouvre les analyses enrichies, la blockchain publique suivie, les historiques étendus et les futurs fournisseurs premium. Les décisions restent entièrement simulées en Koins.</p></div><b>{premium?"PREMIUM ACTIF":"DISPONIBLE DANS PROFIL"}</b></section>
  </section>;
}

function PriceChart({points}:{points:Point[]}) {
  const clean=useMemo(()=>points.filter(p=>Number.isFinite(p.price)).slice(-260),[points]);
  if(clean.length<2)return <div className="price-chart empty">Historique en cours de chargement…</div>;
  const min=Math.min(...clean.map(p=>p.price)),max=Math.max(...clean.map(p=>p.price)),span=Math.max(max-min,0.0001);
  const path=clean.map((p,i)=>`${i?"L":"M"}${(i/(clean.length-1))*800},${230-((p.price-min)/span)*190}`).join(" ");
  const positive=clean.at(-1)!.price>=clean[0].price;
  return <div className={positive?"price-chart positive-chart":"price-chart negative-chart"}><svg viewBox="0 0 800 260" preserveAspectRatio="none"><defs><linearGradient id="fillPrice" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopOpacity=".22"/><stop offset="1" stopOpacity="0"/></linearGradient></defs><path className="area" d={`${path} L800,250 L0,250 Z`}/><path className="line" d={path}/></svg><div className="chart-labels"><span>{clean[0].price.toFixed(2)}</span><b>min {min.toFixed(2)} · max {max.toFixed(2)}</b><span>{clean.at(-1)!.price.toFixed(2)}</span></div></div>;
}
