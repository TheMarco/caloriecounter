// Datastore for App Attest device keys, one-time challenges, and rate-limit
// counters. Uses Upstash Redis in production (set UPSTASH_REDIS_REST_URL +
// UPSTASH_REDIS_REST_TOKEN). When those are absent — local `npm run dev` — it
// transparently falls back to an in-memory store so the backend still runs
// (NOT for production: it's per-instance and non-durable).

import { Redis } from "@upstash/redis";

// Accept either the canonical Upstash names or the KV_* names that Vercel's
// Upstash/KV integration injects — `KV_REST_API_URL` / `KV_REST_API_TOKEN` are
// the same HTTPS REST endpoint + read-write token. (The `REDIS_URL` / `KV_URL`
// values are redis:// TCP strings and are NOT used — @upstash/redis is HTTP, and
// we deliberately avoid the read-only token since we INCR/SET/DEL.)
const restUrl = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const restToken = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

/** The raw Upstash client, or null when not configured (dev fallback active). */
export const upstash: Redis | null =
  restUrl && restToken ? new Redis({ url: restUrl, token: restToken }) : null;

export const usingMemoryStore = upstash === null;

// ── In-memory fallback (dev only) ───────────────────────────────────────────
type Entry = { value: unknown; expiresAt: number | null };
const mem = new Map<string, Entry>();

function memGet<T>(key: string): T | null {
  const e = mem.get(key);
  if (!e) return null;
  if (e.expiresAt !== null && e.expiresAt < Date.now()) {
    mem.delete(key);
    return null;
  }
  return e.value as T;
}

// ── Small KV abstraction the routes use ─────────────────────────────────────
export const kv = {
  async get<T = unknown>(key: string): Promise<T | null> {
    if (upstash) return (await upstash.get<T>(key)) ?? null;
    return memGet<T>(key);
  },

  async set(key: string, value: unknown, opts?: { ex?: number }): Promise<void> {
    if (upstash) {
      await (opts?.ex ? upstash.set(key, value, { ex: opts.ex }) : upstash.set(key, value));
      return;
    }
    mem.set(key, { value, expiresAt: opts?.ex ? Date.now() + opts.ex * 1000 : null });
  },

  async del(key: string): Promise<void> {
    if (upstash) {
      await upstash.del(key);
      return;
    }
    mem.delete(key);
  },

  /** Atomic-ish increment that sets the TTL window on first hit. Used for the
   *  per-device daily ceiling. Returns the new counter value. */
  async incrWithTtl(key: string, ttlSeconds: number): Promise<number> {
    if (upstash) {
      const n = await upstash.incr(key);
      if (n === 1) await upstash.expire(key, ttlSeconds);
      return n;
    }
    const current = memGet<number>(key) ?? 0;
    const next = current + 1;
    const existing = mem.get(key);
    mem.set(key, {
      value: next,
      expiresAt: existing?.expiresAt ?? Date.now() + ttlSeconds * 1000,
    });
    return next;
  },

  /** Add a (possibly fractional) amount to a counter, keeping it on a TTL window.
   *  Used to accumulate per-device monthly OpenAI spend. Returns the new total. */
  async incrByFloat(key: string, amount: number, ttlSeconds: number): Promise<number> {
    if (upstash) {
      const n = await upstash.incrbyfloat(key, amount);
      await upstash.expire(key, ttlSeconds); // month-stamped key; refreshing TTL is harmless
      return typeof n === "number" ? n : Number(n);
    }
    const current = memGet<number>(key) ?? 0;
    const next = current + amount;
    const existing = mem.get(key);
    mem.set(key, {
      value: next,
      expiresAt: existing?.expiresAt ?? Date.now() + ttlSeconds * 1000,
    });
    return next;
  },
};
