import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE_TITLE = "The Last Calorie Tracker — Private, AI-powered calorie tracking";
const SITE_DESC =
  "Log meals by voice, photo, barcode, or text. AI does the math; your food diary never leaves your iPhone. No account, no tracking. $5.99/mo with 10 logs free. Coming soon to the App Store.";

export const metadata: Metadata = {
  metadataBase: new URL("https://caloriecounter.ai-created.com"),
  title: SITE_TITLE,
  description: SITE_DESC,
  applicationName: "The Last Calorie Tracker",
  icons: {
    icon: [
      { url: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [
      { url: "/icons/apple-120.png", sizes: "120x120", type: "image/png" },
      { url: "/icons/apple-152.png", sizes: "152x152", type: "image/png" },
      { url: "/icons/apple-180.png", sizes: "180x180", type: "image/png" },
    ],
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: "website",
    siteName: "The Last Calorie Tracker",
    title: SITE_TITLE,
    description: SITE_DESC,
    images: [{ url: "/og.webp", width: 1200, height: 630, alt: "The Last Calorie Tracker" }],
  },
  twitter: {
    card: "summary_large_image",
    title: SITE_TITLE,
    description: SITE_DESC,
    images: ["/og.webp"],
  },
};

export const viewport: Viewport = {
  // Match the browser chrome to the active appearance. (System-driven; the
  // in-page toggle overrides the page colors but not this OS-level bar.)
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#0c0d10" },
    { media: "(prefers-color-scheme: light)", color: "#f4f5f7" },
  ],
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
        {/* Unregister any service worker left over from the retired PWA so
            returning visitors aren't served a stale cached app shell. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                navigator.serviceWorker.getRegistrations().then(function(registrations) {
                  for (let registration of registrations) { registration.unregister(); }
                });
              }
            `,
          }}
        />
      </body>
    </html>
  );
}
