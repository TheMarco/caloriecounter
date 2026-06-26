import type { NextConfig } from "next";

// The web project is now just the marketing landing page plus the iOS app's
// API backend. The former PWA (next-pwa / service worker / offline shell) has
// been retired, so this config is intentionally minimal.
const nextConfig: NextConfig = {
  skipTrailingSlashRedirect: true,
};

export default nextConfig;
