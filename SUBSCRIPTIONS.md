# Subscription Implementation Guide

This document outlines the approach for turning the Calorie Counter PWA into a subscription-based iOS app.

## Distribution Options

### Option 1: Keep as PWA (Simplest)
- Use a web-based payment provider (Stripe, Paddle, LemonSqueezy)
- No App Store fees (saves 15-30%)
- Limitations: iOS PWA has no push notifications (before iOS 16.4), limited background sync
- Users install via Safari "Add to Home Screen"

### Option 2: Native iOS App (Full App Store)
- Wrap in a native shell or rebuild in Swift/React Native
- **Required**: Use Apple's StoreKit for subscriptions (Apple takes 15-30%)
- Full iOS capabilities (push notifications, widgets, HealthKit integration)
- App Store review process

### Option 3: PWA Wrapped via Capacitor/Expo
- Keep existing Next.js codebase, wrap with Capacitor or Expo
- Can submit to App Store
- Still must use StoreKit for subscriptions if distributed via App Store

---

## Why Server-Side Verification is Needed

The app's expensive operations happen server-side:

```
User's Phone → Next.js API Routes → OpenAI API (costs money)
```

StoreKit runs on the client (iPhone). Without server-side verification, anyone could call API endpoints directly without paying:

```bash
curl -X POST https://yourapp.com/api/parse-food -d '{"text": "chicken sandwich"}'
```

The server must verify subscription status before making OpenAI API calls.

---

## Stateless JWT Solution (No Database Required)

### How It Works

```
1. User buys subscription (StoreKit on device)
2. App sends Apple receipt to your server
3. Server validates receipt with Apple, creates signed JWT with expiry date
4. Client stores JWT, sends with every API request
5. Server verifies JWT signature + checks expiry - no database lookup needed
```

### Implementation

#### 1. Token Verification Endpoint

```typescript
// src/app/api/verify-subscription/route.ts
import { SignJWT } from 'jose';

const SECRET = new TextEncoder().encode(process.env.JWT_SECRET);

export async function POST(request: Request) {
  const { receiptData, deviceId } = await request.json();

  // Validate receipt with Apple
  const appleResponse = await fetch(
    'https://buy.itunes.apple.com/verifyReceipt',
    {
      method: 'POST',
      body: JSON.stringify({
        'receipt-data': receiptData,
        password: process.env.APPLE_SHARED_SECRET,
      }),
    }
  );

  const result = await appleResponse.json();

  if (result.status !== 0) {
    return Response.json({ error: 'Invalid receipt' }, { status: 403 });
  }

  // Find the latest subscription expiry
  const latestReceipt = result.latest_receipt_info?.[0];
  const expiresAt = parseInt(latestReceipt.expires_date_ms);

  // Create signed JWT
  const token = await new SignJWT({
    deviceId,
    plan: 'premium',
    expiresAt,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresAt / 1000)
    .sign(SECRET);

  return Response.json({ token });
}
```

#### 2. Subscription Verification Helper

```typescript
// src/lib/auth.ts
import { jwtVerify } from 'jose';

const SECRET = new TextEncoder().encode(process.env.JWT_SECRET);

export async function verifySubscription(request: Request) {
  const token = request.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) return { valid: false, reason: 'No token' };

  try {
    const { payload } = await jwtVerify(token, SECRET);

    if (Date.now() > payload.expiresAt) {
      return { valid: false, reason: 'Subscription expired' };
    }

    return { valid: true, plan: payload.plan };
  } catch {
    return { valid: false, reason: 'Invalid token' };
  }
}
```

#### 3. Gate Expensive API Endpoints

```typescript
// src/app/api/parse-food/route.ts
import { verifySubscription } from '@/lib/auth';

export async function POST(request: Request) {
  const sub = await verifySubscription(request);

  if (!sub.valid) {
    return Response.json(
      { error: 'Premium subscription required' },
      { status: 403 }
    );
  }

  // ... existing OpenAI parsing code
}
```

#### 4. Client Sends Token With Requests

```typescript
// src/utils/api.ts
const postFetcher = async (url: string, data: unknown) => {
  const token = localStorage.getItem('subscriptionToken');

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token && { 'Authorization': `Bearer ${token}` }),
    },
    body: JSON.stringify(data),
  });

  return res.json();
};
```

### JWT Solution Trade-offs

| Pros | Cons |
|------|------|
| No database needed | Can't revoke mid-subscription (refunds) |
| Very fast verification | Must refresh token on renewal |
| Stateless, scales infinitely | Slight complexity on client |
| Free (no DB hosting costs) | Token could be shared between devices |

### Handling Refunds

If someone gets a refund, their JWT is still valid until expiry. Mitigations:

1. **Short-lived tokens** (7 days) + refresh flow
2. **Accept the risk** - refund abuse is rare and Apple tracks abusers
3. **Hybrid approach**: Keep a small "revoked tokens" list (minimal DB)

### Token Refresh Strategy

For monthly subscriptions:
- Issue JWTs that expire in 35 days (subscription period + grace period)
- On app launch, if token expires within 7 days, re-validate with Apple
- If validation fails (cancelled/refunded), token isn't refreshed

---

## Alternative: Database Solution

If you need more control (cross-device sync, refund handling, analytics):

### Recommended Stack
- **Supabase** or **Firebase** for auth + database
- Minimal schema required

### Database Schema

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  device_id TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Subscriptions table
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  status TEXT, -- 'active', 'cancelled', 'expired'
  plan TEXT,   -- 'monthly', 'yearly'
  expires_at TIMESTAMP,
  apple_transaction_id TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Feature Gating Recommendations

| Free Tier | Premium |
|-----------|---------|
| Manual text entry (no AI) | AI food parsing (voice/text) |
| Basic calorie tracking | Photo analysis |
| 7-day history | Full history + charts |
| | Barcode scanning |
| | Data export (CSV) |
| | Cloud sync across devices |

The AI-powered features are natural paywall candidates since they incur per-call API costs (OpenAI).

---

## Environment Variables Needed

```bash
# Existing
OPENAI_API_KEY=sk-...

# New for subscriptions
JWT_SECRET=your-256-bit-secret-key
APPLE_SHARED_SECRET=your-app-store-connect-shared-secret
```

---

## Implementation Order

1. Add JWT verification infrastructure (`jose` package)
2. Create `/api/verify-subscription` endpoint
3. Add `verifySubscription()` checks to expensive API routes
4. Update client API calls to include Authorization header
5. Implement StoreKit integration in iOS wrapper (Capacitor)
6. Add token storage and refresh logic on client
7. Create free tier fallback for non-premium users

---

## Dependencies to Add

```bash
npm install jose  # For JWT signing/verification
```

For Capacitor (iOS wrapper):
```bash
npm install @capacitor/core @capacitor/ios
npx cap init
```

---

## Apple App Store Connect Setup

1. Create app in App Store Connect
2. Configure subscription products (monthly/yearly)
3. Generate Shared Secret for receipt validation
4. Set up Subscription Groups
5. Configure pricing for each territory

---

## Resources

- [Apple StoreKit 2 Documentation](https://developer.apple.com/storekit/)
- [Capacitor In-App Purchases Plugin](https://github.com/capacitor-community/in-app-purchases)
- [Apple Receipt Validation](https://developer.apple.com/documentation/appstorereceipts)
- [jose (JWT library)](https://github.com/panva/jose)
