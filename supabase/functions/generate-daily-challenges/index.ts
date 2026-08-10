import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (request.headers.get("x-cron-secret") !== Deno.env.get("CHALLENGE_CRON_SECRET")) return new Response("Unauthorized", { status: 401 });
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return new Response("AI not configured", { status: 503 });
  const batchId = crypto.randomUUID();
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "gpt-5.6-luna",
      store: false,
      tools: [{ type: "web_search" }],
      input: "Trouve des actualités françaises récentes, factuelles et non sensibles, puis propose exactement 5 challenges OUI/NON ludiques. Chaque résultat doit pouvoir être résolu objectivement sous 1 à 14 jours par une source publique fiable. Exclure politique électorale, décès, catastrophes, santé individuelle et rumeurs. Ne jamais inventer une source.",
      text: { format: { type: "json_schema", name: "daily_challenges", strict: true, schema: { type: "object", additionalProperties: false, required: ["challenges"], properties: { challenges: { type: "array", minItems: 5, maxItems: 5, items: { type: "object", additionalProperties: false, required: ["question","category","resolution_rule","resolution_source_url","source_title","source_published_at","closes_at"], properties: { question: {type:"string"}, category:{type:"string",enum:["quotidien","sport","actualite","finance","culture"]}, resolution_rule:{type:"string"}, resolution_source_url:{type:"string"}, source_title:{type:"string"}, source_published_at:{type:"string"}, closes_at:{type:"string"} } } } } } } },
      max_output_tokens: 4000
    })
  });
  if (!response.ok) return new Response(await response.text(), { status: 502 });
  const result = await response.json();
  const text = result.output?.flatMap((item: {content?: Array<{type:string;text?:string}>}) => item.content ?? []).find((part: {type:string}) => part.type === "output_text")?.text;
  if (!text) return new Response("No structured output", { status: 502 });
  const parsed = JSON.parse(text);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const rows = parsed.challenges.map((challenge: Record<string, unknown>) => ({ ...challenge, generation_model: "gpt-5.6-luna", generation_batch_id: batchId, status: "pending_review" }));
  const { error } = await supabase.from("challenge_drafts").insert(rows);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ generated: rows.length, batch_id: batchId, status: "pending_review" });
});
