# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **This repo is the home of an iOS app.** The **native iOS app** lives in `apple/`
> and has its own `apple/CLAUDE.md` (build/test commands, NutritionKit architecture,
> conventions) — when working under `apple/`, follow that file. A full feature map is
> in `apple/FEATURES.md`.
>
> The **repo root is a small Next.js project** that does two things, and only two:
> 1. Serves the public **marketing landing page** at `/` (`src/app/page.tsx`).
> 2. Acts as the iOS app's **API backend** — the `/api/*` proxy that holds the
>    OpenAI key server-side so the app never ships it.
>
> The former local-first **web PWA calorie tracker was retired** (the product is
> iOS-only now). If you find references to web pages like `/history` / `/settings`,
> IndexedDB, input hooks, SWR, or a service worker, they are gone — don't reintroduce
> them.

## Build and Development Commands

```bash
npm run dev          # Start development server at localhost:3000
npm run build        # Production build
npm run start        # Start production server
npm run lint         # Run ESLint
```

There is no test suite in this project anymore (the web-app unit/e2e tests were
removed with the PWA). The iOS app has its own tests — see `apple/CLAUDE.md`.

## Architecture Overview

### Tech Stack
- **Next.js 15** with App Router, React 19, TypeScript
- **Tailwind CSS v4** for styling
- **OpenAI API** for food recognition (text/voice/photo); Open Food Facts for barcodes

### Marketing page
`src/app/page.tsx` is a **static server component** (no client JS beyond a tiny
service-worker cleanup script in `layout.tsx`). It's styled to match the iOS app via a
`.ct` design-system block in `src/app/globals.css` (near-black `#0C0D10`, matte cards
`#16181D`, sage-green `#57B58C` accent, macro colors). Imagery lives in `public/`
(`hero-food.webp`, `app-icon.webp`, `og.webp`, `screenshots/app/*.webp`).

### API backend (what the iOS app calls)

```
src/
├── app/
│   ├── api/
│   │   ├── attest/challenge/route.ts  # One-time App Attest challenge
│   │   ├── attest/register/route.ts   # Verify attestation, enroll device, mint JWT
│   │   ├── attest/token/route.ts      # Verify assertion (or dev bypass), mint JWT
│   │   ├── barcode/[code]/route.ts    # Barcode lookup (Open Food Facts + OpenAI)
│   │   ├── parse-food/route.ts        # Text/voice food parsing (OpenAI, with a fallback)
│   │   └── parse-photo/route.ts       # Photo analysis with the Vision API
│   ├── page.tsx          # Marketing landing page (static)
│   ├── layout.tsx        # Root layout + metadata/OG; unregisters any legacy SW
│   └── not-found.tsx     # 404 (marketing-themed)
├── lib/
│   ├── appAttest.ts      # App Attest config + challenge/device Redis records
│   ├── attestToken.ts    # Bearer JWT mint/verify (jose)
│   ├── redis.ts          # Upstash client + in-memory dev fallback
│   ├── ratelimit.ts      # Per-IP / per-device limits + daily ceiling
│   ├── proxyGuard.ts     # Per-request gate for the proxy routes
│   └── clientIp.ts
├── middleware.ts         # Verifies the bearer JWT on /api/* (see below)
└── types/index.ts        # API request/response DTOs
```

### Auth model (Apple App Attest)
The proxy routes (`/api/parse-*`, `/api/barcode/*`) require a short-lived **bearer JWT**;
`middleware.ts` (Edge runtime) verifies `Authorization: Bearer <jwt>` and forwards a
server-set `x-device-id` (overwriting any client value, so it can't be spoofed). The iOS
app obtains the token via App Attest — **no account, no shipped secret**:
- `POST /api/attest/challenge` → one-time challenge (Redis, 5-min TTL)
- `POST /api/attest/register` → verify the Secure-Enclave attestation
  (`node-app-attest`) against Apple's App Attest root CA, store the device public key +
  sign counter, return the first JWT
- `POST /api/attest/token` → verify an assertion, require the counter to strictly
  increase, return a fresh JWT

`/api/attest/*` is public (per-IP rate limited). The marketing page + static assets are
public (middleware only runs on `/api/*`). Abuse controls live in `ratelimit.ts`: per-IP
limit on the attest endpoints, per-device burst limit + a hard daily ceiling on the proxy
(Upstash; in-memory fallback when Redis isn't configured). A **DEBUG-only dev bypass**
(`ATTEST_DEV_BYPASS`, honored only when `NODE_ENV != production`) lets the iOS Simulator
get a token without attestation. These routes run on the **Node runtime**
(`export const runtime = "nodejs"`) because attestation verification needs Node crypto.

### Environment Variables
- `OPENAI_API_KEY` — food parsing and photo analysis. **Set a hard monthly budget cap on
  the key** — that's the real bill protection.
- `ATTEST_JWT_SECRET` (or `NEXTAUTH_SECRET`) — HMAC secret that signs/verifies the JWT.
- `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` — device keys, challenges, rate
  limits (in-memory fallback if unset — dev only).
- `APP_ATTEST_TEAM_ID` / `APP_ATTEST_BUNDLE_ID` — default to this app's IDs.
- `ATTEST_DEV_BYPASS` — DEBUG-only Simulator bypass; **never set in production**.

See `.env.example` for the full list and notes.

### Path Alias
`@/*` maps to `./src/*` for imports.
