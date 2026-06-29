import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";
import { ThemeToggle } from "../ThemeToggle";

// The Last Calorie Tracker — Support / Help.
// Static server component, styled with the shared `.ct` design system. The help
// content mirrors the app's in-app Help guide (HelpView), About/Privacy screens, and
// onboarding copy — keep it in sync with the app if that behavior changes. The contact
// address is the same one used on the Privacy page.

const CONTACT = "info@ai-created.com";

export const metadata: Metadata = {
  title: "Support & Help — The Last Calorie Tracker",
  description:
    "Help for The Last Calorie Tracker: log food by voice, photo, barcode, or text, track calories and macros, use Apple Health, manage your subscription, and export your data. Questions? Email info@ai-created.com.",
  alternates: { canonical: "/support" },
  openGraph: {
    type: "article",
    title: "Support & Help — The Last Calorie Tracker",
    description:
      "How to log food, track macros, use Apple Health, manage your subscription, and get your data out. Questions? Email info@ai-created.com.",
    images: [{ url: "/og.webp", width: 1200, height: 630, alt: "The Last Calorie Tracker" }],
  },
};

/* ───────────────────────────── content ───────────────────────────── */

type GuideItem = [term: string, body: string];
type GuideSection = {
  id: string;
  title: string;
  lead?: string;
  items?: GuideItem[];
  after?: ReactNode;
};

// Mirrors the in-app Help guide, About/Privacy, and onboarding copy.
const GUIDE: GuideSection[] = [
  {
    id: "today",
    title: "The Today screen",
    items: [
      ["Your calorie ring", "The big number is net calories for the day: your goal minus what you’ve eaten, plus any exercise adjustments. The ring fills as you log."],
      ["Macros", "Protein, carbs, and fat each get their own ring beneath the calories, tracked against your daily targets."],
      ["Exercise & adjustments", "Tap the adjustments card to add or remove calories for a workout or a manual tweak. Adjustments raise your remaining budget for the day."],
    ],
  },
  {
    id: "logging",
    title: "Logging food",
    lead: "Tap + in the dock to open the capture tools, then choose how you want to log.",
    items: [
      ["Voice", "Say what you ate in plain language — “a bowl of oatmeal with blueberries.” It’s transcribed on your iPhone and the food is recognised automatically."],
      ["Photo", "Snap your meal and the app estimates the items and their calories. Review and adjust before saving."],
      ["Barcode", "Scan a packaged product’s barcode to pull its nutrition from the Open Food Facts database."],
      ["Verify with label", "After a barcode scan, tap “Verify with label” to scan the printed Nutrition Facts. You’ll see a side-by-side comparison, and confirmed values are trusted for that product next time — shown as “Label verified.”"],
      ["Text", "Prefer typing? Enter the food by hand and it’s parsed just like voice."],
    ],
  },
  {
    id: "faster",
    title: "Faster logging",
    items: [
      ["Your Usuals", "Foods you log often appear as chips on Today — tap one to re-log it in a single step."],
      ["Edit an entry", "Tap any logged item to change its amount or details, or to delete it."],
      ["Undo", "Logged something by mistake? Tap Undo on the toast that appears right after saving."],
    ],
  },
  {
    id: "goals",
    title: "Goals & daily targets",
    lead: "When you first set up the app, a few quick questions tune your plan to you. You can re-run it or fine-tune any number anytime.",
    items: [
      ["Set targets from your goal", "Answer your goal, diet style, activity level, and a few basics, and the app estimates your daily calories and macros using the Mifflin–St Jeor formula and standard activity factors."],
      ["Diet styles", "Choose how you like to eat — Balanced, High Protein, Low Carb, Keto, High Carb, or Mediterranean — and your macro split adjusts to match."],
      ["Adjust anything manually", "Targets are a starting point, not a rule. Tap any value in Settings → Daily Targets to edit it by hand, or re-run the setup wizard to recalculate."],
    ],
    after: (
      <p className="text-sm text-[var(--ink)]/55">
        Targets are estimates to get you started, not medical advice. If you have a health condition or
        specific goals, check with a doctor or registered dietitian.
      </p>
    ),
  },
  {
    id: "health",
    title: "Apple Health",
    items: [
      ["Nutrition sync", "Optionally write your food entries to Apple Health so calories and macros sit alongside the rest of your health data."],
      ["Workouts & active energy", "With permission, the app notices your workouts and offers to add the calories you burned as an adjustment. Turn this on in Settings → Apple Health. Workouts are read only — never written back."],
      ["You’re in control", "Health access is opt-in and off until you turn it on. You can change or disconnect it anytime in Settings or the Health app, and the app works fully without it."],
    ],
  },
  {
    id: "history",
    title: "History & trends",
    items: [
      ["Browse past days", "The History tab shows a calendar — tap any day to see exactly what you logged."],
      ["Charts", "Watch calories and macros trend over time so you can spot patterns."],
      ["Weight", "Log your weight to track it on its own chart over weeks and months."],
    ],
  },
  {
    id: "pro",
    title: "Free logs & Pro",
    items: [
      ["Free to start", "Your first 10 food logs are free. After that, Pro unlocks unlimited logging and every input method. Everything you already logged stays, and you can keep browsing it."],
      ["What Pro includes", "Unlimited food logging; voice, photo, and barcode capture; Apple Health sync; and full history and trends."],
      ["Pricing", "$5.99 per month or $29.99 per year. Subscriptions auto-renew until cancelled, and are billed through your Apple ID."],
      ["Restore purchases", "Already subscribed on another device? Tap Restore Purchases on the upgrade screen — no account needed, it follows your Apple ID."],
      ["Manage or cancel", "Manage, change, or cancel your plan anytime in the Settings app on your iPhone, under your name → Subscriptions."],
    ],
  },
  {
    id: "data",
    title: "Your data: export, import & reset",
    items: [
      ["Export your history", "From Settings, export a daily-totals CSV of your entries, offsets, and weigh-ins. Your data is yours to take anywhere."],
      ["Move to a new device", "Import that CSV on a new iPhone to restore your history. No account, no lock-in."],
      ["Start over", "Erase all data from Settings to permanently delete every entry and restart setup. Export a backup first if you want to keep your history — this can’t be undone."],
    ],
  },
  {
    id: "privacy",
    title: "Privacy & security",
    items: [
      ["On-device by design", "Your food log lives in a private database on your iPhone. There’s no account to create and nothing to sign in to."],
      ["What leaves your device", "Only the words or photo you submit for recognition are sent — securely — to do the parsing, and barcode lookups query the public Open Food Facts database. Your diary itself is never uploaded."],
      ["Lock the app", "Turn on the biometric lock in Settings to require Face ID or Touch ID before your diary opens."],
    ],
    after: (
      <p>
        For the complete details, read our{" "}
        <Link href="/privacy" className="text-[var(--accent-ink)] underline-offset-2 hover:underline">
          Privacy Policy
        </Link>
        .
      </p>
    ),
  },
  {
    id: "accessibility",
    title: "Accessibility",
    items: [
      ["Larger & Bold text", "The app fully supports Dynamic Type and the system Bold Text setting (Settings → Accessibility → Display & Text Size)."],
      ["VoiceOver", "Screens, controls, and logged items are labeled so the app is navigable by VoiceOver."],
    ],
  },
];

// Common questions — mirrors the FAQ on the marketing page.
const FAQ: GuideItem[] = [
  ["Do I need to create an account?", "No. There’s no sign-up, no email, and no password. You open the app and start logging — your data is yours, on your device."],
  ["It’s AI-powered — is my data being used to train models?", "Only the text or photo you submit for a single meal is sent to be parsed, with no name, account, or device ID attached. Under the AI provider’s API terms, that data isn’t used to train their models. Your diary itself is never uploaded."],
  ["What happens after my 10 free logs?", "Logging continues with The Last Calorie Tracker Pro — $5.99/month or $29.99/year. Everything you already logged stays, and you can browse it freely."],
  ["Does it work with Apple Health?", "Yes, optionally. You can sync meals, macros, and weigh-ins, import existing weight, and have finished workouts offered as a calorie offset — all opt-in and off until you turn it on."],
  ["Can I get my data out?", "Anytime. Export a full CSV of every entry, offset, and weigh-in from Settings, and import it back on a new device. No lock-in."],
];

// Table-of-contents order — matches the section ids rendered below.
const TOC: { id: string; label: string }[] = [
  ...GUIDE.map((s) => ({ id: s.id, label: s.title })),
  { id: "faq", label: "Common questions" },
  { id: "contact", label: "Contact us" },
];

/* ───────────────────────────── helpers ───────────────────────────── */

function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return (
    <section id={id} className="scroll-mt-24 border-t border-[var(--ink)]/5 pt-10">
      <h2 className="text-2xl font-bold tracking-tight text-[var(--ink)]">{title}</h2>
      <div className="mt-4 space-y-4 text-[15px] leading-relaxed text-[var(--ink)]/70">{children}</div>
    </section>
  );
}

function ItemList({ items }: { items: GuideItem[] }) {
  return (
    <dl className="space-y-5">
      {items.map(([term, body]) => (
        <div key={term}>
          <dt className="font-semibold text-[var(--ink)]/90">{term}</dt>
          <dd className="mt-1 text-[var(--ink)]/70">{body}</dd>
        </div>
      ))}
    </dl>
  );
}

/* ────────────────────────────── page ─────────────────────────────── */

export default function Support() {
  return (
    <div className="ct min-h-screen w-full overflow-x-hidden antialiased">
      {/* ── Header ── */}
      <header className="sticky top-0 z-50 border-b border-[var(--ink)]/5 bg-[var(--app)]/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-5">
          <Link href="/" className="flex items-center gap-2.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/app-icon.webp" alt="" width={32} height={32} className="h-8 w-8 rounded-[9px]" />
            <span className="text-[15px] font-semibold tracking-tight">The Last Calorie Tracker</span>
          </Link>
          <div className="flex items-center gap-2.5">
            <ThemeToggle />
            <Link href="/" className="text-sm text-[var(--ink)]/65 transition hover:text-[var(--ink)]">
              ← Back to site
            </Link>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-5 py-16">
        {/* ── Title ── */}
        <p className="text-xs font-semibold uppercase tracking-wider text-[var(--accent-ink)]">Support</p>
        <h1 className="mt-3 text-4xl font-bold leading-tight tracking-tight sm:text-5xl">
          Help, <span className="ct-grad">whenever you need it.</span>
        </h1>
        <p className="mt-5 text-lg leading-relaxed text-[var(--ink)]/70">
          Everything you need to track what you eat — by voice, photo, barcode, or text — with your diary
          living privately on your iPhone. Find your topic below, and if anything’s still unclear, we’re an
          email away.
        </p>

        {/* ── Contact callout ── */}
        <div className="ct-card mt-10 p-6">
          <h2 className="text-base font-semibold text-[var(--ink)]">Have a question we don’t answer here?</h2>
          <p className="mt-2 text-[15px] leading-relaxed text-[var(--ink)]/70">
            Email us at{" "}
            <a href={`mailto:${CONTACT}`} className="font-semibold text-[var(--accent-ink)] underline-offset-2 hover:underline">
              {CONTACT}
            </a>
            . There’s no account and no ticket system — just a real reply. We read every message.
          </p>
        </div>

        {/* ── On this page ── */}
        <nav aria-label="On this page" className="mt-8 rounded-2xl border border-[var(--ink)]/10 p-5">
          <p className="text-xs font-semibold uppercase tracking-wider text-[var(--ink)]/45">On this page</p>
          <ul className="mt-3 grid gap-x-6 gap-y-2 text-[15px] sm:grid-cols-2">
            {TOC.map(({ id, label }) => (
              <li key={id}>
                <a href={`#${id}`} className="text-[var(--ink)]/70 underline-offset-2 transition hover:text-[var(--ink)] hover:underline">
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        {/* ── Guide ── */}
        <div className="mt-12 space-y-2">
          {GUIDE.map((section) => (
            <Section key={section.id} id={section.id} title={section.title}>
              {section.lead && <p>{section.lead}</p>}
              {section.items && <ItemList items={section.items} />}
              {section.after}
            </Section>
          ))}

          {/* ── Common questions ── */}
          <Section id="faq" title="Common questions">
            <dl className="space-y-6">
              {FAQ.map(([q, a]) => (
                <div key={q}>
                  <dt className="font-semibold text-[var(--ink)]/90">{q}</dt>
                  <dd className="mt-1.5 text-[var(--ink)]/70">{a}</dd>
                </div>
              ))}
            </dl>
          </Section>

          {/* ── Contact ── */}
          <Section id="contact" title="Contact us">
            <p>
              Still stuck, found a bug, or have a suggestion? Email{" "}
              <a href={`mailto:${CONTACT}`} className="text-[var(--accent-ink)] underline-offset-2 hover:underline">
                {CONTACT}
              </a>
              . We read every message and reply personally — no account or ticket number required.
            </p>
            <p className="text-sm text-[var(--ink)]/55">
              For how your data is handled, see our{" "}
              <Link href="/privacy" className="text-[var(--accent-ink)] underline-offset-2 hover:underline">
                Privacy Policy
              </Link>
              .
            </p>
          </Section>
        </div>
      </main>

      {/* ── Footer ── */}
      <footer className="border-t border-[var(--ink)]/5">
        <div className="mx-auto max-w-3xl px-5 py-10">
          <div className="flex flex-col items-start justify-between gap-4 sm:flex-row sm:items-center">
            <Link href="/" className="flex items-center gap-2.5">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/app-icon.webp" alt="" width={28} height={28} className="h-7 w-7 rounded-lg" />
              <span className="font-semibold">The Last Calorie Tracker</span>
            </Link>
            <nav className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-[var(--ink)]/55">
              <Link href="/" className="transition hover:text-[var(--ink)]">Home</Link>
              <Link href="/privacy" className="transition hover:text-[var(--ink)]">Privacy Policy</Link>
              <a href={`mailto:${CONTACT}`} className="transition hover:text-[var(--ink)]">Email us</a>
            </nav>
          </div>
          <p className="mt-8 border-t border-[var(--ink)]/5 pt-6 text-xs text-[var(--ink)]/40">
            © 2026 Unthinking AI, LLC. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
