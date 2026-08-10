import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const encoder = new TextEncoder();

async function validAlchemySignature(body: string, signature: string, secret: string) {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expected = Array.from(new Uint8Array(signed)).map((b) => b.toString(16).padStart(2, "0")).join("");
  if (expected.length !== signature.length) return false;
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) mismatch |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  return mismatch === 0;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const secret = Deno.env.get("ALCHEMY_WEBHOOK_SIGNING_KEY");
  const signature = request.headers.get("x-alchemy-signature") ?? "";
  if (!secret) return new Response("Webhook not configured", { status: 503 });
  const body = await request.text();
  if (!(await validAlchemySignature(body, signature, secret))) return new Response("Invalid signature", { status: 401 });

  const payload = JSON.parse(body);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const activities = payload?.event?.activity ?? [];
  for (const activity of activities) {
    const addresses = [activity.fromAddress, activity.toAddress].filter(Boolean).map((v: string) => v.toLowerCase());
    const { data: wallets } = await supabase.from("public_wallets").select("id,address,chain").in("address", addresses);
    for (const wallet of wallets ?? []) {
      const outgoing = wallet.address.toLowerCase() === activity.fromAddress?.toLowerCase();
      await supabase.from("wallet_events").upsert({
        provider_event_id: `${payload.id}:${activity.hash}:${wallet.id}`,
        wallet_id: wallet.id,
        chain: payload.event.network,
        transaction_hash: activity.hash,
        event_type: "transfer",
        direction: outgoing ? "out" : "in",
        asset_symbol: activity.asset,
        asset_amount: activity.value,
        explorer_url: `https://etherscan.io/tx/${activity.hash}`,
        raw_event: activity,
      }, { onConflict: "provider_event_id" });
    }
  }
  return Response.json({ accepted: true, events: activities.length });
});
