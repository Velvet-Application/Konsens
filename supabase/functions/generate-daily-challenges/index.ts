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
      input: `Tu es le game master de Konsens, un jeu social français de prédictions entre amis. Cherche des faits et événements français ou très populaires en France, récents, légers, partageables et vérifiables, puis propose exactement 5 challenges OUI/NON qui donnent immédiatement envie de jouer et de comparer sa réponse avec sa ligue.

Priorité éditoriale : pop culture, séries/cinéma, musique, sport, jeux vidéo, internet et réseaux sociaux, technologie grand public, tendances de consommation, loisirs, météo non dangereuse, records, sorties, événements culturels et petites curiosités du quotidien. Une question doit pouvoir provoquer une discussion du type « toi tu mises quoi ? ». Le ton de la question est simple, court et joueur, jamais administratif ni financier.

Composition du lot : au moins 3 challenges doivent relever du sport, de la culture ou du quotidien. La finance ne doit jamais représenter plus d'un challenge sur 5 et peut être absente. Évite de faire cinq questions sur le même thème.

Chaque challenge doit : être objectivement résoluble sous 1 à 14 jours ; utiliser une source publique fiable et directement liée au critère de résolution ; être formulé sans ambiguïté ; avoir un résultat binaire clair ; ne pas dépendre d'une rumeur, d'une opinion ou d'une donnée privée. Ne jamais inventer une source.

Exclus totalement : politique électorale, décès, accidents graves, catastrophes, guerre, terrorisme, santé individuelle, sexualité explicite, mineurs, faits divers violents, humiliation de personnes réelles, rumeurs people, sujets anxiogènes ou incitant à un comportement dangereux. Ne crée pas de défi demandant aux joueurs d'effectuer une action risquée : ils ne font que prédire un résultat extérieur.

Le but n'est pas de donner un cours de finance : le but est de fabriquer le meilleur feed quotidien d'un jeu social de prédiction.`,
      text: {
        format: {
          type: "json_schema",
          name: "daily_challenges",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            required: ["challenges"],
            properties: {
              challenges: {
                type: "array",
                minItems: 5,
                maxItems: 5,
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: ["question","category","resolution_rule","resolution_source_url","source_title","source_published_at","closes_at"],
                  properties: {
                    question: { type: "string" },
                    category: { type: "string", enum: ["quotidien","sport","actualite","finance","culture"] },
                    resolution_rule: { type: "string" },
                    resolution_source_url: { type: "string" },
                    source_title: { type: "string" },
                    source_published_at: { type: "string" },
                    closes_at: { type: "string" }
                  }
                }
              }
            }
          }
        }
      },
      max_output_tokens: 4000
    })
  });

  if (!response.ok) return new Response(await response.text(), { status: 502 });
  const result = await response.json();
  const text = result.output
    ?.flatMap((item: {content?: Array<{type:string;text?:string}>}) => item.content ?? [])
    .find((part: {type:string}) => part.type === "output_text")?.text;
  if (!text) return new Response("No structured output", { status: 502 });

  const parsed = JSON.parse(text);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const rows = parsed.challenges.map((challenge: Record<string, unknown>) => ({
    ...challenge,
    generation_model: "gpt-5.6-luna",
    generation_batch_id: batchId,
    status: "pending_review"
  }));
  const { error } = await supabase.from("challenge_drafts").insert(rows);
  if (error) return Response.json({ error: error.message }, { status: 500 });

  return Response.json({ generated: rows.length, batch_id: batchId, status: "pending_review" });
});
