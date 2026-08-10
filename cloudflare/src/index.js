const securityHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
};

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...securityHeaders, ...extra } });
}

function allowedOrigin(request, env) {
  const origin = request.headers.get("origin");
  if (!origin) return null;
  return env.ALLOWED_ORIGINS.split(",").map((value) => value.trim()).includes(origin) ? origin : null;
}

const worker = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = allowedOrigin(request, env);
    const cors = origin ? { "access-control-allow-origin": origin, vary: "Origin" } : {};

    if (request.method === "OPTIONS") {
      if (!origin) return json({ error: "origin_not_allowed" }, 403);
      return new Response(null, { status: 204, headers: { ...cors, "access-control-allow-methods": "GET, POST, OPTIONS", "access-control-allow-headers": "authorization, content-type, idempotency-key", "access-control-max-age": "86400" } });
    }

    if (url.pathname === "/health" && request.method === "GET") {
      return json({ service: "konsens-api", status: "ok", environment: env.ENVIRONMENT }, 200, cors);
    }

    if (url.pathname === "/v1/config" && request.method === "GET") {
      return json({ supabaseUrl: env.SUPABASE_URL, minimumClientVersion: "1.0.0", demoMode: env.DEMO_MODE === "true" }, 200, { ...cors, "cache-control": "public, max-age=300" });
    }

    return json({ error: "not_found" }, 404, cors);
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(Promise.resolve(console.log(JSON.stringify({ event: "price_refresh_requested", environment: env.ENVIRONMENT, at: new Date().toISOString() }))));
  },
};

export default worker;
