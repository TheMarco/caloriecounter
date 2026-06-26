// Short-lived bearer tokens minted after a successful App Attest enrollment or
// assertion. Signed with `jose` (HS256) so the same verify runs in both the
// Node route handlers and the Edge middleware. The token is the ONLY thing the
// app replays on `/api/parse-*` and `/api/barcode/*`; it expires quickly, so a
// leaked token is useless within minutes and individual devices can be revoked
// by deleting their key server-side.

import { SignJWT, jwtVerify } from "jose";

const SECRET = new TextEncoder().encode(
  process.env.ATTEST_JWT_SECRET ||
    process.env.NEXTAUTH_SECRET ||
    "dev-attest-secret-change-me",
);

/** True when no signing secret is configured, so the insecure built-in default
 *  is in use — tokens would be forgeable. Used to fail loudly in production. */
export const usingDefaultJwtSecret =
  !process.env.ATTEST_JWT_SECRET && !process.env.NEXTAUTH_SECRET;

/** Token lifetime in seconds (default 30 min). */
const TTL_SECONDS = Number(process.env.ATTEST_TOKEN_TTL_SECONDS) || 30 * 60;

const ISSUER = "calorie-tracker-proxy";
const AUDIENCE = "calorie-tracker-app";

export async function mintDeviceToken(
  keyId: string,
): Promise<{ token: string; expiresAt: number }> {
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + TTL_SECONDS;
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(keyId)
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .sign(SECRET);
  return { token, expiresAt };
}

/** Verify a bearer token. Returns the device key id, or null if invalid/expired. */
export async function verifyDeviceToken(
  token: string,
): Promise<{ keyId: string } | null> {
  try {
    const { payload } = await jwtVerify(token, SECRET, {
      issuer: ISSUER,
      audience: AUDIENCE,
    });
    if (typeof payload.sub !== "string" || payload.sub.length === 0) return null;
    return { keyId: payload.sub };
  } catch {
    return null;
  }
}
