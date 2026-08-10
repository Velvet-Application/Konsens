"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co",
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",
);

type Metrics = { advertisers: number; activeCampaigns: number; impressions: number; clicks: number; sdkClients: number };
type Campaign = { id: string; name: string; status: string; placements: string[]; starts_at: string; ends_at: string | null };
type SdkClient = { id: string; name: string; plan: string; status: string; monthly_event_limit: number; allowed_origins: string[] };

export default function MonetizationAdmin() {
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [metrics, setMetrics] = useState<Metrics>({ advertisers: 0, activeCampaigns: 0, impressions: 0, clicks: 0, sdkClients: 0 });
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [clients, setClients] = useState<SdkClient[]>([]);
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [origin, setOrigin] = useState("");
  const [plan, setPlan] = useState("developer");
  const [newKey, setNewKey] = useState("");
  const [status, setStatus] = useState("");

  const load = async () => {
    const { data: auth } = await supabase.auth.getUser();
    if (!auth.user) { setAllowed(false); return; }
    const { data: profile } = await supabase.from("profiles").select("role").eq("id", auth.user.id).maybeSingle();
    if (!profile || !["admin", "moderator"].includes(profile.role)) { setAllowed(false); return; }
    setAllowed(true);
    const [advertisers, activeCampaigns, impressions, clicks, sdkClients, campaignRows, clientRows] = await Promise.all([
      supabase.from("advertisers").select("id", { count: "exact", head: true }),
      supabase.from("ad_campaigns").select("id", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("ad_events").select("id", { count: "exact", head: true }).eq("event_type", "impression"),
      supabase.from("ad_events").select("id", { count: "exact", head: true }).eq("event_type", "click"),
      supabase.from("sdk_clients").select("id", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("ad_campaigns").select("id,name,status,placements,starts_at,ends_at").order("created_at", { ascending: false }).limit(8),
      supabase.from("sdk_clients").select("id,name,plan,status,monthly_event_limit,allowed_origins").order("created_at", { ascending: false }).limit(8),
    ]);
    setMetrics({
      advertisers: advertisers.count ?? 0,
      activeCampaigns: activeCampaigns.count ?? 0,
      impressions: impressions.count ?? 0,
      clicks: clicks.count ?? 0,
      sdkClients: sdkClients.count ?? 0,
    });
    setCampaigns((campaignRows.data ?? []) as Campaign[]);
    setClients((clientRows.data ?? []) as SdkClient[]);
  };

  // This page hydrates an admin-only dashboard from Supabase once on mount.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void load(); }, []);

  const createClient = async (event: FormEvent) => {
    event.preventDefault();
    setStatus("Création…");
    setNewKey("");
    const limits: Record<string, number> = { developer: 10000, starter: 100000, pro: 1000000, business: 5000000, enterprise: 20000000 };
    const { data, error } = await supabase.rpc("create_sdk_client", {
      p_name: name,
      p_slug: slug,
      p_plan: plan,
      p_monthly_event_limit: limits[plan] ?? 10000,
      p_allowed_origins: [origin],
    });
    if (error) { setStatus(error.message); return; }
    const created = Array.isArray(data) ? data[0] : data;
    setNewKey(created?.api_key ?? "");
    setStatus("Client créé. Copie la clé maintenant : elle ne sera plus affichée ensuite.");
    setName(""); setSlug(""); setOrigin("");
    await load();
  };

  if (allowed === null) return <main className="monetization-shell"><div className="monetization-denied">Chargement du pilotage monétisation…</div></main>;
  if (!allowed) return <main className="monetization-shell"><div className="monetization-denied"><h1>Accès réservé</h1><p>Le pilotage de la monétisation est réservé à l’administration Konsens.</p><Link href="/">Retour à Konsens</Link></div></main>;

  const ctr = metrics.impressions > 0 ? ((metrics.clicks / metrics.impressions) * 100).toFixed(2) : "0.00";

  return <main className="monetization-shell">
    <header><div><span>KONSENS REVENUE · ADMIN</span><h1>Monétisation</h1><p>Spots sponsorisés, inventaire publicitaire et Konsens Connect.</p></div><Link href="/">← Retour à l’application</Link></header>
    <section className="monetization-grid">
      <article className="monetization-stat"><span>ANNONCEURS</span><strong>{metrics.advertisers}</strong><small>comptes</small></article>
      <article className="monetization-stat"><span>CAMPAGNES</span><strong>{metrics.activeCampaigns}</strong><small>actives</small></article>
      <article className="monetization-stat"><span>IMPRESSIONS</span><strong>{metrics.impressions}</strong><small>cumulées</small></article>
      <article className="monetization-stat"><span>CTR</span><strong>{ctr}%</strong><small>{metrics.clicks} clics</small></article>
      <article className="monetization-stat"><span>CLIENTS SDK</span><strong>{metrics.sdkClients}</strong><small>actifs</small></article>
    </section>

    <section className="monetization-section"><span>KONSENS CONNECT</span><h2>Créer un client SDK/API</h2>
      <form className="sdk-form" onSubmit={createClient}>
        <input required value={name} onChange={(e) => setName(e.target.value)} placeholder="Nom du partenaire" />
        <input required pattern="[a-z0-9][a-z0-9-]{1,62}" value={slug} onChange={(e) => setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))} placeholder="slug-partenaire" />
        <input required type="url" value={origin} onChange={(e) => setOrigin(e.target.value.replace(/\/$/, ""))} placeholder="https://media.fr" />
        <select value={plan} onChange={(e) => setPlan(e.target.value)}><option value="developer">Developer</option><option value="starter">Starter</option><option value="pro">Pro</option><option value="business">Business</option><option value="enterprise">Enterprise</option></select>
        <button>Créer la clé</button>
      </form>
      {status ? <p>{status}</p> : null}{newKey ? <div className="sdk-key">{newKey}</div> : null}
    </section>

    <section className="monetization-section"><span>INVENTAIRE</span><h2>Campagnes récentes</h2><div className="monetization-table">
      {campaigns.length === 0 ? <p>Aucune campagne créée. Les emplacements restent invisibles tant qu’aucun sponsor réel n’est actif.</p> : campaigns.map((campaign) => <div className="monetization-row" key={campaign.id}><b>{campaign.name}</b><small>{campaign.placements.join(" · ")}</small><small>{campaign.status}</small><small>{new Date(campaign.starts_at).toLocaleDateString("fr-FR")}</small></div>)}
    </div></section>

    <section className="monetization-section"><span>API B2B</span><h2>Clients Konsens Connect</h2><div className="monetization-table">
      {clients.length === 0 ? <p>Aucun client SDK pour le moment.</p> : clients.map((client) => <div className="monetization-row" key={client.id}><b>{client.name}</b><small>{client.plan} · {client.monthly_event_limit.toLocaleString("fr-FR")} événements/mois</small><small>{client.status}</small><small>{client.allowed_origins.join(", ")}</small></div>)}
    </div></section>
  </main>;
}
