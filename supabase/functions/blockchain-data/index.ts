import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const CORS = { "access-control-allow-origin": "*", "access-control-allow-methods": "GET,OPTIONS", "access-control-allow-headers": "authorization,apikey,content-type" };
const out = (body: unknown, status = 200, cache = "private, max-age=30") => new Response(JSON.stringify(body), { status, headers: { ...CORS, "content-type": "application/json; charset=utf-8", "cache-control": cache } });
const validAddress = (value: string) => /^0x[a-fA-F0-9]{40}$/.test(value);
const addressValue = (value: any) => String(value?.hash ?? value ?? "").toLowerCase();
const numberValue = (value: any) => { const n = Number(value); return Number.isFinite(n) ? n : 0; };

async function usdToEur() {
  try { const response = await fetch("https://api.frankfurter.app/latest?from=USD&to=EUR"); const payload = await response.json(); return numberValue(payload?.rates?.EUR) || 0.86; }
  catch { return 0.86; }
}

async function blockscout(address: string) {
  const base = "https://eth.blockscout.com";
  const [transactionsResponse, tokenResponse, statsResponse, fx] = await Promise.all([
    fetch(`${base}/api/v2/addresses/${address}/transactions`),
    fetch(`${base}/api/v2/addresses/${address}/token-transfers`),
    fetch(`${base}/api/v2/stats`),
    usdToEur(),
  ]);
  if (!transactionsResponse.ok) throw new Error(`blockscout_${transactionsResponse.status}`);
  const transactionsPayload = await transactionsResponse.json();
  const tokenPayload = tokenResponse.ok ? await tokenResponse.json() : { items: [] };
  const statsPayload = statsResponse.ok ? await statsResponse.json() : {};
  const ethUsd = numberValue(statsPayload?.coin_price);
  const normalized = address.toLowerCase();

  const native = (transactionsPayload.items ?? []).slice(0, 35).map((tx: any) => {
    const amount = numberValue(tx.value) / 1e18;
    return { providerEventId: `blockscout:${tx.hash}:native`, hash: String(tx.hash ?? ""), from: addressValue(tx.from), to: addressValue(tx.to), eventType: "transfer", direction: addressValue(tx.to) === normalized ? "in" : "out", assetSymbol: "ETH", assetAmount: amount, estimatedValueEUR: ethUsd ? amount * ethUsd * fx : null, blockTime: String(tx.timestamp ?? new Date().toISOString()), blockNumber: String(tx.block ?? ""), explorerUrl: `https://eth.blockscout.com/tx/${tx.hash}`, raw: tx };
  });

  const tokens = (tokenPayload.items ?? []).slice(0, 35).map((tx: any, index: number) => {
    const decimals = numberValue(tx.total?.decimals ?? tx.token?.decimals ?? 18);
    const raw = numberValue(tx.total?.value ?? tx.value ?? 0);
    const amount = raw / Math.pow(10, decimals);
    const usd = numberValue(tx.token?.exchange_rate);
    const symbol = String(tx.token?.symbol ?? "TOKEN");
    const hash = String(tx.transaction_hash ?? tx.tx_hash ?? "");
    return { providerEventId: `blockscout:${hash}:${tx.log_index ?? index}`, hash, from: addressValue(tx.from), to: addressValue(tx.to), eventType: "transfer", direction: addressValue(tx.to) === normalized ? "in" : "out", assetSymbol: symbol, assetAmount: amount, estimatedValueEUR: usd ? amount * usd * fx : null, blockTime: String(tx.timestamp ?? new Date().toISOString()), blockNumber: String(tx.block_number ?? ""), explorerUrl: `https://eth.blockscout.com/tx/${hash}`, raw: tx };
  });
  return { provider: "Blockscout Ethereum", transactions: [...native, ...tokens].sort((a, b) => new Date(b.blockTime).getTime() - new Date(a.blockTime).getTime()).slice(0, 40) };
}

async function etherscan(address: string, key: string) {
  const api = new URL("https://api.etherscan.io/v2/api");
  for (const [name, value] of Object.entries({ chainid: "1", module: "account", action: "txlist", address, startblock: "0", endblock: "99999999", page: "1", offset: "40", sort: "desc", apikey: key })) api.searchParams.set(name, value);
  const response = await fetch(api, { headers: { "user-agent": "KonsensBeta/2.0" } });
  if (!response.ok) throw new Error(`etherscan_${response.status}`);
  const payload = await response.json();
  if (String(payload.status) !== "1" && !Array.isArray(payload.result)) throw new Error(String(payload.message ?? "etherscan_error"));
  const fx = await usdToEur();
  let ethUsd = 0;
  try { const priceResponse = await fetch(`https://api.etherscan.io/v2/api?chainid=1&module=stats&action=ethprice&apikey=${encodeURIComponent(key)}`); const pricePayload = await priceResponse.json(); ethUsd = numberValue(pricePayload?.result?.ethusd); } catch {}
  const normalized = address.toLowerCase();
  const transactions = (Array.isArray(payload.result) ? payload.result : []).slice(0, 40).map((tx: any) => {
    const amount = numberValue(tx.value) / 1e18;
    return { providerEventId: `etherscan:${tx.hash}:native`, hash: String(tx.hash ?? ""), from: String(tx.from ?? "").toLowerCase(), to: String(tx.to ?? "").toLowerCase(), eventType: "transfer", direction: String(tx.to ?? "").toLowerCase() === normalized ? "in" : "out", assetSymbol: "ETH", assetAmount: amount, estimatedValueEUR: ethUsd ? amount * ethUsd * fx : null, blockTime: new Date(numberValue(tx.timeStamp) * 1000).toISOString(), blockNumber: String(tx.blockNumber ?? ""), explorerUrl: `https://etherscan.io/tx/${tx.hash}`, raw: tx };
  });
  return { provider: "Etherscan V2", transactions };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return out({ error: "method_not_allowed" }, 405);
  const requestUrl = new URL(req.url);
  const address = requestUrl.searchParams.get("address") ?? "";
  const walletId = requestUrl.searchParams.get("wallet_id");
  if (!validAddress(address)) return out({ error: "invalid_ethereum_address" }, 400);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
    const authorization = req.headers.get("authorization") ?? "";
    const client = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authorization } } });
    const { data: { user } } = await client.auth.getUser();
    if (!user) return out({ error: "unauthorized" }, 401);

    let canPersist = false;
    let wallet: any = null;
    if (walletId) {
      const walletQuery = await client.from("public_wallets").select("id,address,chain,display_name").eq("id", walletId).eq("address", address).maybeSingle();
      wallet = walletQuery.data;
      if (!wallet) return out({ error: "wallet_not_found" }, 404);
      const profile = await client.from("profiles").select("subscription_tier,role").eq("id", user.id).single();
      const premium = profile.data?.subscription_tier === "premium" || profile.data?.role === "admin";
      const follow = await client.from("wallet_follows").select("wallet_id").eq("user_id", user.id).eq("wallet_id", walletId).maybeSingle();
      canPersist = Boolean(premium && follow.data);
    }

    const etherscanKey = Deno.env.get("ETHERSCAN_API_KEY") ?? "";
    let feed: any;
    try { feed = etherscanKey ? await etherscan(address, etherscanKey) : await blockscout(address); }
    catch (primary) { if (etherscanKey) feed = await blockscout(address); else throw primary; }

    if (canPersist && serviceKey && walletId) {
      const admin = createClient(supabaseUrl, serviceKey);
      for (const tx of feed.transactions) {
        await admin.from("wallet_events").upsert({ provider_event_id: tx.providerEventId, wallet_id: walletId, chain: "ethereum", transaction_hash: tx.hash, event_type: tx.eventType, direction: tx.direction, asset_symbol: tx.assetSymbol, asset_amount: tx.assetAmount, estimated_value_eur: tx.estimatedValueEUR, block_time: tx.blockTime, explorer_url: tx.explorerUrl, raw_event: { provider: feed.provider, ...tx.raw } }, { onConflict: "provider_event_id" });
      }
    }

    return out({ provider: feed.provider, address, wallet: wallet ? { id: wallet.id, displayName: wallet.display_name } : null, transactions: feed.transactions.map(({ raw, ...tx }: any) => tx), persistedForAlerts: canPersist, transparent: true, disclaimer: "Données publiques de chaîne. Une adresse ne constitue pas une identité civile sauf attribution explicitement publique et sourcée." });
  } catch (error) {
    return out({ error: "blockchain_provider_unavailable", detail: error instanceof Error ? error.message : String(error) }, 502);
  }
});
