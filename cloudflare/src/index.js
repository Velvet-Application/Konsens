const securityHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
};

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...securityHeaders, ...extra } });
}

function configuredOrigin(request, env) {
  const origin = request.headers.get("origin");
  if (!origin) return null;
  return (env.ALLOWED_ORIGINS || "").split(",").map((value) => value.trim()).includes(origin) ? origin : null;
}

function corsFor(request, env, openOrigin = false) {
  const origin = request.headers.get("origin");
  if (!origin) return {};
  const allowed = openOrigin ? origin : configuredOrigin(request, env);
  return allowed ? { "access-control-allow-origin": allowed, vary: "Origin" } : {};
}

async function supabaseRpc(request, env, fn, payload) {
  const headers = { apikey: env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" };
  const authorization = request.headers.get("authorization");
  if (authorization) headers.authorization = authorization;
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, { method: "POST", headers, body: JSON.stringify(payload) });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { message: text }; }
  return { ok: response.ok, status: response.status, data };
}

function safeJson(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return {};
  return body;
}

function cleanTopic(value) {
  const topic = String(value || "finance marchés économie technologie").replace(/[\r\n<>]/g, " ").trim().slice(0, 120);
  return topic || "finance marchés économie technologie";
}

async function currentUser(request, env) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) return null;
  const userResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, { headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, authorization } });
  if (!userResponse.ok) return null;
  const user = await userResponse.json();
  const profileResponse = await fetch(`${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role`, {
    headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, authorization },
  });
  if (!profileResponse.ok) return null;
  const profiles = await profileResponse.json();
  return { id: user.id, role: profiles?.[0]?.role || "user" };
}

async function gdeltArticles(topic, maxRecords = 18) {
  const params = new URLSearchParams({ query: topic, mode: "ArtList", maxrecords: String(Math.min(maxRecords, 30)), format: "json", sort: "HybridRel", timespan: "24h" });
  const response = await fetch(`https://api.gdeltproject.org/api/v2/doc/doc?${params.toString()}`, { headers: { "user-agent": "Konsens/1.0" } });
  if (!response.ok) throw new Error(`gdelt_${response.status}`);
  const data = await response.json();
  const articles = Array.isArray(data?.articles) ? data.articles : [];
  return articles.slice(0, maxRecords).map((article) => ({
    title: String(article.title || "").slice(0, 260),
    url: String(article.url || ""),
    domain: String(article.domain || ""),
    seenDate: String(article.seendate || ""),
    sourceCountry: String(article.sourcecountry || ""),
    language: String(article.language || ""),
  })).filter((article) => article.title && /^https?:\/\//.test(article.url));
}

function parseAiJson(result) {
  const raw = typeof result === "string" ? result : String(result?.response || result?.output_text || result?.result || "");
  const stripped = raw.replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  try { return JSON.parse(stripped); } catch {}
  const start = stripped.indexOf("{"); const end = stripped.lastIndexOf("}");
  if (start >= 0 && end > start) return JSON.parse(stripped.slice(start, end + 1));
  throw new Error("ai_json_invalid");
}

function normalizeCandidate(item, articles) {
  const articleUrls = new Set(articles.map((a) => a.url));
  const urls = Array.isArray(item?.sourceUrls) ? item.sourceUrls.filter((url) => articleUrls.has(url)).slice(0, 5) : [];
  const titles = urls.map((url) => articles.find((a) => a.url === url)?.title || "Source");
  const probability = Math.max(0.05, Math.min(0.95, Number(item?.yesProbability || 0.5)));
  const confidence = Math.max(0.05, Math.min(0.99, Number(item?.confidence || 0.5)));
  const close = new Date(item?.closesAt || Date.now() + 7 * 86400000);
  const minClose = Date.now() + 3 * 3600000;
  const maxClose = Date.now() + 45 * 86400000;
  const safeClose = new Date(Math.min(Math.max(close.getTime() || 0, minClose), maxClose));
  return {
    question: String(item?.question || "").trim().slice(0, 240),
    category: String(item?.category || "actualité").trim().slice(0, 40),
    resolutionRules: String(item?.resolutionRules || "").trim().slice(0, 1200),
    closesAt: safeClose.toISOString(),
    yesProbability: probability,
    confidence,
    rationale: String(item?.rationale || "").trim().slice(0, 1400),
    sourceSummary: String(item?.sourceSummary || "").trim().slice(0, 1200),
    sourceUrls: urls,
    sourceTitles: titles,
    suggestedStakeMin: Math.max(5, Math.min(250, Math.round(Number(item?.suggestedStakeMin || 25)))),
    suggestedStakeMax: Math.max(25, Math.min(500, Math.round(Number(item?.suggestedStakeMax || 150)))),
    tags: Array.isArray(item?.tags) ? item.tags.map((v) => String(v).slice(0, 30)).slice(0, 6) : [],
  };
}

const worker = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const openCorsRoute = url.pathname.startsWith("/v1/sdk/") || url.pathname.startsWith("/v1/signals/") || url.pathname.startsWith("/v1/ai/") || url.pathname.startsWith("/v1/news/");
    const cors = corsFor(request, env, openCorsRoute);

    if (request.method === "OPTIONS") {
      const origin = request.headers.get("origin");
      if (!origin) return new Response(null, { status: 204 });
      if (!openCorsRoute && !configuredOrigin(request, env)) return json({ error: "origin_not_allowed" }, 403);
      return new Response(null, { status: 204, headers: { ...cors, "access-control-allow-methods": "GET, POST, OPTIONS", "access-control-allow-headers": "authorization, content-type, idempotency-key, x-konsens-key", "access-control-max-age": "86400" } });
    }

    if (url.pathname === "/health" && request.method === "GET") {
      return json({ service: "konsens-api", status: "ok", environment: env.ENVIRONMENT, monetization: env.MONETIZATION_MODE, ai: Boolean(env.AI) }, 200, cors);
    }

    if (url.pathname === "/v1/config" && request.method === "GET") {
      return json({ supabaseUrl: env.SUPABASE_URL, minimumClientVersion: "1.0.0", demoMode: env.DEMO_MODE === "true", aiModel: "@cf/openai/gpt-oss-20b", monetization: { mode: env.MONETIZATION_MODE || "contextual", placements: ["feed_native", "challenge_sponsor", "post_prediction"], personalizedAdsDefault: false, sdkVersion: "1.0.0" } }, 200, { ...cors, "cache-control": "public, max-age=300" });
    }

    if (url.pathname === "/v1/news/latest" && request.method === "GET") {
      try {
        const topic = cleanTopic(url.searchParams.get("topic"));
        const articles = await gdeltArticles(topic, 20);
        const domains = [...new Set(articles.map((a) => a.domain).filter(Boolean))];
        return json({ topic, window: "24h", articleCount: articles.length, sourceCount: domains.length, domains, articles }, 200, { ...cors, "cache-control": "public, max-age=180" });
      } catch (error) {
        return json({ error: "news_unavailable", detail: error instanceof Error ? error.message : String(error) }, 502, cors);
      }
    }

    if (url.pathname === "/v1/ai/markets/generate" && request.method === "POST") {
      const actor = await currentUser(request, env);
      if (!actor) return json({ error: "authentication_required" }, 401, cors);
      if (actor.role !== "admin" && actor.role !== "moderator") return json({ error: "admin_required" }, 403, cors);
      if (!env.AI) return json({ error: "workers_ai_not_bound" }, 503, cors);
      const body = safeJson(await request.json().catch(() => ({})));
      const topic = cleanTopic(body.topic);
      try {
        const articles = await gdeltArticles(topic, 18);
        if (articles.length < 3) return json({ error: "not_enough_news", articles }, 422, cors);
        const sourceBlock = articles.map((a, i) => `${i + 1}. ${a.title}\nURL: ${a.url}\nDomaine: ${a.domain}\nVu: ${a.seenDate}`).join("\n\n");
        const prompt = `Tu es le moteur éditorial de marchés de prédiction éducatifs de Konsens. Les utilisateurs engagent uniquement des Koins fictifs sans valeur monétaire. À partir EXCLUSIVEMENT des articles fournis, propose 3 à 5 marchés binaires OUI/NON vérifiables.\n\nRègles obligatoires:\n- question précise, neutre, mesurable et résoluble dans 2 à 45 jours;\n- aucune question subjective, aucun conseil financier personnalisé;\n- resolutionRules décrit exactement la source/règle qui tranche;\n- yesProbability entre 0.05 et 0.95 et justifiée par les faits, jamais présentée comme certitude;\n- confidence mesure la qualité de l'information disponible, pas la probabilité;\n- sourceUrls doit contenir uniquement des URL du corpus;\n- suggestedStakeMin/Max en Koins doivent rester prudents, généralement 25 à 150, jamais plus de 500;\n- évite les événements dont la résolution dépend d'une rumeur non vérifiable.\n\nRéponds UNIQUEMENT en JSON valide, sans markdown, sous la forme {"markets":[{"question":"...","category":"...","resolutionRules":"...","closesAt":"ISO-8601","yesProbability":0.62,"confidence":0.75,"rationale":"...","sourceSummary":"...","sourceUrls":["..."],"suggestedStakeMin":25,"suggestedStakeMax":100,"tags":["..."]}]}.\n\nCORPUS D'ACTUALITÉ:\n${sourceBlock}`;
        const aiResult = await env.AI.run("@cf/openai/gpt-oss-20b", { messages: [{ role: "system", content: "Tu produis uniquement du JSON strict pour un système éducatif de simulation. N'invente aucune source." }, { role: "user", content: prompt }], temperature: 0.2, max_tokens: 3600 });
        const parsed = parseAiJson(aiResult);
        const markets = (Array.isArray(parsed?.markets) ? parsed.markets : []).map((item) => normalizeCandidate(item, articles)).filter((item) => item.question.length >= 12 && item.resolutionRules.length >= 20 && item.sourceUrls.length > 0);
        return json({ topic, generatedAt: new Date().toISOString(), model: "@cf/openai/gpt-oss-20b", statistics: { articles: articles.length, sources: new Set(articles.map((a) => a.domain)).size }, markets, articles }, 200, cors);
      } catch (error) {
        return json({ error: "ai_generation_failed", detail: error instanceof Error ? error.message : String(error) }, 502, cors);
      }
    }

    if (url.pathname === "/v1/ads/serve" && request.method === "GET") {
      const placement = url.searchParams.get("placement") || "feed_native"; const category = url.searchParams.get("category"); const session = url.searchParams.get("session");
      const result = await supabaseRpc(request, env, "get_active_ad", { p_placement: placement, p_category: category, p_session_id: session });
      if (!result.ok) return json({ error: "ad_service_unavailable", detail: result.data }, result.status, cors);
      const ad = Array.isArray(result.data) ? result.data[0] ?? null : result.data;
      return json({ ad }, 200, { ...cors, "cache-control": "private, max-age=30" });
    }

    if (url.pathname === "/v1/ads/event" && request.method === "POST") {
      const body = safeJson(await request.json().catch(() => ({})));
      const result = await supabaseRpc(request, env, "track_ad_event", { p_campaign_id: body.campaignId, p_creative_id: body.creativeId, p_event_type: body.eventType, p_placement: body.placement, p_session_id: body.sessionId, p_slot_key: body.slotKey ?? null, p_resource_id: body.resourceId ?? null, p_metadata: safeJson(body.metadata) });
      if (!result.ok) return json({ error: "event_rejected", detail: result.data }, 400, cors);
      return json({ accepted: true, eventId: result.data }, 202, cors);
    }

    const signalMatch = url.pathname.match(/^\/v1\/signals\/challenges\/([0-9a-f-]{36})$/i);
    if (signalMatch && request.method === "GET") {
      const apiKey = request.headers.get("x-konsens-key"); const origin = request.headers.get("origin") || "server";
      if (!apiKey) return json({ error: "missing_api_key" }, 401, cors);
      const signal = await supabaseRpc(request, env, "get_sdk_challenge_signal", { p_api_key: apiKey, p_origin: origin, p_challenge_id: signalMatch[1] });
      if (!signal.ok) return json({ error: "sdk_access_denied", detail: signal.data }, 403, cors);
      const data = Array.isArray(signal.data) ? signal.data[0] ?? null : signal.data;
      if (!data) return json({ error: "challenge_not_found" }, 404, cors);
      return json({ signal: data, usage: { plan: data.client_plan, remainingEvents: data.remaining_events } }, 200, { ...cors, "cache-control": "private, max-age=20" });
    }

    if (url.pathname === "/v1/sdk/events" && request.method === "POST") {
      const apiKey = request.headers.get("x-konsens-key"); const origin = request.headers.get("origin") || "server";
      if (!apiKey) return json({ error: "missing_api_key" }, 401, cors);
      const body = safeJson(await request.json().catch(() => ({})));
      const result = await supabaseRpc(request, env, "register_sdk_event", { p_api_key: apiKey, p_event_type: body.eventType, p_origin: origin, p_metadata: safeJson(body.metadata) });
      if (!result.ok) return json({ error: "sdk_event_rejected", detail: result.data }, 403, cors);
      return json({ accepted: true, usage: Array.isArray(result.data) ? result.data[0] ?? null : result.data }, 202, cors);
    }

    return json({ error: "not_found" }, 404, cors);
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(Promise.resolve(console.log(JSON.stringify({ event: "refresh_requested", environment: env.ENVIRONMENT, at: new Date().toISOString() }))));
  },
};

export default worker;
