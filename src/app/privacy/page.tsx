import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";

// The Last Calorie Tracker — Privacy Policy.
// Static server component, styled with the shared `.ct` design system. The content
// is grounded in what the iOS app and its API proxy actually do (App Attest auth,
// on-device storage, OpenAI/Open Food Facts lookups, opt-in Apple Health) — keep it
// accurate if that behavior changes.

const UPDATED = "June 26, 2026";
const CONTACT = "info@ai-created.com";

export const metadata: Metadata = {
  title: "Privacy Policy — The Last Calorie Tracker",
  description:
    "How The Last Calorie Tracker handles your data: no account, your food diary stays on your iPhone, and only the meal text or photo you submit is sent for AI analysis. No analytics, no tracking, no ads.",
  alternates: { canonical: "/privacy" },
  openGraph: {
    type: "article",
    title: "Privacy Policy — The Last Calorie Tracker",
    description:
      "No account. Your food diary stays on your iPhone. No analytics, no tracking, no ads.",
    images: [{ url: "/og.webp", width: 1200, height: 630, alt: "The Last Calorie Tracker" }],
  },
};

/* ───────────────────────────── helpers ───────────────────────────── */

function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return (
    <section id={id} className="scroll-mt-24 border-t border-white/5 pt-10">
      <h2 className="text-2xl font-bold tracking-tight text-white">{title}</h2>
      <div className="mt-4 space-y-4 text-[15px] leading-relaxed text-white/70">{children}</div>
    </section>
  );
}

function Em({ children }: { children: ReactNode }) {
  return <span className="font-semibold text-white/90">{children}</span>;
}

// Rows: [what, where it lives, leaves your device?]
const DATA_ROWS: [string, string, string][] = [
  ["Food log, corrections, weights, goals, settings", "On your iPhone (on-device database)", "No"],
  ["App-lock token (Face ID / Touch ID)", "iOS Keychain, device-only", "No"],
  ["Free-log counter", "Your private iCloud (your Apple ID)", "iCloud only — we can’t see it"],
  ["Food text you type", "Sent to our API → OpenAI to estimate nutrition", "Only the text you submit"],
  ["Meal photo", "Sent to our API → OpenAI to estimate nutrition", "Only the image you submit"],
  ["Your voice", "Transcribed on your iPhone; only the text is sent", "Audio never leaves"],
  ["Barcode", "Looked up via Open Food Facts", "The barcode number only"],
  ["Apple Health data", "Read/written locally via HealthKit", "Never to any server"],
];

/* ────────────────────────────── page ─────────────────────────────── */

export default function PrivacyPolicy() {
  return (
    <div className="ct min-h-screen w-full overflow-x-hidden antialiased">
      {/* ── Header ── */}
      <header className="sticky top-0 z-50 border-b border-white/5 bg-[#0c0d10]/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-5">
          <Link href="/" className="flex items-center gap-2.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/app-icon.webp" alt="" width={32} height={32} className="h-8 w-8 rounded-[9px]" />
            <span className="text-[15px] font-semibold tracking-tight">The Last Calorie Tracker</span>
          </Link>
          <Link href="/" className="text-sm text-white/65 transition hover:text-white">
            ← Back to site
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-5 py-16">
        {/* ── Title ── */}
        <p className="text-xs font-semibold uppercase tracking-wider text-[#73c2a1]">Privacy Policy</p>
        <h1 className="mt-3 text-4xl font-bold leading-tight tracking-tight sm:text-5xl">
          Your food diary is{" "}
          <span className="ct-grad">nobody’s business but yours.</span>
        </h1>
        <p className="mt-5 text-lg leading-relaxed text-white/70">
          The Last Calorie Tracker (“the app,” “we,” “us”) is built privacy-first. There is no account,
          and the diary you build stays on your iPhone. This page explains exactly what the app does and
          does not do with your information.
        </p>
        <p className="mt-3 text-sm text-white/45">Last updated: {UPDATED}</p>

        {/* ── The short version ── */}
        <div className="ct-card mt-10 p-6">
          <h2 className="text-base font-semibold text-white">The short version</h2>
          <ul className="mt-4 space-y-2.5 text-[15px] leading-relaxed text-white/70">
            {[
              "No account, no sign-up, no email, no password — and no user profile on our servers.",
              "Your food log, weights, goals, and settings live only on your device.",
              "Only the specific meal text or photo you submit is sent out, to turn it into calories and macros.",
              "Speech is transcribed on your iPhone — the audio never leaves it.",
              "Apple Health is fully optional and off until you turn it on; Health data never reaches our servers.",
              "No analytics SDKs, no advertising SDKs, no third-party trackers. We do not track you across apps or the web.",
            ].map((t) => (
              <li key={t} className="flex gap-3">
                <span className="mt-2 h-1.5 w-1.5 flex-none rounded-full bg-[#57b58c]" />
                <span>{t}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="mt-12 space-y-2">
          {/* ── Who we are ── */}
          <Section id="who" title="Who we are">
            <p>
              The Last Calorie Tracker is an iOS app published by <Em>Unthinking AI, LLC</Em>. If you have
              any question about this policy or your privacy, contact us at{" "}
              <a href={`mailto:${CONTACT}`} className="text-[#73c2a1] underline-offset-2 hover:underline">
                {CONTACT}
              </a>
              .
            </p>
          </Section>

          {/* ── No account ── */}
          <Section id="no-account" title="No account, ever">
            <p>
              You open the app and start tracking. We don’t ask for — and never collect — a name, email
              address, phone number, password, or any other identifier that would let us (or anyone) build a
              profile of you. There is nothing to log into, so there is no login to leak.
            </p>
          </Section>

          {/* ── On device ── */}
          <Section id="on-device" title="What stays on your device">
            <p>
              The substance of the app — your <Em>food log, your learned corrections, your weigh-ins, your
              calorie and macro goals, and your settings</Em> — is stored locally on your iPhone and is never
              uploaded to us. It is not stored in iCloud’s document or photo sync, and we operate no
              server-side database of your meals.
            </p>
            <p>
              The token that powers the optional Face ID / Touch ID app lock is kept in the iOS{" "}
              <Em>Keychain</Em>, device-only and non-syncing.
            </p>
            <p>
              One small exception is the <Em>free-log counter</Em> — the number of free entries you’ve used
              before subscribing. It is stored in your own private iCloud key-value storage so it follows
              your Apple ID across your devices and survives reinstalls. It is just a count; it contains none
              of your food data, it stays inside your iCloud, and we have no access to it. There is still no
              account with us.
            </p>
          </Section>

          {/* ── What leaves the device ── */}
          <Section id="leaves-device" title="What leaves your device — and only when you ask">
            <p>
              The app reaches the network only to do the thing you asked: turn a meal you logged into a
              nutrition estimate, or look up a barcode. Here is the complete picture:
            </p>
            <div className="mt-6 overflow-hidden rounded-2xl border border-white/10">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="bg-white/5 text-white/50">
                    <th className="px-4 py-3 font-medium">Data</th>
                    <th className="px-4 py-3 font-medium">Where it lives</th>
                    <th className="px-4 py-3 font-medium">Leaves device?</th>
                  </tr>
                </thead>
                <tbody>
                  {DATA_ROWS.map(([a, b, c]) => (
                    <tr key={a} className="border-t border-white/5 align-top">
                      <td className="px-4 py-3 text-white/85">{a}</td>
                      <td className="px-4 py-3 text-white/55">{b}</td>
                      <td className="px-4 py-3 text-[#73c2a1]">{c}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="mt-4">
              When you log a meal by text, voice, or photo, the app sends just that one submission — the
              short text snippet or the single image — to our server, which forwards it to OpenAI to estimate
              calories and macros. Nothing about your identity is attached, because we don’t have it. Your
              existing diary is never included.
            </p>
          </Section>

          {/* ── Voice & photos ── */}
          <Section id="voice-photos" title="Voice and photos, specifically">
            <p>
              <Em>Voice:</Em> when you speak a meal, the audio is transcribed <Em>on your iPhone</Em> using
              Apple’s on-device speech recognition. The audio recording never leaves your device — only the
              resulting text is sent for analysis.
            </p>
            <p>
              <Em>Photos:</Em> when you log by photo, the app sends the single image you captured for that
              meal (downsized to a small square) to be analyzed. We do not access your photo library, and we
              don’t receive any other images, location data, or photo metadata.
            </p>
          </Section>

          {/* ── Apple Health ── */}
          <Section id="health" title="Apple Health">
            <p>
              Apple Health integration is entirely <Em>optional and off by default</Em>, behind separate
              toggles you control. When you turn it on, the app reads and writes Health data{" "}
              <Em>locally on your device</Em> through Apple’s HealthKit. Health data is{" "}
              <Em>never sent to any server</Em> — not ours, not OpenAI’s.
            </p>
            <p>
              Everything the app writes carries its own source marker, so it’s clearly identifiable and never
              touches other apps’ data. You can disconnect at any time, and you can remove the data the app
              wrote to Health from within the app’s settings.
            </p>
          </Section>

          {/* ── Talking to our server ── */}
          <Section id="server" title="How the app talks to our server">
            <p>
              Food parsing runs through a small server (our “API proxy”) so that the OpenAI key is held
              securely on the server and never shipped inside the app. To keep that proxy from being abused
              and running up costs, the app proves it is a genuine, unmodified copy of our app running on a
              real Apple device using <Em>Apple’s App Attest</Em>.
            </p>
            <p>
              For this, we store an <Em>anonymous, per-install device key</Em> generated by your device’s
              Secure Enclave (a public key, a signature counter, and a random key identifier). This is a
              hardware credential, <Em>not a user identity</Em>: it is not your Apple ID, it isn’t linked to
              your name or contact details, and it carries none of your food data. We use it only to issue
              short-lived access tokens and to enforce fair-use rate limits.
            </p>
            <p>
              Like any internet service, our server and hosting provider process your device’s{" "}
              <Em>IP address</Em> momentarily to deliver each request and to rate-limit abuse. We do not use
              it to build a profile of you or sell it to anyone.
            </p>
          </Section>

          {/* ── Third parties ── */}
          <Section id="third-parties" title="The third parties involved">
            <p>We rely on a few well-known services, and only for the narrow purposes below:</p>
            <ul className="space-y-3">
              <li>
                <Em>OpenAI</Em> — receives the meal text or image you submit, to estimate its nutrition. No
                name, account, or contact information is attached. Under OpenAI’s API terms, data sent through
                the API is <Em>not used to train their models</Em>; OpenAI may retain a submission briefly for
                abuse monitoring under its own policies.
              </li>
              <li>
                <Em>Open Food Facts</Em> — receives a barcode number you scan, to look up the product. Only
                the number is sent.
              </li>
              <li>
                <Em>Apple</Em> — provides App Attest (anti-abuse), the App Store and StoreKit (subscriptions),
                iCloud (your private free-log counter), and HealthKit. Your use of these is governed by
                Apple’s own privacy policy.
              </li>
              <li>
                <Em>Vercel</Em> — hosts our marketing site and API proxy, and processes requests (including IP
                addresses) on our behalf to operate the service.
              </li>
            </ul>
            <p>
              We do not sell or rent your data, and we have no advertising partners or data brokers.
            </p>
          </Section>

          {/* ── Subscriptions ── */}
          <Section id="payments" title="Subscriptions and payments">
            <p>
              Subscriptions are handled entirely by <Em>Apple</Em> through the App Store and StoreKit. We
              never see or receive your payment card, billing address, or Apple ID. Whether you’re subscribed
              is checked on your device against your App Store purchase — there is no payment account on our
              side.
            </p>
          </Section>

          {/* ── No tracking ── */}
          <Section id="no-tracking" title="No analytics, no tracking, no ads">
            <p>
              The app contains <Em>no analytics SDKs, no advertising SDKs, and no third-party trackers</Em>.
              We don’t use the advertising identifier (IDFA), we don’t track you across other apps or
              websites, and we don’t build an advertising profile. In Apple’s App Privacy terms, we do not
              “track” you.
            </p>
          </Section>

          {/* ── Retention & deletion ── */}
          <Section id="retention" title="Keeping and deleting your data">
            <p>
              Because your diary lives on your device, <Em>you</Em> control it. You can export a full CSV of
              your entries from Settings, and deleting the app removes its on-device data from your iPhone.
              Data the app wrote to Apple Health can be removed from within the app; your iCloud free-log
              counter is governed by your Apple ID and iCloud settings.
            </p>
            <p>
              On our side, there is no diary to delete: we don’t keep a copy of your food log, photos, or the
              text you submit. A submission is processed in real time to return an estimate and is not saved
              into any profile. Routine, short-lived operational logs (for security and reliability) may
              briefly include technical request data such as timestamps and IP address; they are rotated
              automatically and are not used to identify or profile you.
            </p>
          </Section>

          {/* ── Children ── */}
          <Section id="children" title="Children">
            <p>
              The app is intended for a general audience and is not directed to children under 13 (or the
              equivalent minimum age in your country). We do not knowingly collect personal information from
              children.
            </p>
          </Section>

          {/* ── Your rights ── */}
          <Section id="rights" title="Your choices and rights">
            <p>
              Depending on where you live, you may have rights under laws such as the GDPR or CCPA to access,
              correct, or delete personal data, or to object to its processing. Because we operate without
              accounts and don’t hold a profile tied to your identity, in practice your data is already in
              your hands: it’s on your device, you can export it, and you can delete it by removing the app.
              If you still have a request or question, email us at{" "}
              <a href={`mailto:${CONTACT}`} className="text-[#73c2a1] underline-offset-2 hover:underline">
                {CONTACT}
              </a>{" "}
              and we’ll help.
            </p>
          </Section>

          {/* ── International ── */}
          <Section id="international" title="Where processing happens">
            <p>
              The app is operated from, and the meal submissions you send are processed in, the United States
              by us and our service providers (such as OpenAI and Vercel). If you use the app from outside the
              United States, you understand that the limited data described above is processed there.
            </p>
          </Section>

          {/* ── Changes ── */}
          <Section id="changes" title="Changes to this policy">
            <p>
              If we change how the app handles your information, we’ll update this page and revise the “last
              updated” date above. Material changes will be reflected here before they take effect.
            </p>
          </Section>

          {/* ── Contact ── */}
          <Section id="contact" title="Contact us">
            <p>
              Questions about your privacy or this policy? Email{" "}
              <a href={`mailto:${CONTACT}`} className="text-[#73c2a1] underline-offset-2 hover:underline">
                {CONTACT}
              </a>
              . We read every message.
            </p>
          </Section>
        </div>
      </main>

      {/* ── Footer ── */}
      <footer className="border-t border-white/5">
        <div className="mx-auto max-w-3xl px-5 py-10">
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-center">
            <Link href="/" className="flex items-center gap-2.5">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/app-icon.webp" alt="" width={28} height={28} className="h-7 w-7 rounded-lg" />
              <span className="font-semibold">The Last Calorie Tracker</span>
            </Link>
            <p className="text-xs text-white/40">© 2026 Unthinking AI, LLC. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
