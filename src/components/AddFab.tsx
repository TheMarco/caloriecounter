'use client';

import type { AddFabProps } from '@/types';
import { BarcodeIconComponent, MicrophoneIconComponent, PencilIconComponent } from '@/components/icons';

export function AddFab({ onScan, onVoice, onText }: AddFabProps) {
  return (
    <div className="grid grid-cols-3 gap-4 mb-6">
      <button
        onClick={onScan}
        className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 text-center transition-theme hover:shadow-md hover:scale-105 duration-200 active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <BarcodeIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-semibold text-black dark:text-white">Scan</div>
      </button>

      <button
        onClick={onVoice}
        className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 text-center transition-theme hover:shadow-md hover:scale-105 duration-200 active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <MicrophoneIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-semibold text-black dark:text-white">Voice</div>
      </button>

      <button
        onClick={onText}
        className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 text-center transition-theme hover:shadow-md hover:scale-105 duration-200 active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <PencilIconComponent size="xl" className="text-gray-800 dark:text-gray-200" />
        </div>
        <div className="text-sm font-semibold text-black dark:text-white">Type</div>
      </button>
    </div>
  );
}
