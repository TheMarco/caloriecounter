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
    console.log('🛑 useBarcode: Stopping scanning');
    setIsScanning(false);
  };

  const handleBarcodeDetected = async (code: string) => {
    try {
      console.log('🔍 Starting barcode processing for:', code);
      setIsLoading(true);
      setError(null);

      console.log('📡 Looking up barcode:', code);

      // Lookup barcode information
      const response: BarcodeResponse = await lookupBarcode(code);
      console.log('📡 Barcode API response:', response);

      if (!response.success || !response.data) {
        console.error('❌ Barcode lookup failed:', response.error);
        throw new Error(response.error || 'Product not found');
      }

      const { food, kcal, unit, serving_size } = response.data;
      console.log('📦 Product data:', { food, kcal, unit, serving_size });

      // Create entry with the scanned product
      const entryData = {
        food,
        qty: serving_size || 100,
        unit,
        kcal: Math.round(kcal * ((serving_size || 100) / 100)),
        method: 'barcode' as const,
        confidence: 1.0,
      };
      console.log('💾 Creating entry with data:', entryData);

      const entry = await addEntry(entryData);
      console.log('✅ Entry created successfully:', entry);

      // Stop scanning after successful detection
      stopScanning();
      console.log('🛑 Scanning stopped');

      return entry;

    } catch (err) {
      console.error('❌ Barcode processing error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to process barcode';
      setError(errorMessage);
      throw err;
    } finally {
      setIsLoading(false);
      console.log('🏁 Barcode processing finished');
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
