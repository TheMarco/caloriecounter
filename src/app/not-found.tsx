import Link from "next/link";

export default function NotFound() {
  return (
    <div className="ct flex min-h-screen items-center justify-center px-6">
      <div className="text-center">
        <p className="text-6xl font-bold tracking-tight">404</p>
        <h1 className="mt-3 text-2xl font-semibold">Page not found</h1>
        <p className="mt-2 text-white/55">The page you’re looking for doesn’t exist.</p>
        <Link
          href="/"
          className="mt-8 inline-block rounded-full bg-[#57b58c] px-5 py-3 text-sm font-semibold text-[#06140d] transition hover:bg-[#73c2a1]"
        >
          Back to home
        </Link>
      </div>
    </div>
  );
}
