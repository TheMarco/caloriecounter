import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { SessionProvider } from "@/components/providers/SessionProvider";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const SITE_TITLE = "Calorie Tracker — Private, AI-powered calorie tracking";
const SITE_DESC =
  "Log meals by voice, photo, barcode, or text. AI does the math; your food diary never leaves your iPhone. No account, no tracking. $5.99/mo with 10 logs free. Coming soon to the App Store.";

export const metadata: Metadata = {
  metadataBase: new URL("https://caloriecounter.ai-created.com"),
  title: SITE_TITLE,
  description: SITE_DESC,
  applicationName: "Calorie Tracker",
  manifest: "/manifest.json",
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
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Calorie Tracker",
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: "website",
    siteName: "Calorie Tracker",
    title: SITE_TITLE,
    description: SITE_DESC,
    images: [{ url: "/og.webp", width: 1200, height: 630, alt: "Calorie Tracker" }],
  },
  twitter: {
    card: "summary_large_image",
    title: SITE_TITLE,
    description: SITE_DESC,
    images: ["/og.webp"],
  },
};

export const viewport: Viewport = {
  themeColor: "#000000",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning style={{ backgroundColor: '#000000', color: '#ffffff' }}>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                // Set document element styles immediately
                document.documentElement.style.backgroundColor = '#000000';
                document.documentElement.style.color = '#ffffff';
                document.documentElement.classList.add('dark');

                // Function to set body styles
                function setBodyStyles() {
                  if (document.body) {
                    document.body.style.backgroundColor = '#000000';
                    document.body.style.color = '#ffffff';
                    document.body.classList.add('dark');
                  }
                }

                // Try to set body styles immediately if body exists
                setBodyStyles();

                // If body doesn't exist yet, wait for it
                if (!document.body) {
                  if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', setBodyStyles);
                  } else {
                    // DOM is already loaded, body should exist
                    setTimeout(setBodyStyles, 0);
                  }
                }
              })();
            `,
          }}
        />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased dark`}
        suppressHydrationWarning
        style={{ backgroundColor: '#000000', color: '#ffffff' }}
      >
        <SessionProvider>
          {children}
        </SessionProvider>
        {process.env.NODE_ENV === 'development' && (
          <script
            dangerouslySetInnerHTML={{
              __html: `
                if ('serviceWorker' in navigator) {
                  navigator.serviceWorker.getRegistrations().then(function(registrations) {
                    for(let registration of registrations) {
                      registration.unregister();
                    }
                  });
                }
              `,
            }}
          />
        )}
      </body>
    </html>
  );
}
