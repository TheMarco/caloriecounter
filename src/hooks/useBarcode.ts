'use client';

import { useState } from 'react';
import { lookupBarcode } from '@/utils/api';
import { addEntry } from '@/utils/idb';
import type { BarcodeResponse } from '@/types';

export function useBarcode() {
  const [isScanning, setIsScanning] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [parsedFood, setParsedFood] = useState<{ food: string; quantity: number; unit: string; kcal: number; notes?: string } | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

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

      // Stop scanning and show confirmation dialog
      stopScanning();

      // Prepare food data for confirmation dialog
      const foodData = {
        food,
        quantity: serving_size || 100,
        unit,
        kcal: Math.round(kcal), // Use calories as-is from barcode API (already calculated for serving)
        notes: `Scanned product: ${food}`
      };

      setParsedFood(foodData);
      setShowConfirmDialog(true);
      console.log('📋 Showing confirmation dialog with data:', foodData);

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

  const handleConfirmFood = async (data: { food: string; qty: number; unit: string; kcal: number }) => {
    try {
      setIsProcessing(true);

      // Create entry with the confirmed data
      const entryData = {
        food: data.food,
        qty: data.qty,
        unit: data.unit,
        kcal: data.kcal,
        method: 'barcode' as const,
        confidence: 1.0,
      };
      console.log('💾 Creating entry with confirmed data:', entryData);

      const entry = await addEntry(entryData);
      console.log('✅ Entry created successfully:', entry);

      // Close dialog
      setShowConfirmDialog(false);
      setParsedFood(null);

      return entry;

    } catch (err) {
      console.error('❌ Failed to save barcode entry:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to save entry';
      setError(errorMessage);
      throw err;
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCancelConfirm = () => {
    setShowConfirmDialog(false);
    setParsedFood(null);
  };

  const handleScanError = (error: string) => {
    console.error('Scan error:', error);
    setError(error);
  };

  return {
    isScanning,
    isLoading,
    error,
    showConfirmDialog,
    parsedFood,
    isProcessing,
    startScanning,
    stopScanning,
    handleBarcodeDetected,
    handleScanError,
    handleConfirmFood,
    handleCancelConfirm,
  };
}
