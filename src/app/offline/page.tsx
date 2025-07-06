'use client';

import Link from 'next/link';

export default function OfflinePage() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-md mx-auto px-4 text-center">
        <div className="bg-white rounded-lg shadow-sm border p-8">
          {/* Offline Icon */}
          <div className="text-6xl mb-4">📱</div>
          
          {/* Title */}
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            You&apos;re Offline
          </h1>
          
          {/* Description */}
          <p className="text-gray-600 mb-6">
            No internet connection detected. Don&apos;t worry - you can still use the app! 
            Your data will sync when you&apos;re back online.
          </p>
          
          {/* Features Available Offline */}
          <div className="text-left mb-6">
            <h2 className="font-semibold text-gray-900 mb-3">Available offline:</h2>
            <ul className="space-y-2 text-sm text-gray-600">
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
            <h2 className="font-semibold text-gray-900 mb-3">Requires internet:</h2>
            <ul className="space-y-2 text-sm text-gray-600">
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
            className="w-full bg-blue-500 hover:bg-blue-600 text-white py-3 px-4 rounded-md font-medium transition-colors"
          >
            Try Again
          </button>
          
          {/* Back to App */}
          <Link
            href="/"
            className="block mt-4 text-blue-600 hover:text-blue-800 text-sm"
          >
            ← Back to App
          </Link>
        </div>
      </div>
    </div>
  );
}
