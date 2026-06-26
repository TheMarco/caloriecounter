import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { verifyDeviceToken } from "@/lib/attestToken";

// The website is the public marketing page plus the iOS app's API backend. The
// proxy routes (parse-food / parse-photo / barcode) require a short-lived bearer
// token that the app obtains via Apple App Attest (see /api/attest/*). The attest
// endpoints protect themselves (rate limit + attestation), and the marketing page
// and static assets are public — the matcher only runs middleware on /api/*.
export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Enrollment / token endpoints are reachable without a token.
  if (pathname.startsWith("/api/attest")) {
    return NextResponse.next();
  }

  // Everything else under /api requires a valid, unexpired device token.
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
  const verified = token ? await verifyDeviceToken(token) : null;
  if (!verified) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Hand the device id to the route via a header we control, overwriting any
  // client-supplied value so it can't be spoofed for per-device rate limiting.
  const headers = new Headers(request.headers);
  headers.set("x-device-id", verified.keyId);
  return NextResponse.next({ request: { headers } });
}

export const config = {
  // Only guard the API backend; the marketing page and static assets are public.
  matcher: ["/api/:path*"],
};
