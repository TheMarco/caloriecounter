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
│   │   ├── auth/route.ts            # POST password → sets signed `calorie-auth` cookie
│   │   ├── auth/check/route.ts      # GET → reports cookie validity
│   │   ├── barcode/[code]/route.ts  # Barcode lookup (Open Food Facts + OpenAI)
│   │   ├── parse-food/route.ts      # Text/voice food parsing (OpenAI, with a fallback)
│   │   └── parse-photo/route.ts     # Photo analysis with the Vision API
│   ├── page.tsx          # Marketing landing page (static)
│   ├── layout.tsx        # Root layout + metadata/OG; unregisters any legacy SW
│   └── not-found.tsx     # 404 (marketing-themed)
├── lib/auth.ts           # HMAC cookie signing/verification + password check
├── middleware.ts         # Guards /api/* (see below)
└── types/index.ts        # API request/response DTOs
```

### Auth model
`middleware.ts` only runs on `/api/:path*`. `/api/auth*` is public; every other API
route requires a valid signed **`calorie-auth`** cookie or returns `401`. The iOS app
authenticates by POSTing the shared password to `/api/auth`, then replays the cookie on
`/api/parse-*` and `/api/barcode/*`. The marketing page and all static assets are public
(middleware doesn't run on them).

### Environment Variables
- `OPENAI_API_KEY` — food parsing and photo analysis (required for the proxy to work).
- `AUTH_PASSWORD` — the shared proxy password the iOS app sends to `/api/auth`.
- `NEXTAUTH_SECRET` (or `AUTH_SECRET`) — HMAC secret used to sign/verify the cookie.

### Path Alias
`@/*` maps to `./src/*` for imports.
