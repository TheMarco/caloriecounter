// Step 1 of App Attest: hand the app a one-time, short-lived challenge. The app
// hashes it (SHA256) and signs that hash with its Secure-Enclave key in the next
// step (register or token). Public, but per-IP rate limited.

import { NextRequest, NextResponse } from "next/server";
import { issueChallenge } from "@/lib/appAttest";
import { limitAttestByIp } from "@/lib/ratelimit";
import { clientIp } from "@/lib/clientIp";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  if (!(await limitAttestByIp(clientIp(req)))) {
    return NextResponse.json({ error: "Too many requests" }, { status: 429 });
  }
  const { challengeId, challenge } = await issueChallenge();
  return NextResponse.json({ challengeId, challenge });
}
