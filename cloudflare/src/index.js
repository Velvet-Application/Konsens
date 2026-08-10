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
  return env.ALLOWED_ORIGINS.split(",").map((value) => value.trim()).includes(origin) ? origin : null;
}

function corsFor(request, env, sdk = false) {
  const origin = request.headers.get("origin");
  if (!origin) return {};
  const allowed = sdk ? origin : configuredOrigin(request, env);
  return allowed ? { "access-control-allow-origin": allowed, vary: "Origin" } : {};
}

async function supabaseRpc(request, env, fn, payload) {
  const headers = {
    apikey: env.SUPABASE_PUBLISHABLE_KEY,
    "content-type": "application/json",
  };
  const authorization = request.headers.get("authorization");
  if (authorization) headers.authorization = authorization;
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { message: text }; }
  return { ok: response.ok, status: response.status, data };
}

function safeJson(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return {};
  return body;
}

const worker = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const sdkRoute = url.pathname.startsWith("/v1/sdk/") || url.pathname.startsWith("/v1/signals/");
    const cors = corsFor(request, env, sdkRoute);

    if (request.method === "OPTIONS") {
      const origin = request.headers.get("origin");
      if (!origin) return new Response(null, { status: 204 });
      if (!sdkRoute && !configuredOrigin(request, env)) return json({ error: "origin_not_allowed" }, 403);
      return new Response(null, {
        status: 204,
        headers: {
          ...cors,
          "access-control-allow-methods": "GET, POST, OPTIONS",
          "access-control-allow-headers": "authorization, content-type, idempotency-key, x-konsens-key",
          "access-control-max-age": "86400",
        },
      });
    }

    if (url.pathname === "/health" && request.method === "GET") {
      return json({ service: "konsens-api", status: "ok", environment: env.ENVIRONMENT, monetization: env.MONETIZATION_MODE }, 200, cors);
    }

    if (url.pathname === "/v1/config" && request.method === "GET") {
      return json({
        supabaseUrl: env.SUPABASE_URL,
        minimumClientVersion: "1.0.0",
        demoMode: env.DEMO_MODE === "true",
        monetization: {
          mode: env.MONETIZATION_MODE || "contextual",
          placements: ["feed_native", "challenge_sponsor", "post_prediction"],
          personalizedAdsDefault: false,
          sdkVersion: "1.0.0",
        },
      }, 200, { ...cors, "cache-control": "public, max-age=300" });
    }

    if (url.pathname === "/v1/ads/serve" && request.method === "GET") {
      const placement = url.searchParams.get("placement") || "feed_native";
      const category = url.searchParams.get("category");
      const session = url.searchParams.get("session");
      const result = await supabaseRpc(request, env, "get_active_ad", {
        p_placement: placement,
        p_category: category,
        p_session_id: session,
      });
      if (!result.ok) return json({ error: "ad_service_unavailable", detail: result.data }, result.status, cors);
      const ad = Array.isArray(result.data) ? result.data[0] ?? null : result.data;
      return json({ ad }, 200, { ...cors, "cache-control": "private, max-age=30" });
    }

    if (url.pathname === "/v1/ads/event" && request.method === "POST") {
      const body = safeJson(await request.json().catch(() => ({})));
      const result = await supabaseRpc(request, env, "track_ad_event", {
        p_campaign_id: body.campaignId,
        p_creative_id: body.creativeId,
        p_event_type: body.eventType,
        p_placement: body.placement,
        p_session_id: body.sessionId,
        p_slot_key: body.slotKey ?? null,
        p_resource_id: body.resourceId ?? null,
        p_metadata: safeJson(body.metadata),
      });
      if (!result.ok) return json({ error: "event_rejected", detail: result.data }, 400, cors);
      return json({ accepted: true, eventId: result.data }, 202, cors);
    }

    const signalMatch = url.pathname.match(/^\/v1\/signals\/challenges\/([0-9a-f-]{36})$/i);
    if (signalMatch && request.method === "GET") {
      const apiKey = request.headers.get("x-konsens-key");
      const origin = request.headers.get("origin") || "server";
      if (!apiKey) return json({ error: "missing_api_key" }, 401, cors);
      const meter = await supabaseRpc(request, env, "register_sdk_event", {
        p_api_key: apiKey,
        p_event_type: "signal_read",
        p_origin: origin,
        p_metadata: { challengeId: signalMatch[1] },
      });
      if (!meter.ok) return json({ error: "sdk_access_denied", detail: meter.data }, 403, cors);
      const signal = await supabaseRpc(request, env, "get_challenge_signal", { p_challenge_id: signalMatch[1] });
      if (!signal.ok) return json({ error: "signal_unavailable", detail: signal.data }, signal.status, cors);
      const data = Array.isArray(signal.data) ? signal.data[0] ?? null : signal.data;
      if (!data) return json({ error: "challenge_not_found" }, 404, cors);
      return json({ signal: data, usage: Array.isArray(meter.data) ? meter.data[0] ?? null : meter.data }, 200, { ...cors, "cache-control": "private, max-age=20" });
    }

    if (url.pathname === "/v1/sdk/events" && request.method === "POST") {
      const apiKey = request.headers.get("x-konsens-key");
      const origin = request.headers.get("origin") || "server";
      if (!apiKey) return json({ error: "missing_api_key" }, 401, cors);
      const body = safeJson(await request.json().catch(() => ({})));
      const result = await supabaseRpc(request, env, "register_sdk_event", {
        p_api_key: apiKey,
        p_event_type: body.eventType,
        p_origin: origin,
        p_metadata: safeJson(body.metadata),
      });
      if (!result.ok) return json({ error: "sdk_event_rejected", detail: result.data }, 403, cors);
      return json({ accepted: true, usage: Array.isArray(result.data) ? result.data[0] ?? null : result.data }, 202, cors);
    }

    return json({ error: "not_found" }, 404, cors);
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(Promise.resolve(console.log(JSON.stringify({ event: "price_refresh_requested", environment: env.ENVIRONMENT, at: new Date().toISOString() }))));
  },
};

export default worker;
