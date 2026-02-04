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

export async function middleware(request: NextRequest) {
  // Get the pathname
  const pathname = request.nextUrl.pathname;

  // Public paths that don't require authentication
  const publicPaths = [
    '/landing',
    '/offline',      // PWA offline page
    '/api/auth',     // Login endpoint
    '/api/auth/check', // Auth check endpoint
  ];

  // Static assets and Next.js internals
  const isStaticAsset =
    pathname.startsWith('/_next/') ||
    pathname.startsWith('/icons/') ||
    pathname === '/manifest.json' ||
    pathname === '/sw.js' ||
    pathname.startsWith('/workbox-') ||
    pathname === '/favicon.ico';

  // Allow public paths and static assets
  if (publicPaths.includes(pathname) || isStaticAsset) {
    return NextResponse.next();
  }

  // Check for authentication cookie with signed token
  const authCookie = request.cookies.get('calorie-auth');
  const isAuthenticated = authCookie?.value ? await verifyAuthToken(authCookie.value) : false;

  // If authenticated and on landing page, redirect to main app
  if (isAuthenticated && pathname === '/landing') {
    return NextResponse.redirect(new URL('/', request.url));
  }

  // Block unauthenticated access to protected routes
  if (!isAuthenticated) {
    // Block API routes (except auth)
    if (pathname.startsWith('/api/')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Redirect pages to landing
    return NextResponse.redirect(new URL('/landing', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
