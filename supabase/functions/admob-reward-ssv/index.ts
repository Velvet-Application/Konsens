import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";
import { Buffer } from "node:buffer";
import { createPublicKey, verify } from "node:crypto";

const PROD_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const TEST_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys-test.json";
const CACHE_TTL_MS = 12 * 60 * 60 * 1000;
const MAX_REWARD_AGE_MS = 6 * 60 * 60 * 1000;
const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000;

type GoogleKey = { keyId: number; pem: string };
type CachedKeys = { fetchedAt: number; keys: Map<string, string> };

let prodCache: CachedKeys | null = null;
let testCache: CachedKeys | null = null;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function isUuid(value: string | null): value is string {
  return !!value && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function decodeBase64Url(value: string) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return Buffer.from(padded, "base64");
}

async function fetchKeySet(url: string, cached: CachedKeys | null) {
  const now = Date.now();
  if (cached && now - cached.fetchedAt < CACHE_TTL_MS) return cached;

  const response = await fetch(url, {
    headers: { accept: "application/json" },
  });
  if (!response.ok) throw new Error(`admob_key_fetch_${response.status}`);

  const payload = await response.json() as { keys?: GoogleKey[] };
  const keys = new Map<string, string>();
  for (const key of payload.keys ?? []) {
    if (key?.pem && Number.isFinite(key?.keyId)) keys.set(String(key.keyId), key.pem);
  }
  if (!keys.size) throw new Error("admob_key_set_empty");
  return { fetchedAt: now, keys } satisfies CachedKeys;
}

async function getProductionKey(keyId: string) {
  prodCache = await fetchKeySet(PROD_KEYS_URL, prodCache);
  return prodCache.keys.get(keyId) ?? null;
}

async function getTestKey(keyId: string) {
  testCache = await fetchKeySet(TEST_KEYS_URL, testCache);
  return testCache.keys.get(keyId) ?? null;
}

function parseSignedCallback(request: Request) {
  const url = new URL(request.url);
  const rawQuery = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  const signatureMarker = "&signature=";
  const keyMarker = "&key_id=";
  const signatureIndex = rawQuery.indexOf(signatureMarker);
  const keyIndex = rawQuery.indexOf(keyMarker, Math.max(0, signatureIndex));

  // Google requires signature and key_id to be the final two query parameters, in this order.
  if (signatureIndex <= 0 || keyIndex <= signatureIndex || rawQuery.indexOf("&", keyIndex + keyMarker.length) !== -1) {
    throw new Error("invalid_ssv_parameter_order");
  }

  const signedContent = rawQuery.slice(0, signatureIndex);
  const params = url.searchParams;
  const signature = params.get("signature");
  const keyId = params.get("key_id");
  if (!signature || !keyId || !/^\d+$/.test(keyId)) throw new Error("missing_ssv_signature");

  return { url, params, signedContent, signature, keyId };
}

function verifySignature(signedContent: string, signature: string, pem: string) {
  const key = createPublicKey(pem);
  return verify(
    "sha256",
    Buffer.from(signedContent, "utf8"),
    key,
    decodeBase64Url(signature),
  );
}

Deno.serve(async (request) => {
  if (request.method !== "GET") return json({ ok: false, error: "method_not_allowed" }, 405);

  try {
    const { params, signedContent, signature, keyId } = parseSignedCallback(request);
    const customData = params.get("custom_data");
    const isSetupProbe = customData?.startsWith("setup:konsens") === true;

    let pem = await getProductionKey(keyId);
    let keyEnvironment: "prod" | "test" = "prod";

    // Test keys are accepted only for AdMob's callback-URL verification probe and can never grant Koins.
    if (!pem && isSetupProbe) {
      pem = await getTestKey(keyId);
      keyEnvironment = "test";
    }

    if (!pem || !verifySignature(signedContent, signature, pem)) {
      return json({ ok: false, error: "invalid_signature" }, 401);
    }

    if (isSetupProbe) {
      return json({ ok: true, mode: "setup_probe", key_environment: keyEnvironment });
    }

    // From this point onward only production AdMob keys can authorize an economic mutation.
    if (keyEnvironment !== "prod") return json({ ok: false, error: "test_key_cannot_reward" }, 401);

    const userId = params.get("user_id");
    const rewardNonce = customData;
    const adUnit = params.get("ad_unit") ?? "";
    const transactionId = params.get("transaction_id") ?? "";
    const timestampText = params.get("timestamp") ?? "";
    const adNetwork = params.get("ad_network") ?? "";
    const rewardItem = params.get("reward_item") ?? "";
    const rewardAmountText = params.get("reward_amount") ?? "";

    if (!isUuid(userId) || !isUuid(rewardNonce)) {
      return json({ ok: false, error: "invalid_reward_identity" }, 400);
    }
    if (transactionId.length < 8 || transactionId.length > 220) {
      return json({ ok: false, error: "invalid_transaction_id" }, 400);
    }

    const timestamp = Number(timestampText);
    const rewardAmount = Number(rewardAmountText);
    if (!Number.isFinite(timestamp) || !Number.isFinite(rewardAmount)) {
      return json({ ok: false, error: "invalid_reward_payload" }, 400);
    }

    const age = Date.now() - timestamp;
    if (age > MAX_REWARD_AGE_MS || age < -MAX_FUTURE_SKEW_MS) {
      return json({ ok: false, error: "stale_reward_callback" }, 400);
    }

    const configuredAdUnit = Deno.env.get("ADMOB_REWARDED_AD_UNIT_ID")?.trim();
    if (configuredAdUnit && adUnit !== configuredAdUnit) {
      return json({ ok: false, error: "unexpected_ad_unit" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRole) return json({ ok: false, error: "server_not_configured" }, 503);

    const supabase = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await supabase.rpc("finalize_daily_reward_video_ssv", {
      p_user_id: userId,
      p_reward_nonce: rewardNonce,
      p_ad_unit: adUnit,
      p_transaction_id: transactionId,
      p_timestamp: Math.trunc(timestamp),
      p_ad_network: adNetwork,
      p_reward_item: rewardItem,
      p_reward_amount: rewardAmount,
    });

    if (error) {
      console.error("AdMob SSV finalization failed", {
        code: error.code,
        message: error.message,
        transactionId,
      });
      return json({ ok: false, error: "reward_finalization_failed" }, 500);
    }

    const result = Array.isArray(data) ? data[0] : data;
    return json({
      ok: true,
      transaction_id: transactionId,
      claimed: result?.claimed ?? false,
      amount: result?.amount ?? 100,
    });
  } catch (error) {
    console.error("AdMob SSV rejected", error);
    return json({ ok: false, error: error instanceof Error ? error.message : "invalid_callback" }, 400);
  }
});
