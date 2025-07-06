'use client';

import type { AddFabProps } from '@/types';

export function AddFab({ onScan, onVoice, onText }: AddFabProps) {
  return (
    <div className="grid grid-cols-3 gap-4 mb-6">
      <button
        onClick={onScan}
        className="bg-white rounded-lg shadow-sm border-2 border-gray-200 p-4 text-center hover:bg-gray-50 hover:border-gray-300 transition-colors active:bg-gray-100"
      >
        <div className="text-2xl mb-2">📷</div>
        <div className="text-sm font-medium text-gray-900">Scan</div>
      </button>

      <button
        onClick={onVoice}
        className="bg-white rounded-lg shadow-sm border-2 border-gray-200 p-4 text-center hover:bg-gray-50 hover:border-gray-300 transition-colors active:bg-gray-100"
      >
        <div className="text-2xl mb-2">🎤</div>
        <div className="text-sm font-medium text-gray-900">Voice</div>
      </button>

      <button
        onClick={onText}
        className="bg-white rounded-lg shadow-sm border-2 border-gray-200 p-4 text-center hover:bg-gray-50 hover:border-gray-300 transition-colors active:bg-gray-100"
      >
        <div className="text-2xl mb-2">✏️</div>
        <div className="text-sm font-medium text-gray-900">Type</div>
      </button>
    </div>
  );
}
