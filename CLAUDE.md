# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
npm run dev          # Start development server at localhost:3000
npm run build        # Production build
npm run start        # Start production server
npm run lint         # Run ESLint

# Testing
npm test             # Run Jest unit tests
npm run test:watch   # Run tests in watch mode
npm run test:coverage # Run tests with coverage report

# E2E Testing (Playwright)
npm run test:e2e         # Run Playwright tests
npm run test:e2e:ui      # Run with Playwright UI
npm run test:e2e:headed  # Run in headed browser mode
npm run test:e2e:debug   # Debug mode
```

## Architecture Overview

### Tech Stack
- **Next.js 15** with App Router, React 19, TypeScript
- **Tailwind CSS v4** for styling
- **IndexedDB** (via idb-keyval) for local-first data persistence
- **OpenAI API** for food recognition (text/voice/photo) and barcode nutrition lookup
- **SWR** for data fetching with caching

### Data Flow
All food entries are stored locally in IndexedDB. The app is offline-capable via PWA service worker.

**Entry creation flow:**
1. User input (barcode/voice/text/photo) → API route parses with OpenAI → Confirmation dialog
2. User confirms → Entry saved to IndexedDB via `src/utils/idb.ts`
3. UI refreshes via hooks (`useTodayEntries`, `useDayEntries`)

### Key Directories

```
src/
├── app/
│   ├── api/
│   │   ├── barcode/[code]/route.ts  # Barcode lookup (OpenFoodFacts + OpenAI)
│   │   ├── parse-food/route.ts      # Text/voice food parsing
│   │   └── parse-photo/route.ts     # Photo analysis with Vision API
│   ├── page.tsx          # Main entry tracking page
│   ├── history/page.tsx  # Historical data and charts
│   └── settings/page.tsx # User preferences
├── components/           # React components
├── hooks/                # Custom hooks for input methods and data
├── lib/constants.ts      # App-wide constants and configuration
├── types/index.ts        # TypeScript type definitions
└── utils/
    ├── idb.ts            # IndexedDB operations (entries, offsets, queries)
    ├── api.ts            # API client utilities and SWR hooks
    └── csvExport.ts      # Data export functionality
```

### Core Types (src/types/index.ts)
- `Entry`: Food entry with id, date (YYYY-MM-DD), timestamp, food name, quantity, unit, kcal, macros (fat/carbs/protein), input method
- `MacroTotals`: Aggregated nutrition totals
- `MacroTargets`: Daily goal configuration

### Input Hooks Pattern
Each input method has a dedicated hook (`useBarcode`, `useVoiceInput`, `useTextInput`, `usePhoto`) that:
- Manages input state (active, processing, errors)
- Handles API calls to parse food
- Shows confirmation dialog with parsed data
- Saves confirmed entry to IndexedDB

### IndexedDB Key Schema (src/utils/idb.ts)
- `entry:{cuid}` - Individual food entries
- `offset:{YYYY-MM-DD}` - Daily calorie offsets (for exercise/adjustments)

### Environment Variables
Required: `OPENAI_API_KEY` - Used for food parsing and photo analysis

### Path Alias
`@/*` maps to `./src/*` for imports
