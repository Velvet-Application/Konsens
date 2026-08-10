"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co",
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",
);

type Ad = {
  campaign_id: string;
  creative_id: string;
  sponsor_name: string;
  eyebrow: string;
  headline: string;
  body: string | null;
  cta_label: string;
  destination_url: string;
  image_url: string | null;
  placement: "feed_native" | "challenge_sponsor" | "post_prediction";
};

function sessionId() {
  const key = "konsens_monetization_session";
  const existing = window.sessionStorage.getItem(key);
  if (existing) return existing;
  const value = crypto.randomUUID();
  window.sessionStorage.setItem(key, value);
  return value;
}

export default function MonetizationLayer({ children }: { children: ReactNode }) {
  const [target, setTarget] = useState<Element | null>(null);
  const [ad, setAd] = useState<Ad | null>(null);
  const [freeTier, setFreeTier] = useState(false);
  const impression = useRef<string | null>(null);
  const session = useRef<string | null>(null);

  useEffect(() => {
    session.current = sessionId();
    const syncTarget = () => setTarget(document.querySelector(".beta-content"));
    syncTarget();
    const observer = new MutationObserver(syncTarget);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!target || !session.current) {
      setAd(null);
      setFreeTier(false);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data: auth } = await supabase.auth.getUser();
      if (!auth.user) return;
      const { data: profile } = await supabase
        .from("profiles")
        .select("subscription_tier")
        .eq("id", auth.user.id)
        .maybeSingle();
      if (cancelled) return;
      const isFree = (profile?.subscription_tier ?? "free") === "free";
      setFreeTier(isFree);
      if (!isFree) return;
      const { data } = await supabase.rpc("get_active_ad", {
        p_placement: "feed_native",
        p_category: null,
        p_session_id: session.current,
      });
      if (!cancelled) setAd((Array.isArray(data) ? data[0] : data) as Ad | null);
    })();
    return () => { cancelled = true; };
  }, [target]);

  useEffect(() => {
    if (!ad || !session.current || impression.current === ad.creative_id) return;
    impression.current = ad.creative_id;
    void supabase.rpc("track_ad_event", {
      p_campaign_id: ad.campaign_id,
      p_creative_id: ad.creative_id,
      p_event_type: "impression",
      p_placement: ad.placement,
      p_session_id: session.current,
      p_slot_key: "app_contextual_native",
      p_resource_id: null,
      p_metadata: { client: "web", targeting: "contextual" },
    });
  }, [ad]);

  const openSponsor = async () => {
    if (!ad || !session.current) return;
    await supabase.rpc("track_ad_event", {
      p_campaign_id: ad.campaign_id,
      p_creative_id: ad.creative_id,
      p_event_type: "click",
      p_placement: ad.placement,
      p_session_id: session.current,
      p_slot_key: "app_contextual_native",
      p_resource_id: null,
      p_metadata: { client: "web", targeting: "contextual" },
    });
    window.open(ad.destination_url, "_blank", "noopener,noreferrer");
  };

  return <>
    {children}
    {target && freeTier && ad ? createPortal(
      <aside className="k-sponsor-card" aria-label={`Contenu sponsorisé par ${ad.sponsor_name}`}>
        {ad.image_url ? <div className="k-sponsor-image" style={{ backgroundImage: `url(${JSON.stringify(ad.image_url)})` }} aria-hidden="true" /> : <div className="k-sponsor-mark">K</div>}
        <div className="k-sponsor-copy">
          <span>{ad.eyebrow} · {ad.sponsor_name}</span>
          <strong>{ad.headline}</strong>
          {ad.body ? <p>{ad.body}</p> : null}
        </div>
        <button onClick={openSponsor}>{ad.cta_label} <b>→</b></button>
      </aside>,
      target,
    ) : null}
  </>;
}
