'use client';

import type { AddFabProps } from '@/types';
import { BarcodeIconComponent, MicrophoneIconComponent, PencilIconComponent } from '@/components/icons';

export function AddFab({ onScan, onVoice, onText }: AddFabProps) {
  return (
    <div data-testid="add-fab" className="grid grid-cols-3 gap-4 mb-6">
      <button
        data-testid="scan-button"
        onClick={onScan}
        className="card-glass card-glass-hover rounded-3xl p-6 text-center transition-all duration-300 shadow-2xl active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <BarcodeIconComponent size="xl" className="text-blue-400" />
        </div>
        <div className="text-sm font-semibold text-white">Scan</div>
      </button>

      <button
        data-testid="voice-button"
        onClick={onVoice}
        className="card-glass card-glass-hover rounded-3xl p-6 text-center transition-all duration-300 shadow-2xl active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <MicrophoneIconComponent size="xl" className="text-green-400" />
        </div>
        <div className="text-sm font-semibold text-white">Voice</div>
      </button>

      <button
        data-testid="text-button"
        onClick={onText}
        className="card-glass card-glass-hover rounded-3xl p-6 text-center transition-all duration-300 shadow-2xl active:scale-95"
      >
        <div className="mb-3 flex justify-center">
          <PencilIconComponent size="xl" className="text-purple-400" />
        </div>
        <div className="text-sm font-semibold text-white">Type</div>
      </button>
    </div>
  );
}
