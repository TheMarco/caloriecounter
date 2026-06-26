import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const AUTH_SECRET = process.env.NEXTAUTH_SECRET || process.env.AUTH_SECRET || 'default-dev-secret-change-me';
const TOKEN_EXPIRY_HOURS = 24;

/**
 * Convert string to Uint8Array for Web Crypto
 */
function stringToUint8Array(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

/**
 * Convert hex string to Uint8Array
 */
function hexToUint8Array(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

/**
 * Convert Uint8Array to hex string
 */
function uint8ArrayToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Timing-safe comparison of two Uint8Arrays
 */
function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result === 0;
}

/**
 * Compute HMAC-SHA256 using Web Crypto API
 */
async function computeHmac(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    stringToUint8Array(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    stringToUint8Array(message)
  );

  return uint8ArrayToHex(new Uint8Array(signature));
}

/**
 * Verifies an authentication token in middleware
 */
async function verifyAuthToken(token: string): Promise<boolean> {
  if (!token || typeof token !== 'string') {
    return false;
  }

  const parts = token.split('.');
  if (parts.length !== 2) {
    return false;
  }

  const [timestamp, providedSignature] = parts;

  // Check if timestamp is valid
  const tokenTime = parseInt(timestamp, 10);
  if (isNaN(tokenTime)) {
    return false;
  }

  // Check expiration
  const expiryMs = TOKEN_EXPIRY_HOURS * 60 * 60 * 1000;
  if (Date.now() - tokenTime > expiryMs) {
    return false;
  }

  // Verify signature using timing-safe comparison
  try {
    const expectedSignature = await computeHmac(timestamp, AUTH_SECRET);
    const providedBytes = hexToUint8Array(providedSignature);
    const expectedBytes = hexToUint8Array(expectedSignature);

    return timingSafeEqual(providedBytes, expectedBytes);
  } catch {
    return false;
  }
}

// The website is now just the public marketing page plus the iOS app's API
// backend. The only thing that needs protecting is the OpenAI proxy
// (/api/parse-food, /api/parse-photo, /api/barcode/*). The iOS app authenticates
// by POSTing the shared password to /api/auth and replaying the signed
// `calorie-auth` cookie. Everything else — the landing page and its assets — is
// public, so the matcher below only runs middleware on /api/* paths.
export async function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;

  // Auth endpoints are public so a client can obtain / check the token.
  if (pathname.startsWith('/api/auth')) {
    return NextResponse.next();
  }

  // Every other API route requires the signed cookie.
  const authCookie = request.cookies.get('calorie-auth');
  const isAuthenticated = authCookie?.value ? await verifyAuthToken(authCookie.value) : false;

  if (!isAuthenticated) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  return NextResponse.next();
}

export const config = {
  // Only guard the API backend; the marketing page and static assets are public.
  matcher: ['/api/:path*'],
};
