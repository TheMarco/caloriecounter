import type { NextRequest } from "next/server";

/** Best-effort client IP for rate limiting. Vercel sets `x-forwarded-for`. */
export function clientIp(req: NextRequest): string {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  return req.headers.get("x-real-ip") ?? "unknown";
}
