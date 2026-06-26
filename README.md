# 🍎 Calorie Tracker

**Calorie Tracker** is a private, AI-powered calorie and macro tracker for iOS. Log
meals by voice, photo, barcode, or text — AI does the math, and your food diary never
leaves your iPhone. No account, no analytics, no tracking. *Coming soon to the App Store.*

This repository contains two things:

| Path | What it is |
| --- | --- |
| **`apple/`** | The native **iOS app** (SwiftUI, iOS 26, Swift 6). This is the product. See [`apple/CLAUDE.md`](apple/CLAUDE.md) and [`apple/FEATURES.md`](apple/FEATURES.md). |
| **repo root** | A small **Next.js project** that serves the public **marketing landing page** at `/` and acts as the iOS app's **API backend** (the `/api/*` OpenAI proxy). |

> **Note:** This used to be a local-first web PWA. That web app has been retired — the
> product is iOS-only now. The web project's sole jobs are the marketing page and the
> API proxy that keeps the OpenAI key off the device.

## 🛠️ Tech Stack (web)

- **Next.js 15** (App Router) · **React 19** · **TypeScript**
- **Tailwind CSS v4** — the landing page is styled to mirror the iOS app
- **OpenAI API** — food parsing & photo analysis (server-side only)
- **Open Food Facts** — barcode nutrition lookup

## 🚀 Quick Start

```bash
npm install
cp .env.example .env.local   # then fill in the variables below
npm run dev                  # http://localhost:3000
```

Production:

```bash
npm run build
npm start
```

## 🔒 Environment Variables

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Food parsing and photo analysis (required for the proxy). |
| `AUTH_PASSWORD` | Shared password the iOS app POSTs to `/api/auth` to obtain its session cookie. |
| `NEXTAUTH_SECRET` (or `AUTH_SECRET`) | HMAC secret used to sign/verify the `calorie-auth` cookie. |

Never commit real secrets. Use `.env.local` locally (git-ignored) and the host's
environment variables in production.

## 📁 Project Structure (web)

```
src/
├── app/
│   ├── api/              # iOS backend: auth, parse-food, parse-photo, barcode
│   ├── page.tsx          # Marketing landing page (static)
│   ├── layout.tsx        # Metadata / OpenGraph
│   └── globals.css       # Tailwind + the `.ct` design-system styles
├── lib/auth.ts           # Signed-cookie helpers + password check
├── middleware.ts         # Guards /api/* (except /api/auth*)
└── types/index.ts        # API DTOs

public/                   # Landing-page imagery + favicons
```

The iOS app's structure is documented separately in `apple/CLAUDE.md`.

## 📄 License

This software is licensed under a custom non-commercial license. See the [LICENSE](LICENSE)
file for complete terms.

- ✅ Free for personal, non-commercial use
- ❌ Commercial use requires permission; attribution may not be removed

For commercial licensing, contact: info@ai-created.com

## 📊 Data Sources & Attribution

Barcode nutrition data comes from **Open Food Facts** (ODbL); food analysis is powered by
**OpenAI**. See [ATTRIBUTION.md](ATTRIBUTION.md) for full details and any additional sources.

## 👨‍💻 Author

**Marco van Hylckama Vlieg** — [ai-created.com](https://ai-created.com/) · info@ai-created.com

---

**Copyright © 2026 Marco van Hylckama Vlieg.** Built with ❤️ using AI-assisted development.
