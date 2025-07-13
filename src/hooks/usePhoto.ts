import { useState } from 'react';
import { addEntry } from '@/utils/idb';

// API function to parse photo
async function parsePhoto(imageData: string, units: 'metric' | 'imperial' = 'metric', details?: { plateSize: string; servingType: string; additionalDetails: string }) {
  console.log('📡 parsePhoto called with image size:', imageData.length, 'units:', units, 'details:', details);

  const response = await fetch('/api/parse-photo', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ imageData, units, details }),
  });

  console.log('📡 API response status:', response.status);

  if (!response.ok) {
    const errorText = await response.text();
    console.error('📡 API error response:', errorText);
    throw new Error(`HTTP error! status: ${response.status}, body: ${errorText}`);
  }

  const result = await response.json();
  console.log('📡 API response data:', result);
  return result;
}

export function usePhoto() {
  const [isCapturing, setIsCapturing] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [parsedFood, setParsedFood] = useState<{ 
    food: string; 
    quantity: number; 
    unit: string; 
    kcal: number; 
    fat?: number; 
    carbs?: number; 
    protein?: number; 
    notes?: string 
  } | null>(null);

  const startCapture = () => {
    setIsCapturing(true);
    setError(null);
  };

  const stopCapture = () => {
    console.log('🛑 usePhoto: Stopping capture');
    setIsCapturing(false);
  };

  const handlePhotoCapture = async (imageData: string, units: 'metric' | 'imperial' = 'metric', details?: { plateSize: string; servingType: string; additionalDetails: string }) => {
    try {
      console.log('📸 Starting photo processing, image size:', imageData.length);
      console.log('📸 Image data preview:', imageData.substring(0, 100) + '...');

      // Check image size (5MB limit for better API performance)
      if (imageData.length > 5 * 1024 * 1024) {
        throw new Error('Image too large. Please try taking a smaller photo.');
      }

      setIsProcessing(true);
      setError(null);

      // Stop capturing and show processing state
      stopCapture();

      console.log('📡 Analyzing photo with OpenAI Vision, units:', units);

      // Parse the photo using OpenAI Vision API
      const response = await parsePhoto(imageData, units, details);
      console.log('📡 Photo API response:', response);

      if (!response.success || !response.data) {
        console.error('❌ Photo analysis failed:', response.error);

        // Check if it's a food recognition error and provide user-friendly message
        const errorMsg = response.error || 'Failed to analyze photo';
        if (errorMsg.includes('Cannot clearly identify food') ||
            errorMsg.includes('No food visible') ||
            errorMsg.includes('not food')) {
          throw new Error('We couldn\'t identify any food in this photo. Please try taking a clearer picture of your meal, or make sure the food is well-lit and clearly visible.');
        }

        throw new Error(errorMsg);
      }

      const { food, quantity, unit, kcal, fat, carbs, protein, notes } = response.data;
      console.log('🍽️ Food data:', { food, quantity, unit, kcal, fat, carbs, protein });

      // Prepare food data for confirmation dialog
      const foodData = {
        food,
        quantity,
        unit,
        kcal: Math.round(kcal),
        fat: fat || 0,
        carbs: carbs || 0,
        protein: protein || 0,
        notes: notes || `Photo analysis: ${food}`
      };

      setParsedFood(foodData);
      setShowConfirmDialog(true);
      console.log('📋 Showing confirmation dialog with data:', foodData);

    } catch (err) {
      console.error('❌ Failed to process photo:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to analyze photo';
      setError(errorMessage);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleConfirmFood = async (data: { 
    food: string; 
    qty: number; 
    unit: string; 
    kcal: number; 
    fat?: number; 
    carbs?: number; 
    protein?: number 
  }) => {
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
        method: 'photo',
        confidence: 0.9, // High confidence - photo analysis is working well
      });

      console.log('Entry created:', entry);

      // Close dialog
      setShowConfirmDialog(false);
      setParsedFood(null);

      return entry;

    } catch (err) {
      console.error('❌ Failed to save photo entry:', err);
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
    setError(null); // Clear any errors
  };

  const handleCaptureError = (error: string) => {
    console.error('Photo capture error:', error);
    setError(error);
  };

  return {
    isCapturing,
    isProcessing,
    error,
    showConfirmDialog,
    parsedFood,
    startCapture,
    stopCapture,
    handlePhotoCapture,
    handleCaptureError,
    handleConfirmFood,
    handleCancelConfirm,
  };
}
