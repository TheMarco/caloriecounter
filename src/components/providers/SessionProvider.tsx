'use client';

import { ReactNode } from 'react';

interface SessionProviderProps {
  children: ReactNode;
}

export function SessionProvider({ children }: SessionProviderProps) {
  // Simplified provider for now - will implement auth later
  return <>{children}</>;
}
