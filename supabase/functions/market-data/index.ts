import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

type Point = { t: number; price: number; volume?: number };
const CORS = { "access-control-allow-origin": "*", "access-control-allow-methods": "GET,OPTIONS", "access-control-allow-headers": "authorization,apikey,content-type" };
const reply = (body: unknown, status = 200, cache = "public, max-age=60") => new Response(JSON.stringify(body), { status, headers: { ...CORS, "content-type": "application/json; charset=utf-8", "cache-control": cache } });
const clean = (value: string) => { const symbol = value.trim().toUpperCase(); return /^[A-Z0-9.^=-]{1,20}$/.test(symbol) ? symbol : null; };

async function yahooChart(symbol: string, range: string, interval: string) {
  const target = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=${encodeURIComponent(range)}&interval=${encodeURIComponent(interval)}&includePrePost=false&events=div%2Csplits`;
  const response = await fetch(target, { headers: { "user-agent": "KonsensBeta/2.0" } });
  if (!response.ok) throw new Error(`market_provider_${response.status}`);
  const payload = await response.json();
  const chart = payload?.chart?.result?.[0];
  if (!chart) throw new Error("market_provider_empty");
  const timestamps: number[] = chart.timestamp ?? [];
  const quote = chart.indicators?.quote?.[0] ?? {};
  const closes: Array<number | null> = quote.close ?? [];
  const volumes: Array<number | null> = quote.volume ?? [];
  const points: Point[] = timestamps.map((t, i) => ({ t, price: Number(closes[i]), volume: Number(volumes[i] ?? 0) })).filter((item) => Number.isFinite(item.price) && item.price > 0);
  const meta = chart.meta ?? {};
  const current = Number(meta.regularMarketPrice ?? points.at(-1)?.price ?? 0);
  const previous = Number(meta.chartPreviousClose ?? meta.previousClose ?? points.at(-2)?.price ?? current);
  return { symbol: String(meta.symbol ?? symbol), currency: String(meta.currency ?? ""), exchange: String(meta.fullExchangeName ?? meta.exchangeName ?? ""), price: current, previousClose: previous, change: current - previous, changePct: previous ? ((current - previous) / previous) * 100 : 0, updatedAt: new Date((Number(meta.regularMarketTime) || points.at(-1)?.t || Date.now() / 1000) * 1000).toISOString(), points, provider: "Yahoo Finance chart endpoint (beta fallback)", meta };
}

async function twelve(symbol: string, range: string, interval: string, key: string) {
  const outputsize = range === "1d" ? 78 : range === "5d" ? 120 : range === "1mo" ? 40 : range === "6mo" ? 140 : range === "5y" ? 1300 : 260;
  const tdInterval = interval === "5m" ? "5min" : interval === "15m" ? "15min" : interval === "1h" ? "1h" : "1day";
  const target = `https://api.twelvedata.com/time_series?symbol=${encodeURIComponent(symbol)}&interval=${tdInterval}&outputsize=${outputsize}&order=ASC&apikey=${encodeURIComponent(key)}`;
  const response = await fetch(target);
  if (!response.ok) throw new Error(`twelve_data_${response.status}`);
  const payload = await response.json();
  if (payload.status === "error" || !Array.isArray(payload.values)) throw new Error(payload.message ?? "twelve_data_empty");
  const points: Point[] = payload.values.map((value: any) => ({ t: Math.floor(new Date(`${value.datetime}Z`).getTime() / 1000), price: Number(value.close), volume: Number(value.volume ?? 0) })).filter((value: Point) => Number.isFinite(value.price) && value.price > 0);
  const current = points.at(-1)?.price ?? 0;
  const previous = points.at(-2)?.price ?? current;
  return { symbol: String(payload.meta?.symbol ?? symbol), currency: String(payload.meta?.currency ?? ""), exchange: String(payload.meta?.exchange ?? ""), price: current, previousClose: previous, change: current - previous, changePct: previous ? ((current - previous) / previous) * 100 : 0, updatedAt: new Date((points.at(-1)?.t ?? Date.now() / 1000) * 1000).toISOString(), points, provider: "Twelve Data", meta: {} };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return reply({ error: "method_not_allowed" }, 405, "no-store");
  const requestUrl = new URL(req.url);
  const symbol = clean(requestUrl.searchParams.get("symbol") ?? "");
  const rangeParam = requestUrl.searchParams.get("range") ?? "";
  const intervalParam = requestUrl.searchParams.get("interval") ?? "";
  const range = ["1d", "5d", "1mo", "6mo", "1y", "5y"].includes(rangeParam) ? rangeParam : "1mo";
  const interval = ["5m", "15m", "1h", "1d"].includes(intervalParam) ? intervalParam : "1d";
  if (!symbol) return reply({ error: "invalid_symbol" }, 400, "no-store");

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
    const admin = serviceKey ? createClient(supabaseUrl, serviceKey) : null;
    let asset: any = null;
    if (admin) {
      const result = await admin.from("assets").select("id,symbol,name,sector,description,instrument_group,risk_level,official_url,external_ref,is_active").eq("external_ref", `market:${symbol}`).eq("is_active", true).maybeSingle();
      asset = result.data;
      if (!asset) return reply({ error: "symbol_not_enabled" }, 404, "no-store");
    }

    const twelveKey = Deno.env.get("TWELVE_DATA_API_KEY") ?? "";
    let quote: any;
    try { quote = twelveKey ? await twelve(symbol, range, interval, twelveKey) : await yahooChart(symbol, range, interval); }
    catch (primary) { if (twelveKey) quote = await yahooChart(symbol, range, interval); else throw primary; }

    let year: any = quote;
    if (range !== "1y" && range !== "5y") { try { year = await yahooChart(symbol, "1y", "1d"); } catch { year = quote; } }
    const yearPrices = (year.points ?? []).map((point: Point) => point.price).filter(Number.isFinite);
    const volumes = (year.points ?? []).map((point: Point) => point.volume ?? 0).filter((value: number) => value > 0);
    const meta = quote.meta ?? {};
    const fundamentals = {
      dayHigh: Number(meta.regularMarketDayHigh ?? 0) || null,
      dayLow: Number(meta.regularMarketDayLow ?? 0) || null,
      open: Number(meta.regularMarketOpen ?? 0) || null,
      volume: Number(meta.regularMarketVolume ?? volumes.at(-1) ?? 0) || null,
      averageVolume: volumes.length ? Math.round(volumes.reduce((a: number, b: number) => a + b, 0) / volumes.length) : null,
      fiftyTwoWeekHigh: Number(meta.fiftyTwoWeekHigh ?? (yearPrices.length ? Math.max(...yearPrices) : 0)) || null,
      fiftyTwoWeekLow: Number(meta.fiftyTwoWeekLow ?? (yearPrices.length ? Math.min(...yearPrices) : 0)) || null,
      marketCap: Number(meta.marketCap ?? 0) || null,
      trailingPE: Number(meta.trailingPE ?? 0) || null,
      dividendYield: Number(meta.dividendYield ?? 0) || null,
    };
    delete quote.meta;
    if (admin && asset?.id && quote.price > 0) await admin.from("price_history").upsert({ asset_id: asset.id, observed_at: quote.updatedAt, price: quote.price, source: quote.provider }, { onConflict: "asset_id,observed_at" });
    return reply({ quote, fundamentals, profile: asset ? { sector: asset.sector, description: asset.description, instrumentGroup: asset.instrument_group, riskLevel: asset.risk_level, officialUrl: asset.official_url } : null, disclaimer: "Données de marché informatives et pédagogiques. Aucun ordre réel n’est transmis par Konsens." });
  } catch (error) {
    return reply({ error: "market_data_unavailable", detail: error instanceof Error ? error.message : String(error) }, 502, "no-store");
  }
});
