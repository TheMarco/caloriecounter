'use client';

import Link from 'next/link';

export default function OfflinePage() {
  return (
    <div className="min-h-screen bg-white dark:bg-black transition-theme flex items-center justify-center">
      <div className="max-w-md mx-auto px-6 text-center">
        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-8 transition-theme">
          {/* Offline Icon */}
          <div className="text-6xl mb-4">📱</div>
          
          {/* Title */}
          <h1 className="text-2xl font-bold text-black dark:text-white mb-4">
            You&apos;re Offline
          </h1>

          {/* Description */}
          <p className="text-gray-700 dark:text-gray-200 mb-6 font-medium">
            No internet connection detected. Don&apos;t worry - you can still use the app!
            Your data will sync when you&apos;re back online.
          </p>
          
          {/* Features Available Offline */}
          <div className="text-left mb-6">
            <h2 className="font-semibold text-black dark:text-white mb-3">Available offline:</h2>
            <ul className="space-y-2 text-sm text-gray-700 dark:text-gray-200">
              <li className="flex items-center space-x-2">
                <span className="text-green-500">✓</span>
                <span>View today&apos;s entries</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-green-500">✓</span>
                <span>Add food manually</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-green-500">✓</span>
                <span>View calorie totals</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-green-500">✓</span>
                <span>Delete entries</span>
              </li>
            </ul>
          </div>
          
          {/* Features Requiring Internet */}
          <div className="text-left mb-6">
            <h2 className="font-semibold text-black dark:text-white mb-3">Requires internet:</h2>
            <ul className="space-y-2 text-sm text-gray-700 dark:text-gray-200">
              <li className="flex items-center space-x-2">
                <span className="text-orange-500">⚠</span>
                <span>Barcode scanning</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-orange-500">⚠</span>
                <span>Voice input with AI</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-orange-500">⚠</span>
                <span>AI food parsing</span>
              </li>
              <li className="flex items-center space-x-2">
                <span className="text-orange-500">⚠</span>
                <span>Cloud sync</span>
              </li>
            </ul>
          </div>
          
          {/* Action Button */}
          <button
            onClick={() => window.location.reload()}
            className="w-full bg-blue-500 hover:bg-blue-600 text-white py-4 px-6 rounded-xl font-semibold transition-all duration-200 hover:scale-105 active:scale-95 mb-4"
          >
            Try Again
          </button>

          {/* Back to App */}
          <Link
            href="/"
            className="block text-blue-500 dark:text-blue-400 hover:text-blue-600 dark:hover:text-blue-300 text-sm font-medium transition-colors"
          >
            ← Back to App
          </Link>
        </div>
      </div>
    </div>
  );
}
