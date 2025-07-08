'use client';

import { useState } from 'react';
import { parseFood } from '@/utils/api';
import { addEntry } from '@/utils/idb';
import { useSettings } from '@/hooks/useSettings';
import type { ParseFoodResponse } from '@/types';

export function useVoiceInput() {
  const { settings } = useSettings();
  const [isListening, setIsListening] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [parsedFood, setParsedFood] = useState<ParseFoodResponse['data'] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const startListening = () => {
    setIsListening(true);
    setError(null);
    setParsedFood(null);
  };

  const stopListening = () => {
    setIsListening(false);
  };

  const handleTranscript = async (text: string) => {
    try {
      // Keep listening state true but set processing true to show processing screen
      setIsProcessing(true);
      setError(null);

      console.log('Processing transcript:', text);

      // Parse the food using OpenAI with user's units preference
      const response: ParseFoodResponse = await parseFood(text, settings.units);

      if (!response.success || !response.data) {
        throw new Error(response.error || 'Failed to parse food');
      }

      console.log('Parsed food:', response.data);

      // Now stop listening and show confirmation dialog
      setIsListening(false);
      setParsedFood(response.data);
      setShowConfirmDialog(true);

    } catch (err) {
      console.error('Voice processing error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to process voice input';
      setError(errorMessage);
      setIsListening(false);
    } finally {
      setIsProcessing(false);
    }
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
        method: 'voice',
        confidence: 0.9, // High confidence since user confirmed
      });

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

  const handleVoiceError = (error: string) => {
    console.error('Voice error:', error);
    setError(error);
    setIsListening(false);
  };

  const reset = () => {
    setIsListening(false);
    setIsProcessing(false);
    setShowConfirmDialog(false);
    setParsedFood(null);
    setError(null);
  };

  return {
    isListening,
    isProcessing,
    showConfirmDialog,
    parsedFood,
    error,
    startListening,
    stopListening,
    handleTranscript,
    handleConfirmFood,
    handleCancelConfirm,
    handleVoiceError,
    reset,
  };
}
