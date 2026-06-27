/* eslint-disable @next/next/no-img-element */
//
// The Last Calorie Tracker — marketing landing page.
// A static, SEO-friendly server component styled to match the iOS app. It
// adapts to light/dark: colors come from CSS tokens (see globals.css) that
// follow the visitor's system setting by default and the header toggle when
// used. Text shades are `var(--ink)` at an opacity; surfaces are
// `var(--app)` / `var(--surface)` — never hardcoded white/black — so a single
// markup tree renders correctly in both appearances.
//

import type { ReactNode } from "react";
import { ThemeToggle } from "./ThemeToggle";

const SHOT = "/screenshots/app";
const W = 720;
const H = 1564;

// Light-appearance screenshots live alongside the dark ones with the SAME
// filenames, under /screenshots/white/ instead of /screenshots/app/. When true,
// each PhoneShot emits both variants and CSS swaps them to follow the toggle +
// system setting (see `.ct-phone img.shot-*` in globals.css). Set to false if the
// light set is ever removed, and every shot falls back to its dark variant.
const LIGHT_SHOTS_READY = true;
const SHOT_LIGHT = "/screenshots/white";

/* ────────────────────────────── icons ────────────────────────────── */

type IconProps = { className?: string };
const I = ({ d, className }: { d: string; className?: string }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}
    strokeLinecap="round" strokeLinejoin="round" className={className ?? "h-6 w-6"} aria-hidden>
    <path d={d} />
  </svg>
);
const Mic = (p: IconProps) => <I {...p} d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3ZM5 11a7 7 0 0 0 14 0M12 18v3" />;
const Camera = (p: IconProps) => <I {...p} d="M3 8a2 2 0 0 1 2-2h2l1.2-1.6A1 1 0 0 1 11 4h2a1 1 0 0 1 .8.4L15 6h4a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8Zm9 3a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Z" />;
const Barcode = (p: IconProps) => <I {...p} d="M3 5v14M7 5v14M11 5v10M11 18v1M15 5v14M19 5v14" />;
const Keyboard = (p: IconProps) => <I {...p} d="M4 7h16a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1Zm3 3h.01M11 10h.01M15 10h.01M8 14h8" />;
const Sparkle = (p: IconProps) => <I {...p} d="M12 3l1.8 4.7L18.5 9.5 13.8 11.3 12 16l-1.8-4.7L5.5 9.5l4.7-1.8L12 3ZM19 14l.7 1.8L21.5 16.5 19.7 17.2 19 19l-.7-1.8L16.5 16.5l1.8-.7L19 14Z" />;
const Lock = (p: IconProps) => <I {...p} d="M6 10V8a6 6 0 0 1 12 0v2m-13 0h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1Zm7 4v3" />;
const ShieldIcon = (p: IconProps) => <I {...p} d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3Zm-3 9 2 2 4-4" />;
const PhoneIcon = (p: IconProps) => <I {...p} d="M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Zm3 15h2" />;
const Chart = (p: IconProps) => <I {...p} d="M4 20V4m0 16h16M8 16v-5m4 5V8m4 8v-3" />;
const Heart = (p: IconProps) => <I {...p} d="M12 20s-7-4.4-9.2-8.5C1.3 8.6 2.7 5.5 6 5.5c2 0 3.2 1.2 4 2.3.8-1.1 2-2.3 4-2.3 3.3 0 4.7 3.1 3.2 6C19 15.6 12 20 12 20Z" />;
const Check = (p: IconProps) => <I {...p} d="M5 12.5 10 17.5 19 7" />;
const Bolt = (p: IconProps) => <I {...p} d="M13 3 4 14h7l-1 7 9-11h-7l1-7Z" />;
const Apple = ({ className }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className ?? "h-6 w-6"} aria-hidden>
    <path d="M16.4 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.8-.8-3-.8-1.5 0-2.9.9-3.7 2.3-1.6 2.7-.4 6.8 1.1 9 .8 1.1 1.6 2.3 2.8 2.2 1.1 0 1.6-.7 2.9-.7 1.3 0 1.8.7 3 .7 1.2 0 2-1.1 2.7-2.2.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.7ZM14.3 5.8c.6-.8 1-1.8.9-2.8-.9 0-2 .6-2.6 1.3-.6.7-1.1 1.7-.9 2.7 1 0 2-.5 2.6-1.2Z" />
  </svg>
);

/* ────────────────────────────── data ─────────────────────────────── */

const PILLARS = [
  { icon: PhoneIcon, color: "#57b58c", title: "On-device", body: "Your food log, weights, and targets live on your iPhone — not a server." },
  { icon: Lock, color: "#cc7c8c", title: "No account, ever", body: "Open the app and start. No sign-up, no email, no password to forget." },
  { icon: Sparkle, color: "#6e9ac8", title: "AI-powered", body: "Describe or photograph a meal — AI turns it into calories and macros in seconds." },
  { icon: ShieldIcon, color: "#cfa85c", title: "Zero tracking", body: "No analytics identity, no ad SDKs, no profile. Nobody is logging what you eat." },
];

const CAPTURE = [
  { icon: Barcode, color: "#8a86f0", title: "Scan", body: "Point at a barcode — nutrition comes straight from Open Food Facts, per-serving when the label has it." },
  { icon: Mic, color: "#e0594f", title: "Speak", body: "Say “a peanut butter and jelly sandwich.” Speech is transcribed on-device; only the text is parsed." },
  { icon: Keyboard, color: "#6e9ac8", title: "Type", body: "Jot down what you ate. Autocomplete reuses foods you’ve logged before, no cloud call needed." },
  { icon: Camera, color: "#cfa85c", title: "Photo", body: "Snap the plate. A vision model breaks it into editable items — chicken, rice, veggies." },
];

const PRIVACY_ROWS = [
  ["Food log, weights, targets, settings", "On your device", "Never"],
  ["Biometric-lock token", "Keychain (device-only)", "Never"],
  ["Food text or photo you submit", "Sent to AI to parse", "Only what you submit"],
  ["Your voice", "Transcribed on-device", "Audio never leaves"],
  ["Barcodes", "Open Food Facts lookup", "The number only"],
  ["Apple Health data", "Read/written locally", "Never to any server"],
];

// Monthly price signal, sorted high → low; The Last Calorie Tracker highlighted at the bottom.
const COMPARISON = [
  { app: "MyFitnessPal Premium+", price: 24.99, label: "$24.99/mo", verdict: "Dramatically cheaper" },
  { app: "SnapCal", price: 15.99, label: "$14.99–$16.99/mo", verdict: "Much cheaper" },
  { app: "Cronometer Gold", price: 10.99, label: "$10.99/mo", verdict: "Much cheaper" },
  { app: "Cal AI", price: 9.99, label: "~$9.99/mo", verdict: "Beats the common price" },
  { app: "Lose It Premium", price: 9.99, label: "~$9.99/mo", verdict: "Cheaper monthly" },
  { app: "YAZIO Pro", price: 6.99, label: "~$6.99/mo", verdict: "Slightly cheaper" },
  { app: "The Last Calorie Tracker", price: 5.99, label: "$5.99/mo", verdict: "Best value", self: true },
];
const MAX_PRICE = 24.99;

const FAQ = [
  { q: "Do I need to create an account?", a: "No. There’s no sign-up, no email, and no password. You open the app and start logging — your data is yours, on your device." },
  { q: "It’s AI-powered — is my data being used to train models?", a: "Only the text or photo you submit for a single meal is sent to be parsed, with no name, account, or device ID attached. Under the AI provider’s API terms, that data isn’t used to train their models. Your diary itself is never uploaded." },
  { q: "What happens after my 10 free logs?", a: "Logging continues with The Last Calorie Tracker Pro — $5.99/month or $29.99/year. Everything you already logged stays, and you can browse it freely." },
  { q: "Does it work with Apple Health?", a: "Yes, optionally. You can sync meals, macros, and weigh-ins, import existing weight, and have finished workouts offered as a calorie offset — all opt-in and off until you turn it on." },
  { q: "Can I get my data out?", a: "Anytime. Export a full CSV of every entry, offset, and weigh-in from Settings, and import it back on a new device. No lock-in." },
];

/* ───────────────────────────── helpers ───────────────────────────── */

function PhoneShot({ src, alt, className = "", eager = false }: { src: string; alt: string; className?: string; eager?: boolean }) {
  const loading = eager ? "eager" : "lazy";
  const lightSrc = LIGHT_SHOTS_READY ? src.replace(SHOT, SHOT_LIGHT) : null;
  return (
    <div className={`ct-phone ${className}`}>
      <img className={lightSrc ? "shot-dark" : undefined} src={src} alt={alt} width={W} height={H} loading={loading} decoding="async" />
      {lightSrc && (
        <img className="shot-light" src={lightSrc} alt={alt} width={W} height={H} loading={loading} decoding="async" />
      )}
    </div>
  );
}

/* Lifestyle / food photography. Same dark↔light swap as PhoneShot: each photo has a
   dark (/lifestyle) and light (/lifestyle/white) variant under the SAME filename;
   CSS shows whichever matches the appearance (see `.ct-pic img.shot-*` in globals.css). */
const PIC = "/lifestyle";
const PIC_LIGHT = "/lifestyle/white";

function Pic({ src, alt, className = "" }: { src: string; alt: string; className?: string }) {
  return (
    <figure className={`ct-pic ${className}`}>
      <img className="shot-dark" src={src} alt={alt} width={1448} height={1086} loading="lazy" decoding="async" />
      <img className="shot-light" src={src.replace(PIC, PIC_LIGHT)} alt={alt} width={1448} height={1086} loading="lazy" decoding="async" />
    </figure>
  );
}

function ComingSoonBadge({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-3 rounded-2xl border border-white/15 bg-black px-5 py-3 ${className}`}>
      <Apple className="h-7 w-7 text-white" />
      <span className="text-left leading-tight">
        <span className="block text-[11px] uppercase tracking-wider text-white/55">Coming soon</span>
        <span className="block text-base font-semibold text-white">App Store</span>
      </span>
    </span>
  );
}

function SectionTag({ children }: { children: ReactNode }) {
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-[#57b58c]/30 bg-[#57b58c]/10 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-[var(--accent-ink)]">
      {children}
    </span>
  );
}

/* ────────────────────────────── page ─────────────────────────────── */

export default function Home() {
  return (
    <div className="ct min-h-screen w-full overflow-x-hidden antialiased">
      {/* ── Header ── */}
      <header className="sticky top-0 z-50 border-b border-[var(--ink)]/5 bg-[var(--app)]/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5">
          <a href="#top" className="flex items-center gap-2.5">
            <img src="/app-icon.webp" alt="" width={32} height={32} className="h-8 w-8 rounded-[9px]" />
            <span className="text-[15px] font-semibold tracking-tight">The Last Calorie Tracker</span>
          </a>
          <nav className="hidden items-center gap-7 text-sm text-[var(--ink)]/65 md:flex">
            <a href="#features" className="transition hover:text-[var(--ink)]">Features</a>
            <a href="#privacy" className="transition hover:text-[var(--ink)]">Privacy</a>
            <a href="#pricing" className="transition hover:text-[var(--ink)]">Pricing</a>
            <a href="#value" className="transition hover:text-[var(--ink)]">Value</a>
          </nav>
          <div className="flex items-center gap-2.5">
            <ThemeToggle />
            <a href="#pricing" className="rounded-full bg-[#57b58c] px-4 py-2 text-sm font-semibold text-[#06140d] transition hover:bg-[#73c2a1]">
              Coming soon
            </a>
          </div>
        </div>
      </header>

      {/* ── Hero ── */}
      <section id="top" className="relative overflow-hidden">
        <img src="/hero-food.webp" alt="" aria-hidden width={1400} height={2488}
          className="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-40" />
        <div className="absolute inset-0 bg-gradient-to-b from-[var(--app)]/70 via-[var(--app)]/85 to-[var(--app)]" />
        <div className="ct-glow pointer-events-none absolute -top-24 left-1/2 h-[420px] w-[620px] -translate-x-1/2 opacity-60" />

        <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-5 pb-16 pt-16 md:grid-cols-2 md:pb-24 md:pt-24">
          <div className="ct-rise">
            <span className="inline-flex items-center gap-2 rounded-full border border-[var(--ink)]/15 bg-[var(--ink)]/5 px-3 py-1.5 text-xs font-medium text-[var(--ink)]/75">
              <span className="h-1.5 w-1.5 rounded-full bg-[#57b58c]" /> Coming soon to the App Store
            </span>
            <h1 className="mt-5 text-[2.6rem] font-bold leading-[1.05] tracking-tight sm:text-6xl">
              Track what you eat.<br />
              <span className="ct-grad">Keep it to yourself.</span>
            </h1>
            <p className="mt-5 max-w-md text-lg leading-relaxed text-[var(--ink)]/70">
              The Last Calorie Tracker logs meals by voice, photo, barcode, or text — and AI does the math in
              seconds. No account. No analytics. Your food diary never leaves your iPhone.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-4">
              <ComingSoonBadge />
              <a href="#features" className="rounded-2xl border border-[var(--ink)]/15 px-5 py-3.5 text-sm font-semibold text-[var(--ink)]/90 transition hover:bg-[var(--ink)]/5">
                See how it works
              </a>
            </div>
            <p className="mt-5 text-sm text-[var(--ink)]/45">
              On-device · No account · <span className="text-[var(--ink)]/70">$5.99/mo</span> · 10 logs free · Cancel anytime
            </p>
          </div>

          <div className="relative ct-rise" style={{ animationDelay: "0.12s" }}>
            <div className="ct-glow pointer-events-none absolute inset-x-10 top-10 h-72 opacity-50" />
            <div className="relative mx-auto flex max-w-md items-end justify-center gap-4">
              <PhoneShot src={`${SHOT}/app-09.webp`} alt="Confirming an AI-estimated meal" eager
                className="ct-float w-[42%] translate-y-6 opacity-90" />
              <PhoneShot src={`${SHOT}/app-01.webp`} alt="The Last Calorie Tracker Today dashboard with calorie and macro rings" eager
                className="w-[58%]" />
            </div>
          </div>
        </div>
      </section>

      {/* ── Pillars ── */}
      <section className="mx-auto max-w-6xl px-5 py-14">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {PILLARS.map(({ icon: Icon, color, title, body }) => (
            <div key={title} className="ct-card p-6">
              <span className="flex h-11 w-11 items-center justify-center rounded-2xl" style={{ background: `${color}1f`, color }}>
                <Icon className="h-6 w-6" />
              </span>
              <h3 className="mt-4 text-base font-semibold">{title}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-[var(--ink)]/55">{body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Lifestyle gallery ── */}
      <section className="border-y border-[var(--ink)]/5 bg-[var(--surface-2)]">
        <div className="mx-auto max-w-6xl px-5 py-16 md:py-20">
          <div className="max-w-2xl">
            <SectionTag><Heart className="h-3.5 w-3.5" /> Made for real life</SectionTag>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Track the food you actually eat.</h2>
            <p className="mt-4 text-[var(--ink)]/65">
              From a salmon bowl to a post-gym shake — log it in seconds and get on with your day. No guilt,
              no performance, no audience. Just your real meals, kept to yourself.
            </p>
          </div>

          <div className="mt-10 grid grid-cols-2 gap-3 sm:gap-4">
            <Pic src={`${PIC}/i4.webp`} alt="Checking the day’s calories in The Last Calorie Tracker over a healthy bowl" />
            <Pic src={`${PIC}/i1.webp`} alt="A grilled salmon bowl with avocado, quinoa and greens" />
          </div>
          <div className="mt-3 grid grid-cols-3 gap-3 sm:mt-4 sm:gap-4">
            <Pic src={`${PIC}/i2.webp`} alt="Grilled chicken with roasted sweet potato, asparagus and quinoa" />
            <Pic src={`${PIC}/i3.webp`} alt="A falafel and hummus bowl with quinoa, cucumber and pickled onion" />
            <Pic src={`${PIC}/i5.webp`} alt="Taking a breather after a workout at the gym" />
          </div>
        </div>
      </section>

      {/* ── Capture: four ways ── */}
      <section id="features" className="mx-auto max-w-6xl scroll-mt-20 px-5 py-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div className="order-2 lg:order-1">
            <SectionTag><Bolt className="h-3.5 w-3.5" /> Effortless logging</SectionTag>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Log a meal in seconds — four ways.</h2>
            <p className="mt-4 max-w-md text-[var(--ink)]/65">
              Tap the green <span className="font-semibold text-[var(--accent-ink)]">+</span> and pick whatever’s fastest.
              Every method ends on the same confirm-and-adjust screen, so nothing is saved until you say so.
            </p>
            <div className="mt-8 grid gap-4 sm:grid-cols-2">
              {CAPTURE.map(({ icon: Icon, color, title, body }) => (
                <div key={title} className="ct-card p-5">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl" style={{ background: `${color}24`, color }}>
                    <Icon className="h-5 w-5" />
                  </span>
                  <h3 className="mt-3 font-semibold">{title}</h3>
                  <p className="mt-1 text-sm leading-relaxed text-[var(--ink)]/55">{body}</p>
                </div>
              ))}
            </div>
          </div>
          <div className="order-1 flex justify-center gap-4 lg:order-2">
            <PhoneShot src={`${SHOT}/app-07.webp`} alt="The capture dock with Scan, Speak, Type and Photo" className="w-1/2 max-w-[230px]" />
            <PhoneShot src={`${SHOT}/app-08.webp`} alt="Speaking a meal to log it by voice" className="mt-10 w-1/2 max-w-[230px]" />
          </div>
        </div>
      </section>

      {/* ── AI parsing ── */}
      <section className="border-y border-[var(--ink)]/5 bg-[var(--surface-2)]">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-5 py-16 lg:grid-cols-2">
          <div className="flex justify-center">
            <PhoneShot src={`${SHOT}/app-09.webp`} alt="AI estimate for a sandwich with adjustable macros" className="w-full max-w-[300px]" />
          </div>
          <div>
            <SectionTag><Sparkle className="h-3.5 w-3.5" /> Smart, not preachy</SectionTag>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">AI reads your meal. You stay in control.</h2>
            <ul className="mt-6 space-y-4">
              {[
                ["Estimates, not judgment", "Numbers are presented as guides — no “good,” “bad,” “cheat,” or “fail” language, anywhere."],
                ["One-tap adjustments", "Nudge any result with ½, 2×, Less, More, or swap the unit. Multi-item plates split into ingredients."],
                ["It learns your corrections", "Fix an estimate once and The Last Calorie Tracker remembers your numbers for next time — stored on your device."],
                ["Barcodes are measured data", "Packaged foods use real label values, with an on-device “Verify with label” scan to make them stick."],
              ].map(([t, b]) => (
                <li key={t} className="flex gap-3">
                  <span className="mt-0.5 flex h-6 w-6 flex-none items-center justify-center rounded-full bg-[#57b58c]/15 text-[var(--accent-ink)]">
                    <Check className="h-4 w-4" />
                  </span>
                  <span><span className="font-semibold">{t}.</span> <span className="text-[var(--ink)]/60">{b}</span></span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* ── Today + History ── */}
      <section className="mx-auto max-w-6xl px-5 py-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div className="order-2 lg:order-1">
            <SectionTag><Chart className="h-3.5 w-3.5" /> Your day, your trends</SectionTag>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">The whole day at a glance — then the bigger picture.</h2>
            <p className="mt-4 max-w-md text-[var(--ink)]/65">
              A hero ring shows net calories against your goal, with protein, carbs, and fat tracked
              alongside. History turns weeks of logs into plain, honest insights — no streaks, scores,
              or guilt trips.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-2">
              {([
                [Heart, "#cc7c8c", "Net-calorie & macro rings"],
                [Bolt, "#cfa85c", "Exercise & workout offsets"],
                [Chart, "#6e9ac8", "Calorie, macro & weight trends"],
                [Check, "#57b58c", "Re-log your usuals in one tap"],
              ] as [(p: IconProps) => ReactNode, string, string][]).map(([Icon, color, label]) => (
                <div key={label} className="ct-card flex items-center gap-3 p-4">
                  <span className="flex h-9 w-9 flex-none items-center justify-center rounded-lg" style={{ background: `${color}22`, color }}>
                    <Icon className="h-5 w-5" />
                  </span>
                  <span className="text-sm font-medium text-[var(--ink)]/85">{label}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="order-1 flex justify-center gap-4 lg:order-2">
            <PhoneShot src={`${SHOT}/app-01.webp`} alt="Today dashboard" className="w-1/2 max-w-[230px]" />
            <PhoneShot src={`${SHOT}/app-03.webp`} alt="History trends and calendar" className="mt-10 w-1/2 max-w-[230px]" />
          </div>
        </div>
      </section>

      {/* ── Privacy ── */}
      <section id="privacy" className="relative scroll-mt-20 overflow-hidden border-y border-[var(--ink)]/5">
        <div className="ct-glow pointer-events-none absolute -right-20 top-0 h-96 w-96 opacity-40" />
        <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-5 py-20 lg:grid-cols-[1.1fr_0.9fr]">
          <div>
            <SectionTag><ShieldIcon className="h-3.5 w-3.5" /> Privacy by design</SectionTag>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-5xl">
              Fully AI-powered.<br /><span className="ct-grad">Nobody’s watching.</span>
            </h2>
            <p className="mt-5 max-w-lg text-lg text-[var(--ink)]/65">
              Most “AI calorie” apps want an account, then quietly build a profile of everything you eat.
              The Last Calorie Tracker does the opposite: the intelligence runs for you, and the record stays with you.
            </p>
            <div className="mt-8 overflow-hidden rounded-2xl border border-[var(--ink)]/10">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="bg-[var(--ink)]/5 text-[var(--ink)]/50">
                    <th className="px-4 py-3 font-medium">Data</th>
                    <th className="px-4 py-3 font-medium">Where it lives</th>
                    <th className="px-4 py-3 font-medium">Leaves device?</th>
                  </tr>
                </thead>
                <tbody>
                  {PRIVACY_ROWS.map(([a, b, c]) => (
                    <tr key={a} className="border-t border-[var(--ink)]/5">
                      <td className="px-4 py-3 text-[var(--ink)]/85">{a}</td>
                      <td className="px-4 py-3 text-[var(--ink)]/55">{b}</td>
                      <td className="px-4 py-3 text-[var(--accent-ink)]">{c}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="mt-4 text-sm text-[var(--ink)]/40">
              No accounts, no analytics identity, no server-side profile. The free-log counter syncs through
              your own iCloud — still without an account.
            </p>
          </div>
          <div className="flex justify-center">
            <PhoneShot src={`${SHOT}/app-04.webp`} alt="In-app help over the app’s private, on-device design" className="w-full max-w-[300px]" />
          </div>
        </div>
      </section>

      {/* ── Pricing ── */}
      <section id="pricing" className="mx-auto max-w-6xl scroll-mt-20 px-5 py-20">
        <div className="text-center">
          <SectionTag>Simple pricing</SectionTag>
          <h2 className="mx-auto mt-4 max-w-2xl text-3xl font-bold tracking-tight sm:text-4xl">
            Start free. Go Pro for less than a coffee a month.
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--ink)]/60">
            Your first <span className="font-semibold text-[var(--ink)]">10 food logs are free</span>. After that, Pro
            unlocks unlimited logging and every input method — with no account to create.
          </p>
        </div>

        <div className="mx-auto mt-12 grid max-w-3xl gap-5 sm:grid-cols-2">
          <div className="ct-card p-7">
            <p className="text-sm font-medium text-[var(--ink)]/55">Monthly</p>
            <p className="mt-3 text-4xl font-bold">$5.99<span className="text-lg font-medium text-[var(--ink)]/45">/mo</span></p>
            <p className="mt-2 text-sm text-[var(--ink)]/50">Flexible. Cancel anytime.</p>
          </div>
          <div className="relative ct-card overflow-hidden p-7" style={{ borderColor: "rgba(87,181,140,0.5)" }}>
            <span className="absolute right-5 top-6 rounded-full bg-[#57b58c]/15 px-2.5 py-1 text-xs font-bold text-[var(--accent-ink)]">Save 58%</span>
            <p className="text-sm font-medium text-[var(--ink)]/55">Yearly</p>
            <p className="mt-3 text-4xl font-bold">$29.99<span className="text-lg font-medium text-[var(--ink)]/45">/yr</span></p>
            <p className="mt-2 text-sm text-[var(--ink)]/50">Best value — about $2.50/mo.</p>
          </div>
        </div>

        <div className="mx-auto mt-6 flex max-w-3xl flex-wrap justify-center gap-x-6 gap-y-2 text-sm text-[var(--ink)]/55">
          {["10 logs free", "No account needed", "Restore on any device", "Cancel anytime"].map((t) => (
            <span key={t} className="inline-flex items-center gap-1.5"><Check className="h-4 w-4 text-[#57b58c]" /> {t}</span>
          ))}
        </div>
      </section>

      {/* ── Value / comparison ── */}
      <section id="value" className="scroll-mt-20 border-t border-[var(--ink)]/5 bg-[var(--surface-2)]">
        <div className="mx-auto max-w-5xl px-5 py-20">
          <div className="text-center">
            <SectionTag>Unbeatable value</SectionTag>
            <h2 className="mx-auto mt-4 max-w-2xl text-3xl font-bold tracking-tight sm:text-4xl">
              The same AI calorie tracking. A fraction of the price.
            </h2>
            <p className="mx-auto mt-4 max-w-xl text-[var(--ink)]/60">
              At <span className="font-semibold text-[var(--ink)]">$5.99/month</span>, The Last Calorie Tracker sits below
              mainstream plans and far under the aggressive AI calorie apps — without skimping on features.
            </p>
          </div>

          <div className="mt-12 space-y-2.5">
            {COMPARISON.map(({ app, price, label, verdict, self }) => (
              <div key={app} className={`rounded-2xl border p-4 ${self ? "border-[#57b58c]/50 bg-[#57b58c]/10" : "border-[var(--ink)]/10 bg-[var(--surface)]"}`}>
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2.5">
                    <span className={`text-sm font-semibold ${self ? "text-[var(--ink)]" : "text-[var(--ink)]/85"}`}>{app}</span>
                    {self && <span className="rounded-full bg-[#57b58c] px-2 py-0.5 text-[11px] font-bold text-[#06140d]">You</span>}
                  </div>
                  <span className={`text-sm font-semibold tabular-nums ${self ? "text-[var(--accent-ink)]" : "text-[var(--ink)]/70"}`}>{label}</span>
                </div>
                <div className="mt-2.5 flex items-center gap-3">
                  <div className="h-2.5 flex-1 overflow-hidden rounded-full bg-[var(--ink)]/5">
                    <div className="h-full rounded-full"
                      style={{ width: `${Math.max(8, (price / MAX_PRICE) * 100)}%`, background: self ? "linear-gradient(90deg,#4fae84,#73c2a1)" : "color-mix(in oklab, var(--ink) 28%, transparent)" }} />
                  </div>
                  <span className={`w-44 flex-none text-right text-xs ${self ? "font-semibold text-[var(--accent-ink)]" : "text-[var(--ink)]/45"}`}>{verdict}</span>
                </div>
              </div>
            ))}
          </div>

          <p className="mt-6 text-xs leading-relaxed text-[var(--ink)]/35">
            Competitor pricing is approximate, gathered from public App Store listings and third-party
            write-ups, and varies by region and over time. Several rivals push annual plans (e.g. MyFitnessPal
            Premium+ ~$79.99/yr, Lose It ~$39.99/yr, Foodnoms ~$40/yr); Cal AI’s monthly is commonly $9.99
            with a reported $5.99–$19.99 range. The Last Calorie Tracker is a flat $5.99/month or $29.99/year.
          </p>
        </div>
      </section>

      {/* ── FAQ ── */}
      <section className="mx-auto max-w-3xl px-5 py-20">
        <h2 className="text-center text-3xl font-bold tracking-tight sm:text-4xl">Questions, answered</h2>
        <div className="mt-10 space-y-3">
          {FAQ.map(({ q, a }) => (
            <details key={q} className="ct-card group p-5">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold">
                {q}
                <span className="flex h-6 w-6 flex-none items-center justify-center rounded-full bg-[var(--ink)]/5 text-[var(--ink)]/60 transition group-open:rotate-45">+</span>
              </summary>
              <p className="mt-3 text-sm leading-relaxed text-[var(--ink)]/60">{a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* ── Final CTA ── */}
      <section className="relative overflow-hidden border-t border-[var(--ink)]/5">
        <img src="/hero-food.webp" alt="" aria-hidden width={1400} height={2488} className="pointer-events-none absolute inset-0 h-full w-full object-cover opacity-25" />
        <div className="absolute inset-0 bg-[var(--app)]/85" />
        <div className="ct-glow pointer-events-none absolute bottom-0 left-1/2 h-80 w-[600px] -translate-x-1/2 opacity-50" />
        <div className="relative mx-auto max-w-3xl px-5 py-24 text-center">
          <img src="/app-icon.webp" alt="" width={72} height={72} className="mx-auto h-[72px] w-[72px] rounded-[18px] shadow-2xl" />
          <h2 className="mt-6 text-4xl font-bold tracking-tight sm:text-5xl">Eat well. Stay private.</h2>
          <p className="mx-auto mt-4 max-w-md text-lg text-[var(--ink)]/65">
            The Last Calorie Tracker is coming soon to the App Store. Private by design, powered by AI, $5.99 a month.
          </p>
          <div className="mt-8 flex justify-center">
            <ComingSoonBadge />
          </div>
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="border-t border-[var(--ink)]/5">
        <div className="mx-auto max-w-6xl px-5 py-12">
          <div className="flex flex-col items-start justify-between gap-8 md:flex-row md:items-center">
            <div className="flex items-center gap-2.5">
              <img src="/app-icon.webp" alt="" width={28} height={28} className="h-7 w-7 rounded-lg" />
              <span className="font-semibold">The Last Calorie Tracker</span>
            </div>
            <nav className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-[var(--ink)]/55">
              <a href="#features" className="hover:text-[var(--ink)]">Features</a>
              <a href="#privacy" className="hover:text-[var(--ink)]">Privacy</a>
              <a href="#pricing" className="hover:text-[var(--ink)]">Pricing</a>
              <a href="#value" className="hover:text-[var(--ink)]">Value</a>
              <a href="/privacy" className="hover:text-[var(--ink)]">Privacy Policy</a>
            </nav>
          </div>
          <div className="mt-8 border-t border-[var(--ink)]/5 pt-6 text-xs leading-relaxed text-[var(--ink)]/40">
            <p>© 2026 Unthinking AI, LLC. Built by Marco van Hylckama Vlieg. The Last Calorie Tracker is not yet available; “coming soon to the App Store.”</p>
            <p className="mt-2">
              Nutrition data from Open Food Facts (ODbL). Food analysis powered by OpenAI. Calorie and macro
              figures are estimates, not medical advice — consult a professional for dietary guidance.
            </p>
          </div>
        </div>
      </footer>

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "MobileApplication",
            name: "The Last Calorie Tracker",
            applicationCategory: "HealthApplication",
            operatingSystem: "iOS",
            description:
              "Private, AI-powered calorie and macro tracker. Log meals by voice, photo, barcode, or text — on-device, with no account.",
            offers: [
              { "@type": "Offer", price: "5.99", priceCurrency: "USD", name: "Monthly" },
              { "@type": "Offer", price: "29.99", priceCurrency: "USD", name: "Yearly" },
            ],
          }),
        }}
      />
    </div>
  );
}
