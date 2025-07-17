'use client';

import { useState } from 'react';
import { addEntry } from '@/utils/idb';
import type { ParseFoodResponse } from '@/types';

export function useTextInput(date?: string) {
  const [isActive, setIsActive] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [parsedFood, setParsedFood] = useState<ParseFoodResponse['data'] | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startTextInput = () => {
    setIsActive(true);
    setError(null);
    setParsedFood(null);
  };

  const stopTextInput = () => {
    setIsActive(false);
  };

  const handleFoodParsed = (data: ParseFoodResponse['data']) => {
    console.log('Food parsed:', data);
    setParsedFood(data);
    setShowConfirmDialog(true);
    setIsActive(false);
  };

  const handleConfirmFood = async (data: { food: string; qty: number; unit: string; kcal: number; fat?: number; carbs?: number; protein?: number }) => {
    try {
      setIsProcessing(true);

      // Create entry with the confirmed data
      const entry = await addEntry({
        food: data.food,
        qty: data.qty,
        unit: data.unit,
        kcal: data.kcal,
        fat: data.fat || 0,
        carbs: data.carbs || 0,
        protein: data.protein || 0,
        method: 'text',
        confidence: 0.8, // Good confidence since user confirmed
      }, date);

      console.log('Entry created:', entry);

      // Close dialog
      setShowConfirmDialog(false);
      setParsedFood(null);

      return entry;

    } catch (err) {
      console.error('Failed to save entry:', err);
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
    setError(null);
  };

  const handleTextError = (error: string) => {
    console.error('Text input error:', error);
    setError(error);
  };

  const reset = () => {
    setIsActive(false);
    setShowConfirmDialog(false);
    setParsedFood(null);
    setIsProcessing(false);
    setError(null);
  };

  return {
    isActive,
    showConfirmDialog,
    parsedFood,
    isProcessing,
    error,
    startTextInput,
    stopTextInput,
    handleFoodParsed,
    handleConfirmFood,
    handleCancelConfirm,
    handleTextError,
    reset,
  };
}
