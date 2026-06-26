// Abuse controls. Two layers:
//   • sliding-window rate limits (per-IP on the expensive attest endpoints,
//     per-device on the proxy) to blunt bursts, and
//   • a per-device DAILY ceiling — the hard cap that actually protects the
//     OpenAI bill even if a token leaks.
//
// When Upstash isn't configured (local dev) the window limiters allow-all and
// the daily ceiling uses the in-memory store, so development isn't blocked.

import { Ratelimit } from "@upstash/ratelimit";
import { upstash, kv } from "./redis";

const attestLimiter = upstash
  ? new Ratelimit({
      redis: upstash,
      limiter: Ratelimit.slidingWindow(20, "10 m"),
      prefix: "rl:attest",
      analytics: false,
    })
  : null;

const proxyLimiter = upstash
  ? new Ratelimit({
      redis: upstash,
      limiter: Ratelimit.slidingWindow(40, "1 m"),
      prefix: "rl:proxy",
      analytics: false,
    })
  : null;

/** Per-IP limit for `/api/attest/*` (enrollment is the costly path to abuse). */
export async function limitAttestByIp(ip: string): Promise<boolean> {
  if (!attestLimiter) return true;
  const { success } = await attestLimiter.limit(ip);
  return success;
}

/** Per-device burst limit for the proxy routes. */
export async function limitProxyByDevice(keyId: string): Promise<boolean> {
  if (!proxyLimiter) return true;
  const { success } = await proxyLimiter.limit(keyId);
  return success;
}

/** Hard per-device daily call ceiling. Default 300/day; override with
 *  PROXY_DAILY_DEVICE_LIMIT. Returns false once the device is over budget. */
const DAILY_MAX = Number(process.env.PROXY_DAILY_DEVICE_LIMIT) || 300;

export async function withinDailyCeiling(keyId: string): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10); // yyyy-mm-dd (UTC)
  const count = await kv.incrWithTtl(`attest:quota:${keyId}:${day}`, 60 * 60 * 26);
  return count <= DAILY_MAX;
}
