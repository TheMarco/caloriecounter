# Backend security

The web project exposes the iOS app's API backend — the OpenAI proxy
(`/api/parse-food`, `/api/parse-photo`, `/api/barcode/*`). Every call costs money,
so it must be reachable by the genuine app **without a user account** and protected
against abuse.

## How it works

The app authenticates with **Apple App Attest**. No password or key is shipped in the
binary; instead a Secure-Enclave key proves the request comes from a genuine, unmodified
build of this app (Team ID `3ML6V62AF5`, bundle `com.aidashcreated.caloriecounter`) on a
real Apple device. The server exchanges that proof for a **short-lived bearer JWT** (~30
min) that the app replays on the proxy routes.

```
First launch (enroll):
  app: DCAppAttestService.generateKey()                → keyId (Secure Enclave)
  server: POST /api/attest/challenge                   → one-time challenge (Redis, 5 min)
  app: attestKey(keyId, SHA256(challenge))             → attestation object
  server: POST /api/attest/register
          → verify vs Apple App Attest root CA (node-app-attest),
            store {keyId → publicKey, signCount}, return JWT

Each token refresh:
  server: POST /api/attest/challenge                   → challenge
  app: generateAssertion(keyId, SHA256(challenge))     → assertion
  server: POST /api/attest/token
          → verify signature + counter strictly increases, return JWT

Each proxy call:
  app: Authorization: Bearer <jwt>
  middleware: verify JWT (jose), forward server-set x-device-id (un-spoofable)
```

**Defense in depth — the bearer is not the only thing protecting the bill:**
- Per-IP rate limit on `/api/attest/*` (enrollment is the costly path to abuse).
- Per-device burst limit + a **hard daily call ceiling** on the proxy.
- A **hard monthly budget cap on the OpenAI key** (set in the OpenAI dashboard).

Rate-limit state and device records live in **Upstash Redis**. Locally (no Redis
configured) the backend falls back to an in-memory store so `npm run dev` works.

### Threat model notes
- No client-side secret is truly secret, but App Attest can't be extracted — the private
  key never leaves the Secure Enclave and Apple attests to app integrity. A determined
  attacker on a jailbroken device may still relay assertions; the rate limits + daily
  ceiling + OpenAI budget cap bound the damage.
- Tokens are short-lived, so a leaked token is useless within minutes. A specific abusive
  device can be revoked by deleting its `attest:device:<keyId>` record in Redis.
- Code lives in `src/lib/{appAttest,attestToken,redis,ratelimit,proxyGuard}.ts`,
  `src/app/api/attest/*`, and `src/middleware.ts`. On the app side:
  `Packages/NutritionKit/Sources/NutritionAPI/{AppAttesting,APIClient}.swift`.

## One-time setup checklist

These steps require your accounts and can't be done from code:

- [ ] **Upstash Redis** — Vercel ▸ Marketplace ▸ Upstash; add
      `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` to the Vercel project env
      (Production + Preview).
- [ ] **`ATTEST_JWT_SECRET`** — set a long random string in the Vercel env (or rely on the
      existing `NEXTAUTH_SECRET`).
- [ ] **OpenAI budget cap** — Platform ▸ Settings ▸ Limits ▸ set a hard monthly budget.
- [ ] **App Attest capability** — enable "App Attest" for the App ID
      `com.aidashcreated.caloriecounter` in the Apple Developer portal, then let Xcode
      refresh the provisioning profile (Automatic signing).
- [ ] **Do NOT set `ATTEST_DEV_BYPASS`** in any deployed environment. It's local-only and
      is ignored when `NODE_ENV=production`, but don't set it anyway.

## Testing

- **Local (Simulator):** the Simulator can't do App Attest. In the Xcode scheme
  (Edit Scheme ▸ Run ▸ Arguments ▸ Environment Variables) set `ATTEST_DEV_BYPASS` to a
  value, and optionally `API_BASE_URL=http://localhost:3000`. Run the local proxy with
  the same `ATTEST_DEV_BYPASS` set. The app then obtains a token without attestation.
- **On device:** App Attest runs for real. Build to a device, confirm food logging works
  (enroll → token → proxy). A fresh install re-enrolls automatically; "sign out" clears
  the stored keyId so the next call re-enrolls.
- **Backend:** `npm run build` + `npm run lint`. The attest flow is covered end-to-end on
  the app side by `swift test` (enroll / refresh / 409 re-enroll / dev bypass / bearer).
