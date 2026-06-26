// Step 2 (first launch): enrollment. The app sends its keyId + the attestation
// object Apple produced for SHA256(challenge). We verify it against Apple's App
// Attest root CA (genuine, unmodified build of THIS app on a real device), store
// the device's public key + sign counter, and return the first bearer token.

import { NextRequest, NextResponse } from "next/server";
import { verifyAttestation } from "node-app-attest";
import { APP_ATTEST, consumeChallenge, saveDevice } from "@/lib/appAttest";
import { mintDeviceToken } from "@/lib/attestToken";
import { limitAttestByIp } from "@/lib/ratelimit";
import { clientIp } from "@/lib/clientIp";
import { guardConfig } from "@/lib/configCheck";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  const misconfig = guardConfig();
  if (misconfig) return misconfig;

  if (!(await limitAttestByIp(clientIp(req)))) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }

  const body = await req.json().catch(() => null);
  const keyId = body?.keyId;
  const attestation = body?.attestation;
  const challengeId = body?.challengeId;
  if (typeof keyId !== "string" || typeof attestation !== "string" || typeof challengeId !== "string") {
    return NextResponse.json({ error: "keyId, attestation and challengeId are required" }, { status: 400 });
  }

  const challenge = await consumeChallenge(challengeId);
  if (!challenge) {
    return NextResponse.json({ error: "Challenge expired or already used" }, { status: 400 });
  }

  let result: { publicKey: string };
  try {
    result = verifyAttestation({
      attestation: Buffer.from(attestation, "base64"),
      challenge, // the library hashes SHA256(challenge) to form the expected clientDataHash
      keyId,
      bundleIdentifier: APP_ATTEST.bundleId,
      teamIdentifier: APP_ATTEST.teamId,
      allowDevelopmentEnvironment: APP_ATTEST.allowDevelopmentEnvironment,
    });
  } catch {
    return NextResponse.json({ error: "Attestation verification failed" }, { status: 401 });
  }

  await saveDevice(keyId, { publicKey: result.publicKey, signCount: 0, createdAt: Date.now() });

  const { token, expiresAt } = await mintDeviceToken(keyId);
  return NextResponse.json({ token, expiresAt });
}
