'use client';

import { useState } from 'react';
import { lookupBarcode } from '@/utils/api';
import { addEntry } from '@/utils/idb';
import type { BarcodeResponse } from '@/types';

export function useBarcode() {
  const [isScanning, setIsScanning] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startScanning = () => {
    setIsScanning(true);
    setError(null);
  };

  const stopScanning = () => {
    setIsScanning(false);
  };

  const handleBarcodeDetected = async (code: string) => {
    try {
      setIsLoading(true);
      setError(null);

      console.log('Looking up barcode:', code);

      // Lookup barcode information
      const response: BarcodeResponse = await lookupBarcode(code);

      if (!response.success || !response.data) {
        throw new Error(response.error || 'Product not found');
      }

      const { food, kcal, unit, serving_size } = response.data;

      // Create entry with the scanned product
      const entry = await addEntry({
        food,
        qty: serving_size || 100,
        unit,
        kcal: Math.round(kcal * ((serving_size || 100) / 100)),
        method: 'barcode',
        confidence: 1.0,
      });

      console.log('Entry created:', entry);

      // Stop scanning after successful detection
      stopScanning();

      return entry;

    } catch (err) {
      console.error('Barcode processing error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to process barcode';
      setError(errorMessage);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const handleScanError = (error: string) => {
    console.error('Scan error:', error);
    setError(error);
  };

  return {
    isScanning,
    isLoading,
    error,
    startScanning,
    stopScanning,
    handleBarcodeDetected,
    handleScanError,
  };
}
