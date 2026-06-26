// Token refresh: the app proves continued possession of its enrolled key with an
// "assertion" over SHA256(challenge). We verify it against the stored public key,
// require the sign counter to strictly increase (replay protection), and mint a
// fresh short-lived bearer token.
//
// Dev bypass: in development only (NODE_ENV !== production), if ATTEST_DEV_BYPASS
// is set and the request carries it in `x-attest-dev-bypass`, we mint a token
// without attestation so the iOS Simulator (which can't do App Attest) still
// works against `npm run dev`. The env var is never set on deployed envs.

import { NextRequest, NextResponse } from "next/server";
import { verifyAssertion } from "node-app-attest";
import { APP_ATTEST, consumeChallenge, getDevice, updateSignCount } from "@/lib/appAttest";
import { mintDeviceToken } from "@/lib/attestToken";
import { limitAttestByIp } from "@/lib/ratelimit";
import { clientIp } from "@/lib/clientIp";
import { guardConfig } from "@/lib/configCheck";

export const runtime = "nodejs";

const DEV_BYPASS_KEY_ID = "dev-bypass-device";

export async function POST(req: NextRequest) {
  const misconfig = guardConfig();
  if (misconfig) return misconfig;

  // ── Dev-only bypass for the Simulator ──
  const bypass = process.env.ATTEST_DEV_BYPASS;
  if (process.env.NODE_ENV !== "production" && bypass && req.headers.get("x-attest-dev-bypass") === bypass) {
    const { token, expiresAt } = await mintDeviceToken(DEV_BYPASS_KEY_ID);
    return NextResponse.json({ token, expiresAt, dev: true });
  }

  if (!(await limitAttestByIp(clientIp(req)))) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }

  const body = await req.json().catch(() => null);
  const keyId = body?.keyId;
  const assertion = body?.assertion;
  const challengeId = body?.challengeId;
  if (typeof keyId !== "string" || typeof assertion !== "string" || typeof challengeId !== "string") {
    return NextResponse.json({ error: "keyId, assertion and challengeId are required" }, { status: 400 });
  }

  const challenge = await consumeChallenge(challengeId);
  if (!challenge) {
    return NextResponse.json({ error: "Challenge expired or already used" }, { status: 400 });
  }

  const device = await getDevice(keyId);
  if (!device) {
    // Unknown key (server lost state, or never enrolled) → tell the app to re-register.
    return NextResponse.json({ error: "Unknown device — re-register" }, { status: 409 });
  }

  let signCount: number;
  try {
    ({ signCount } = verifyAssertion({
      assertion: Buffer.from(assertion, "base64"),
      payload: challenge, // the library hashes SHA256(payload) to form the clientDataHash
      publicKey: device.publicKey,
      bundleIdentifier: APP_ATTEST.bundleId,
      teamIdentifier: APP_ATTEST.teamId,
      signCount: device.signCount,
    }));
  } catch {
    return NextResponse.json({ error: "Assertion verification failed" }, { status: 401 });
  }

  await updateSignCount(keyId, signCount);

  const { token, expiresAt } = await mintDeviceToken(keyId);
  return NextResponse.json({ token, expiresAt });
}
