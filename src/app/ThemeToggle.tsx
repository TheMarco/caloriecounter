"use client";

//
// Light/dark toggle for the marketing page.
//
// By design it does NOT persist: the page defaults to the visitor's system
// setting (handled entirely in CSS via prefers-color-scheme, so there's no
// flash on load), the toggle just sets `data-theme` on <html> to override the
// media query for the current visit, and a reload drops it back to the system
// setting. Which icon shows is decided in CSS (.icon-sun / .icon-moon), so the
// button is correct on first paint without any client work.
//

function SunIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}
      strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
  );
}

function MoonIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8}
      strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden>
      <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
    </svg>
  );
}

export function ThemeToggle({ className = "" }: { className?: string }) {
  function toggle() {
    const root = document.documentElement;
    const isDark =
      root.dataset.theme === "dark" ||
      (!root.dataset.theme &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    root.dataset.theme = isDark ? "light" : "dark";
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label="Switch between light and dark appearance"
      title="Toggle light / dark"
      className={`relative flex h-9 w-9 items-center justify-center rounded-full border border-[var(--ink)]/10 bg-[var(--ink)]/5 text-[var(--ink)]/70 transition hover:bg-[var(--ink)]/10 hover:text-[var(--ink)] ${className}`}
    >
      <SunIcon className="icon-sun h-[18px] w-[18px]" />
      <MoonIcon className="icon-moon h-[18px] w-[18px]" />
    </button>
  );
}
