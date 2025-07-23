import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="min-h-screen gradient-bg flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-6xl font-bold text-white mb-4">404</h1>
        <h2 className="text-2xl font-semibold text-white mb-4">Page Not Found</h2>
        <p className="text-white/70 mb-8">The page you&apos;re looking for doesn&apos;t exist.</p>
        <Link 
          href="/" 
          className="inline-block px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-2xl transition-colors"
        >
          Go Home
        </Link>
      </div>
    </div>
  );
}
