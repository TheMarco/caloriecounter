// Shared gate for the OpenAI proxy routes (parse-food / parse-photo / barcode).
// The device id is taken from the `x-device-id` header, which the middleware
// sets from the verified bearer token (and strips from the incoming request, so
// a client can't spoof it). Applies the per-device burst limit, daily ceiling,
// and monthly spend cap.
//
// IMPORTANT: the abuse limits are INVISIBLE to the user. A device that trips one
// gets the same generic "temporarily unavailable" a transient hiccup would
// produce — never anything that reveals a quota/limit. Real users never hit these
// (normal use is a few cents/month), so only an abuser sees the soft wall, and
// they can't tell it's a deliberate cap. Retries are free: this gate short-circuits
// before any OpenAI call, so a blocked device costs nothing.

import type { NextRequest } from "next/server";
import { limitProxyByDevice, withinDailyCeiling } from "./ratelimit";
import { productionConfigError } from "./configCheck";
import { overMonthlyCap } from "./openaiCost";

// Single neutral, non-limit message for every refusal the user might see.
const UNAVAILABLE = "We couldn’t process that right now. Please try again later.";

export type GuardResult =
  | { ok: true; keyId: string }
  | { ok: false; status: number; error: string };

function unavailable(): GuardResult {
  return { ok: false, status: 503, error: UNAVAILABLE };
}

export async function guardProxy(req: NextRequest): Promise<GuardResult> {
  const misconfig = productionConfigError();
  if (misconfig) {
    console.error(`[FATAL CONFIG] Refusing proxy request — ${misconfig}`);
    return unavailable();
  }

  const keyId = req.headers.get("x-device-id") ?? "";
  if (!keyId) return { ok: false, status: 401, error: "Unauthorized" };

  // Abuse guards — all surface as the same generic message above (never a
  // "limit"). Logged server-side so abuse is still visible to operators.
  if (!(await limitProxyByDevice(keyId))) {
    console.warn(`[abuse] device ${keyId} hit the burst limit`);
    return unavailable();
  }
  if (!(await withinDailyCeiling(keyId))) {
    console.warn(`[abuse] device ${keyId} hit the daily ceiling`);
    return unavailable();
  }
  if (await overMonthlyCap(keyId)) {
    console.warn(`[abuse] device ${keyId} hit the monthly spend cap — refusing silently until next month`);
    return unavailable();
  }
  return { ok: true, keyId };
}
