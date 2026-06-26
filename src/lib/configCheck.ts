// Fail-loud guard against a misconfigured PRODUCTION deploy. Both failure modes
// here would otherwise degrade silently:
//   • no JWT secret  → tokens signed with a public default literal (forgeable)
//   • no Redis       → in-memory store, which on serverless is non-durable and
//                       not shared across instances (enrollment + rate limits break)
// In production we refuse to operate and log clearly, instead of pretending to work.

import { NextResponse } from "next/server";
import { usingMemoryStore } from "./redis";
import { usingDefaultJwtSecret } from "./attestToken";

/** A human-readable reason the deploy is critically misconfigured, or null when
 *  healthy. Always null outside production. */
export function productionConfigError(): string | null {
  if (process.env.NODE_ENV !== "production") return null;
  const problems: string[] = [];
  if (usingDefaultJwtSecret) {
    problems.push("ATTEST_JWT_SECRET (or NEXTAUTH_SECRET) is not set");
  }
  if (usingMemoryStore) {
    problems.push("Upstash Redis is not configured (UPSTASH_REDIS_REST_* / KV_REST_API_*)");
  }
  return problems.length ? problems.join("; ") : null;
}

/** Returns a 503 response (and logs loudly) when production is misconfigured,
 *  else null. Call at the top of the public attest routes. */
export function guardConfig(): NextResponse | null {
  const reason = productionConfigError();
  if (!reason) return null;
  console.error(`[FATAL CONFIG] Refusing requests — ${reason}`);
  return NextResponse.json(
    { error: "The service is temporarily unavailable." },
    { status: 503 },
  );
}
