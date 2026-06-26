// App Attest configuration + the challenge/device records kept in Redis.
//
// Flow recap:
//   1. App asks for a one-time `challenge` (issueChallenge).
//   2. App attests its Secure-Enclave key over SHA256(challenge); we verify the
//      attestation, then persist the device's public key + sign counter.
//   3. For each token refresh the app signs SHA256(challenge) again (an
//      "assertion"); we verify it against the stored key and bump the counter.
//
// This module is imported only by the Node-runtime `/api/attest/*` routes.

import { randomBytes, randomUUID } from "crypto";
import { kv } from "./redis";

export const APP_ATTEST = {
  /** Apple Team ID — forms the App ID `teamId.bundleId` that attestations bind to. */
  teamId: process.env.APP_ATTEST_TEAM_ID || "3ML6V62AF5",
  bundleId: process.env.APP_ATTEST_BUNDLE_ID || "com.aidashcreated.caloriecounter",
  /** Accept attestations from the Apple "development" environment (Xcode/dev
   *  builds + TestFlight). Set APP_ATTEST_ALLOW_DEV=false to require production. */
  allowDevelopmentEnvironment: process.env.APP_ATTEST_ALLOW_DEV !== "false",
};

const CHALLENGE_TTL_SECONDS = 5 * 60;

// ── Challenges (one-time, short-lived) ──────────────────────────────────────

export async function issueChallenge(): Promise<{ challengeId: string; challenge: string }> {
  const challengeId = randomUUID();
  const challenge = randomBytes(32).toString("base64url");
  await kv.set(`attest:challenge:${challengeId}`, challenge, { ex: CHALLENGE_TTL_SECONDS });
  return { challengeId, challenge };
}

/** Fetch and immediately invalidate a challenge so it can be used exactly once. */
export async function consumeChallenge(challengeId: string): Promise<string | null> {
  if (!challengeId) return null;
  const key = `attest:challenge:${challengeId}`;
  const challenge = await kv.get<string>(key);
  if (challenge) await kv.del(key);
  return challenge;
}

// ── Device records (durable) ────────────────────────────────────────────────

export interface DeviceRecord {
  publicKey: string; // SPKI PEM from the attestation certificate
  signCount: number; // monotonically increasing assertion counter
  createdAt: number;
}

const deviceKey = (keyId: string) => `attest:device:${keyId}`;

export async function getDevice(keyId: string): Promise<DeviceRecord | null> {
  return kv.get<DeviceRecord>(deviceKey(keyId));
}

export async function saveDevice(keyId: string, record: DeviceRecord): Promise<void> {
  await kv.set(deviceKey(keyId), record);
}

export async function updateSignCount(keyId: string, signCount: number): Promise<void> {
  const record = await getDevice(keyId);
  if (!record) return;
  record.signCount = signCount;
  await kv.set(deviceKey(keyId), record);
}
