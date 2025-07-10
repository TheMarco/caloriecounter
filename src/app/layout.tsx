import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { SessionProvider } from "@/components/providers/SessionProvider";
import { PWAInstallBanner } from "@/components/PWAInstallBanner";
import { OfflineIndicator } from "@/components/OfflineIndicator";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Calorie Counter",
  description: "Lightning-fast calorie tracking PWA with barcode scanning and voice input",
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
    statusBarStyle: "default",
    title: "Calorie Counter",
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: "website",
    siteName: "Calorie Counter",
    title: "Calorie Counter",
    description: "Lightning-fast calorie tracking PWA with barcode scanning and voice input",
  },
  twitter: {
    card: "summary",
    title: "Calorie Counter",
    description: "Lightning-fast calorie tracking PWA with barcode scanning and voice input",
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
          <PWAInstallBanner />
          <OfflineIndicator />
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
