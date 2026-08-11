import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const developmentPreviewMeta =
  /<meta(?=[^>]*\bname=["']codex-preview["'])(?=[^>]*\bcontent=["']development["'])[^>]*>/i;

test("renders development preview metadata", async () => {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  const response = await worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );

  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("content-type") ?? "",
    /^text\/html\b/i,
  );
  assert.match(await response.text(), developmentPreviewMeta);
});

test("Play keeps real Koin trading and position tracking wired", async () => {
  const source = await readFile(new URL("../app/prediction-v2.tsx", import.meta.url), "utf8");
  assert.match(source, /from\("trade_orders"\)\.insert/);
  assert.match(source, /Acheter OUI/);
  assert.match(source, /Acheter NON/);
  assert.match(source, /Revendre/);
  assert.match(source, /Suivre mes paris/);
  assert.match(source, /market_watchlist/);
  assert.match(source, /konsens:trade/);
  assert.doesNotMatch(source, /outcome-prices[^\n]*<button className="yes"/);
});

test("Finance keeps simulated buy sell watchlist and portfolio tracking wired", async () => {
  const source = await readFile(new URL("../app/live-finance-v2.tsx", import.meta.url), "utf8");
  assert.match(source, /from\("trade_orders"\)\.insert/);
  assert.match(source, /Acheter en simulation/);
  assert.match(source, /Revendre/);
  assert.match(source, /asset_watchlist/);
  assert.match(source, /Suivre mes investissements/);
  assert.match(source, /average_price/);
  assert.match(source, /konsens:trade/);
});

test("Academy persists real quiz progress", async () => {
  const source = await readFile(new URL("../app/academy-v2.tsx", import.meta.url), "utf8");
  assert.match(source, /from\("learning_progress"\)\.upsert/);
  assert.match(source, /Impossible d’enregistrer/);
  assert.match(source, /Valider le module/);
});

test("Premium activation remains connected to the beta entitlement RPC", async () => {
  const source = await readFile(new URL("../app/premium-v2.tsx", import.meta.url), "utf8");
  assert.match(source, /start_premium_beta_trial/);
  assert.match(source, /konsens:subscription/);
  assert.match(source, /Activer 14 jours gratuitement/);
});

test("Konsens Revenue keeps ad and SDK admin actions wired", async () => {
  const revenue = await readFile(new URL("../app/monetization/page.tsx", import.meta.url), "utf8");
  const ads = await readFile(new URL("../app/monetization/ads/page.tsx", import.meta.url), "utf8");
  assert.match(revenue, /create_sdk_client/);
  assert.match(revenue, /Créer la clé/);
  assert.match(ads, /from\("advertisers"\)\.insert/);
  assert.match(ads, /from\("ad_campaigns"\)\.insert/);
  assert.match(ads, /from\("ad_creatives"\)\.insert/);
  assert.match(ads, /Activer la campagne/);
});
