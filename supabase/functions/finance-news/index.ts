import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,OPTIONS",
  "access-control-allow-headers": "authorization,apikey,content-type",
};

const out = (body: unknown, status = 200, cache = "public, max-age=300") =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json; charset=utf-8", "cache-control": cache },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return out({ error: "method_not_allowed" }, 405, "no-store");

  const url = new URL(req.url);
  const raw = (url.searchParams.get("q") ?? "").trim().slice(0, 100);
  if (raw.length < 2) return out({ error: "query_required" }, 400, "no-store");

  try {
    const gdelt = new URL("https://api.gdeltproject.org/api/v2/doc/doc");
    gdelt.searchParams.set("query", `\"${raw.replace(/[\"<>]/g, "")}\"`);
    gdelt.searchParams.set("mode", "ArtList");
    gdelt.searchParams.set("maxrecords", "12");
    gdelt.searchParams.set("format", "json");
    gdelt.searchParams.set("sort", "HybridRel");

    const response = await fetch(gdelt, { headers: { "user-agent": "KonsensBeta/2.0" } });
    if (!response.ok) throw new Error(`gdelt_${response.status}`);
    const payload = await response.json();
    const articles = (payload.articles ?? [])
      .map((article: any) => ({
        title: String(article.title ?? ""),
        url: String(article.url ?? ""),
        domain: String(article.domain ?? ""),
        language: String(article.language ?? ""),
        seenDate: String(article.seendate ?? article.seenDate ?? ""),
        sourceCountry: String(article.sourcecountry ?? ""),
      }))
      .filter((article: any) => article.title && article.url)
      .slice(0, 10);

    return out({
      query: raw,
      provider: "GDELT DOC 2.0",
      articles,
      generatedAt: new Date().toISOString(),
      disclaimer: "Actualités externes à titre informatif. Vérifie toujours la source avant toute conclusion.",
    });
  } catch (error) {
    return out(
      { error: "news_unavailable", detail: error instanceof Error ? error.message : String(error) },
      502,
      "no-store",
    );
  }
});
