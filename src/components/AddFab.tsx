'use client';

import type { AddFabProps } from '@/types';
import { BarcodeIconComponent, MicrophoneIconComponent, PencilIconComponent } from '@/components/icons';

export function AddFab({ onScan, onVoice, onText }: AddFabProps) {
  return (
    <div className="grid grid-cols-3 gap-4 mb-6">
      <button
        onClick={onScan}
        className="bg-white dark:bg-gray-900 rounded-lg shadow-sm border-2 border-gray-200 dark:border-gray-600 p-4 text-center hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-300 dark:hover:border-gray-500 transition-colors active:bg-gray-100 dark:active:bg-gray-700"
      >
        <div className="mb-2 flex justify-center">
          <BarcodeIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-medium text-black dark:text-white">Scan</div>
      </button>

      <button
        onClick={onVoice}
        className="bg-white dark:bg-gray-900 rounded-lg shadow-sm border-2 border-gray-200 dark:border-gray-600 p-4 text-center hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-300 dark:hover:border-gray-500 transition-colors active:bg-gray-100 dark:active:bg-gray-700"
      >
        <div className="mb-2 flex justify-center">
          <MicrophoneIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-medium text-black dark:text-white">Voice</div>
      </button>

      <button
        onClick={onText}
        className="bg-white dark:bg-gray-900 rounded-lg shadow-sm border-2 border-gray-200 dark:border-gray-600 p-4 text-center hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-300 dark:hover:border-gray-500 transition-colors active:bg-gray-100 dark:active:bg-gray-700"
      >
        <div className="mb-2 flex justify-center">
          <PencilIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-medium text-black dark:text-white">Type</div>
      </button>
    </div>
  );
}
