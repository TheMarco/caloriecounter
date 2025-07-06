'use client';

import { usePWA } from '@/hooks/usePWA';

export function OfflineIndicator() {
  const { isOnline } = usePWA();

  if (isOnline) {
    return null;
  }

  return (
    <div className="fixed top-0 left-0 right-0 z-50 bg-orange-500 text-white text-center py-2 text-sm">
      <div className="flex items-center justify-center space-x-2">
        <span>📡</span>
        <span>You&apos;re offline - data will sync when reconnected</span>
      </div>
    </div>
  );
}
