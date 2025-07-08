// API utility functions and SWR hooks
import useSWR from 'swr';
import type { BarcodeResponse, ParseFoodResponse } from '@/types';

// Base fetcher function
const fetcher = async (url: string) => {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error('An error occurred while fetching the data.');
  }
  return res.json();
};

// POST fetcher
const postFetcher = async (url: string, data: unknown) => {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(data),
  });
  
  if (!res.ok) {
    throw new Error('An error occurred while posting the data.');
  }
  
  return res.json();
};

// API endpoints
export const API_ENDPOINTS = {
  barcode: (code: string) => `/api/barcode/${code}`,
  parseFood: '/api/parse-food',
} as const;

// SWR hooks for data fetching
export const useBarcode = (code: string | null) => {
  const { data, error, isLoading } = useSWR<BarcodeResponse>(
    code ? API_ENDPOINTS.barcode(code) : null,
    fetcher,
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: false,
    }
  );

  return {
    data,
    isLoading,
    error,
  };
};



// Direct API calls (not using SWR)
export const parseFood = async (text: string, units: 'metric' | 'imperial' = 'metric'): Promise<ParseFoodResponse> => {
  try {
    return await postFetcher(API_ENDPOINTS.parseFood, { text, units });
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
};





// Utility functions for API calls
export const lookupBarcode = async (code: string): Promise<BarcodeResponse> => {
  try {
    return await fetcher(API_ENDPOINTS.barcode(code));
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
};

// Error handling utilities
export const isAPIError = (error: unknown): error is { message: string } => {
  return error !== null && typeof error === 'object' && 'message' in error && typeof (error as { message: unknown }).message === 'string';
};

export const getErrorMessage = (error: unknown): string => {
  if (isAPIError(error)) {
    return error.message;
  }
  return 'An unexpected error occurred';
};

// Cache management
export const clearAPICache = () => {
  // This would clear SWR cache if needed
  // For now, we'll implement this when we add SWR provider
};

// Network status utilities
export const isOnline = (): boolean => {
  return typeof navigator !== 'undefined' ? navigator.onLine : true;
};

export const waitForOnline = (): Promise<void> => {
  return new Promise((resolve) => {
    if (isOnline()) {
      resolve();
      return;
    }
    
    const handleOnline = () => {
      window.removeEventListener('online', handleOnline);
      resolve();
    };
    
    window.addEventListener('online', handleOnline);
  });
};
