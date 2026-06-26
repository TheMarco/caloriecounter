// Shared gate for the OpenAI proxy routes (parse-food / parse-photo / barcode).
// The device id is taken from the `x-device-id` header, which the middleware
// sets from the verified bearer token (and strips from the incoming request, so
// a client can't spoof it). Applies the per-device burst limit + daily ceiling.

import type { NextRequest } from "next/server";
import { limitProxyByDevice, withinDailyCeiling } from "./ratelimit";

export type GuardResult =
  | { ok: true; keyId: string }
  | { ok: false; status: number; error: string };

export async function guardProxy(req: NextRequest): Promise<GuardResult> {
  const keyId = req.headers.get("x-device-id") ?? "";
  if (!keyId) return { ok: false, status: 401, error: "Unauthorized" };

  if (!(await limitProxyByDevice(keyId))) {
    return { ok: false, status: 429, error: "Too many requests — slow down." };
  }
  if (!(await withinDailyCeiling(keyId))) {
    return { ok: false, status: 429, error: "Daily request limit reached." };
  }
  return { ok: true, keyId };
}
