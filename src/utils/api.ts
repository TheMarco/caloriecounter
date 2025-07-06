// API utility functions and SWR hooks
import useSWR from 'swr';
import type { Entry, BarcodeResponse, ParseFoodResponse, StatsResponse, DateRange } from '@/types';

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
  entry: '/api/entry',
  stats: (range: DateRange) => `/api/stats?range=${range}`,
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

export const useStats = (range: DateRange) => {
  const { data, error, isLoading, mutate } = useSWR<StatsResponse>(
    API_ENDPOINTS.stats(range),
    fetcher,
    {
      refreshInterval: 0, // Don't auto-refresh
      revalidateOnFocus: false,
    }
  );

  return {
    data,
    isLoading,
    error,
    mutate,
  };
};

// Direct API calls (not using SWR)
export const parseFood = async (text: string): Promise<ParseFoodResponse> => {
  try {
    return await postFetcher(API_ENDPOINTS.parseFood, { text });
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
};

export const saveEntry = async (entry: Omit<Entry, 'id'>): Promise<{ success: boolean; id?: string; error?: string }> => {
  try {
    const response = await postFetcher(API_ENDPOINTS.entry, entry);
    return response;
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
};

export const deleteEntryAPI = async (id: string): Promise<{ success: boolean; error?: string }> => {
  try {
    const res = await fetch(`${API_ENDPOINTS.entry}/${id}`, {
      method: 'DELETE',
    });
    
    if (!res.ok) {
      throw new Error('Failed to delete entry');
    }
    
    return await res.json();
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
