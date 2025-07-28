'use client';

import { useState, useEffect, useRef, useMemo } from 'react';
import { parseFood } from '@/utils/api';
import { searchPreviousFood } from '@/utils/idb';
import type { ParseFoodResponse, Entry } from '@/types';

interface TextInputProps {
  onFoodParsed: (data: ParseFoodResponse['data']) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
  units?: 'metric' | 'imperial';
  error?: string | null;
}

export function TextInput({ onFoodParsed, onError, onClose, isActive, units = 'metric', error }: TextInputProps) {
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [suggestions, setSuggestions] = useState<typeof commonFoods>([]);
  const [previousEntries, setPreviousEntries] = useState<Entry[]>([]);
  const [showPreviousEntries, setShowPreviousEntries] = useState(false);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Comprehensive USDA-based common foods database
  const commonFoods = useMemo(() => [
    // Fruits
    { name: 'apple', qty: 1, unit: 'piece', kcal: 95, fat: 0.3, carbs: 25, protein: 0.5 },
    { name: 'banana', qty: 1, unit: 'piece', kcal: 105, fat: 0.4, carbs: 27, protein: 1.3 },
    { name: 'orange', qty: 1, unit: 'piece', kcal: 62, fat: 0.2, carbs: 15.4, protein: 1.2 },
    { name: 'grapes', qty: 100, unit: 'g', kcal: 62, fat: 0.2, carbs: 16, protein: 0.6 },
    { name: 'strawberries', qty: 100, unit: 'g', kcal: 32, fat: 0.3, carbs: 7.7, protein: 0.7 },
    { name: 'blueberries', qty: 100, unit: 'g', kcal: 57, fat: 0.3, carbs: 14.5, protein: 0.7 },
    { name: 'pineapple', qty: 100, unit: 'g', kcal: 50, fat: 0.1, carbs: 13.1, protein: 0.5 },
    { name: 'mango', qty: 100, unit: 'g', kcal: 60, fat: 0.4, carbs: 15, protein: 0.8 },
    { name: 'watermelon', qty: 100, unit: 'g', kcal: 30, fat: 0.2, carbs: 7.6, protein: 0.6 },
    { name: 'avocado', qty: 0.5, unit: 'piece', kcal: 160, fat: 14.7, carbs: 8.5, protein: 2 },

    // Vegetables
    { name: 'broccoli', qty: 100, unit: 'g', kcal: 34, fat: 0.4, carbs: 7, protein: 2.8 },
    { name: 'spinach', qty: 100, unit: 'g', kcal: 23, fat: 0.4, carbs: 3.6, protein: 2.9 },
    { name: 'carrots', qty: 100, unit: 'g', kcal: 41, fat: 0.2, carbs: 9.6, protein: 0.9 },
    { name: 'bell pepper', qty: 100, unit: 'g', kcal: 31, fat: 0.3, carbs: 7, protein: 1 },
    { name: 'cucumber', qty: 100, unit: 'g', kcal: 16, fat: 0.1, carbs: 4, protein: 0.7 },
    { name: 'tomato', qty: 1, unit: 'piece', kcal: 22, fat: 0.2, carbs: 4.8, protein: 1.1 },
    { name: 'lettuce', qty: 100, unit: 'g', kcal: 15, fat: 0.2, carbs: 2.9, protein: 1.4 },
    { name: 'onion', qty: 100, unit: 'g', kcal: 40, fat: 0.1, carbs: 9.3, protein: 1.1 },
    { name: 'mushrooms', qty: 100, unit: 'g', kcal: 22, fat: 0.3, carbs: 3.3, protein: 3.1 },
    { name: 'zucchini', qty: 100, unit: 'g', kcal: 17, fat: 0.3, carbs: 3.1, protein: 1.2 },

    // Proteins
    { name: 'chicken breast', qty: 100, unit: 'g', kcal: 165, fat: 3.6, carbs: 0, protein: 31 },
    { name: 'chicken thigh', qty: 100, unit: 'g', kcal: 209, fat: 10.9, carbs: 0, protein: 26 },
    { name: 'ground beef', qty: 100, unit: 'g', kcal: 250, fat: 20, carbs: 0, protein: 17 },
    { name: 'salmon', qty: 100, unit: 'g', kcal: 208, fat: 12.4, carbs: 0, protein: 22.1 },
    { name: 'tuna', qty: 100, unit: 'g', kcal: 144, fat: 4.9, carbs: 0, protein: 23 },
    { name: 'shrimp', qty: 100, unit: 'g', kcal: 99, fat: 0.3, carbs: 0.2, protein: 24 },
    { name: 'turkey breast', qty: 100, unit: 'g', kcal: 135, fat: 1, carbs: 0, protein: 30 },
    { name: 'pork chop', qty: 100, unit: 'g', kcal: 231, fat: 14, carbs: 0, protein: 25 },
    { name: 'egg', qty: 1, unit: 'piece', kcal: 70, fat: 5, carbs: 0.6, protein: 6 },
    { name: 'tofu', qty: 100, unit: 'g', kcal: 76, fat: 4.8, carbs: 1.9, protein: 8 },

    // Dairy
    { name: 'milk', qty: 250, unit: 'ml', kcal: 150, fat: 8, carbs: 12, protein: 8 },
    { name: 'greek yogurt', qty: 150, unit: 'g', kcal: 100, fat: 0.4, carbs: 6, protein: 17 },
    { name: 'yogurt', qty: 150, unit: 'g', kcal: 150, fat: 8, carbs: 17, protein: 8 },
    { name: 'cheddar cheese', qty: 30, unit: 'g', kcal: 113, fat: 9, carbs: 1, protein: 7 },
    { name: 'mozzarella cheese', qty: 30, unit: 'g', kcal: 85, fat: 6.3, carbs: 0.6, protein: 6.3 },
    { name: 'cottage cheese', qty: 100, unit: 'g', kcal: 98, fat: 4.3, carbs: 3.4, protein: 11 },
    { name: 'cream cheese', qty: 30, unit: 'g', kcal: 99, fat: 9.9, carbs: 1.6, protein: 1.8 },
    { name: 'butter', qty: 10, unit: 'g', kcal: 72, fat: 8.1, carbs: 0.1, protein: 0.1 },

    // Grains & Starches
    { name: 'white rice', qty: 100, unit: 'g', kcal: 130, fat: 0.3, carbs: 28, protein: 2.7 },
    { name: 'brown rice', qty: 100, unit: 'g', kcal: 111, fat: 0.9, carbs: 23, protein: 2.6 },
    { name: 'pasta', qty: 100, unit: 'g', kcal: 131, fat: 1.1, carbs: 25, protein: 5 },
    { name: 'white bread', qty: 1, unit: 'slice', kcal: 80, fat: 1, carbs: 14, protein: 4 },
    { name: 'whole wheat bread', qty: 1, unit: 'slice', kcal: 80, fat: 1.5, carbs: 14, protein: 4 },
    { name: 'oatmeal', qty: 40, unit: 'g', kcal: 150, fat: 3, carbs: 27, protein: 5 },
    { name: 'quinoa', qty: 100, unit: 'g', kcal: 120, fat: 1.9, carbs: 22, protein: 4.4 },
    { name: 'potato', qty: 150, unit: 'g', kcal: 116, fat: 0.1, carbs: 26, protein: 2 },
    { name: 'sweet potato', qty: 150, unit: 'g', kcal: 129, fat: 0.2, carbs: 30, protein: 2.3 },
    { name: 'bagel', qty: 1, unit: 'piece', kcal: 245, fat: 1.5, carbs: 48, protein: 10 },
    { name: 'tortilla', qty: 1, unit: 'piece', kcal: 104, fat: 2.5, carbs: 18, protein: 3 },

    // Nuts & Seeds
    { name: 'almonds', qty: 30, unit: 'g', kcal: 174, fat: 15, carbs: 6.1, protein: 6.4 },
    { name: 'walnuts', qty: 30, unit: 'g', kcal: 196, fat: 19.5, carbs: 4.1, protein: 4.6 },
    { name: 'peanuts', qty: 30, unit: 'g', kcal: 161, fat: 13.9, carbs: 4.6, protein: 7.3 },
    { name: 'cashews', qty: 30, unit: 'g', kcal: 157, fat: 12.4, carbs: 8.6, protein: 5.2 },
    { name: 'peanut butter', qty: 32, unit: 'g', kcal: 188, fat: 16, carbs: 8, protein: 8 },
    { name: 'sunflower seeds', qty: 30, unit: 'g', kcal: 164, fat: 14.1, carbs: 6.8, protein: 5.8 },

    // Legumes
    { name: 'black beans', qty: 100, unit: 'g', kcal: 132, fat: 0.5, carbs: 24, protein: 8.9 },
    { name: 'chickpeas', qty: 100, unit: 'g', kcal: 164, fat: 2.6, carbs: 27, protein: 8.9 },
    { name: 'lentils', qty: 100, unit: 'g', kcal: 116, fat: 0.4, carbs: 20, protein: 9 },
    { name: 'kidney beans', qty: 100, unit: 'g', kcal: 127, fat: 0.5, carbs: 23, protein: 8.7 },

    // Beverages & Others
    { name: 'coffee', qty: 240, unit: 'ml', kcal: 2, fat: 0, carbs: 0, protein: 0.3 },
    { name: 'tea', qty: 240, unit: 'ml', kcal: 2, fat: 0, carbs: 0.7, protein: 0 },
    { name: 'orange juice', qty: 240, unit: 'ml', kcal: 112, fat: 0.5, carbs: 26, protein: 1.7 },
    { name: 'apple juice', qty: 240, unit: 'ml', kcal: 114, fat: 0.3, carbs: 28, protein: 0.2 },
    { name: 'olive oil', qty: 15, unit: 'ml', kcal: 119, fat: 13.5, carbs: 0, protein: 0 },
    { name: 'coconut oil', qty: 15, unit: 'ml', kcal: 121, fat: 13.5, carbs: 0, protein: 0 },
    { name: 'honey', qty: 21, unit: 'g', kcal: 64, fat: 0, carbs: 17.3, protein: 0.1 },
    { name: 'sugar', qty: 12, unit: 'g', kcal: 49, fat: 0, carbs: 12.6, protein: 0 },

    // Snacks & Processed
    { name: 'dark chocolate', qty: 30, unit: 'g', kcal: 155, fat: 8.8, carbs: 17, protein: 2.3 },
    { name: 'milk chocolate', qty: 30, unit: 'g', kcal: 151, fat: 8.7, carbs: 17.1, protein: 2.2 },
    { name: 'granola bar', qty: 1, unit: 'piece', kcal: 118, fat: 4.9, carbs: 15.8, protein: 2.4 },
    { name: 'crackers', qty: 5, unit: 'piece', kcal: 62, fat: 2.5, carbs: 9.1, protein: 1.1 },
    { name: 'popcorn', qty: 30, unit: 'g', kcal: 106, fat: 1.2, carbs: 21.8, protein: 3.4 },
    { name: 'pretzels', qty: 30, unit: 'g', kcal: 108, fat: 0.8, carbs: 22.5, protein: 2.8 },

    // Fast Food Basics
    { name: 'pizza slice', qty: 1, unit: 'slice', kcal: 285, fat: 10.4, carbs: 36, protein: 12.2 },
    { name: 'hamburger', qty: 1, unit: 'piece', kcal: 540, fat: 31, carbs: 40, protein: 25 },
    { name: 'french fries', qty: 100, unit: 'g', kcal: 365, fat: 17, carbs: 63, protein: 4 },
    { name: 'chicken nuggets', qty: 4, unit: 'piece', kcal: 190, fat: 12, carbs: 11, protein: 12 },
  ], []);

  useEffect(() => {
    if (isActive && inputRef.current) {
      // Reset input text when dialog opens
      setInputText('');
      setSuggestions([]);
      setPreviousEntries([]);
      setShowPreviousEntries(false);
      inputRef.current.focus();
    }
  }, [isActive]);

  useEffect(() => {
    const updateSuggestions = async () => {
      if (inputText.length >= 2) {
        // Search previous entries first (increased limit to show more frequent foods)
        const previousMatches = await searchPreviousFood(inputText, 10);
        setPreviousEntries(previousMatches);

        // Also get common food suggestions
        const filtered = commonFoods.filter(food =>
          food.name.toLowerCase().includes(inputText.toLowerCase())
        );
        setSuggestions(filtered.slice(0, 5));

        setShowPreviousEntries(previousMatches.length > 0);
      } else {
        setSuggestions([]);
        setPreviousEntries([]);
        setShowPreviousEntries(false);
      }
    };

    updateSuggestions();
  }, [inputText, commonFoods]);

  const handleInputChange = (value: string) => {
    setInputText(value);

    // Clear any existing debounce
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    // No auto-parsing - only parse when user clicks "Parse Food" button
  };



  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!inputText.trim()) return;

    try {
      setIsLoading(true);
      console.log('Manual parsing:', inputText.trim());

      const response: ParseFoodResponse = await parseFood(inputText.trim(), units);

      if (!response.success || !response.data) {
        throw new Error(response.error || 'Failed to parse food');
      }

      onFoodParsed(response.data);
    } catch (err) {
      console.error('Parse error:', err);
      const errorMessage = err instanceof Error ? err.message : 'Failed to parse food';
      onError?.(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSuggestionClick = (suggestion: typeof commonFoods[0]) => {
    // Directly use the common food data without AI parsing
    const data = {
      food: suggestion.name,
      quantity: suggestion.qty,
      unit: suggestion.unit,
      kcal: suggestion.kcal,
      fat: suggestion.fat,
      carbs: suggestion.carbs,
      protein: suggestion.protein,
    };

    onFoodParsed(data);
  };

  const handlePreviousEntryClick = (entry: Entry) => {
    // Directly use the previous entry data without AI parsing
    const data = {
      food: entry.food,
      quantity: entry.qty,
      unit: entry.unit,
      kcal: entry.kcal,
      fat: entry.fat,
      carbs: entry.carbs,
      protein: entry.protein,
    };

    onFoodParsed(data);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    }
  };

  if (!isActive) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div data-testid="text-input-dialog" className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-purple-500/20 rounded-2xl border border-purple-400/30">
              <svg className="w-6 h-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-white">Add Food</h2>
          </div>
          <button
            data-testid="text-close-button"
            onClick={onClose}
            className="text-white/60 hover:text-white text-xl font-bold p-2 rounded-xl hover:bg-white/10 transition-all"
          >
            ✕
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-white/80 mb-3">
              What did you eat?
            </label>
            <input
              ref={inputRef}
              data-testid="text-input-field"
              type="text"
              value={inputText}
              onChange={(e) => handleInputChange(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="e.g., 2 slices of bread, 1 apple, 100g chicken breast"
              className="w-full px-4 py-4 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all text-base"
              disabled={isLoading}
            />
          </div>

          {/* Previous Entries */}
          {showPreviousEntries && previousEntries.length > 0 && (
            <div className="space-y-2">
              <h3 className="text-sm font-medium text-white/80 px-1">Foods Entered Previously</h3>
              <div className="border border-white/20 rounded-2xl max-h-40 overflow-y-auto backdrop-blur-sm bg-white/5">
                {previousEntries.map((entry) => (
                  <button
                    key={entry.id}
                    type="button"
                    onClick={() => handlePreviousEntryClick(entry)}
                    className="w-full text-left px-4 py-3 hover:bg-white/10 text-sm text-white/80 hover:text-white border-b border-white/10 last:border-b-0 transition-all"
                  >
                    <div className="flex justify-between items-center">
                      <span className="font-medium">{entry.food}</span>
                      <span className="text-xs text-white/60">{entry.kcal} kcal</span>
                    </div>
                    <div className="text-xs text-white/50 mt-1">
                      {entry.qty} {entry.unit} • {entry.fat}g fat, {entry.carbs}g carbs, {entry.protein}g protein
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Common Food Suggestions */}
          {suggestions.length > 0 && (
            <div className="space-y-2">
              <h3 className="text-sm font-medium text-white/80 px-1">Common Foods</h3>
              <div className="border border-white/20 rounded-2xl max-h-32 overflow-y-auto backdrop-blur-sm bg-white/5">
                {suggestions.map((suggestion, index) => (
                  <button
                    key={index}
                    type="button"
                    onClick={() => handleSuggestionClick(suggestion)}
                    className="w-full text-left px-4 py-3 hover:bg-white/10 text-sm text-white/80 hover:text-white border-b border-white/10 last:border-b-0 transition-all"
                  >
                    <div className="flex justify-between items-center">
                      <span className="font-medium capitalize">{suggestion.name}</span>
                      <span className="text-xs text-white/60">{suggestion.kcal} kcal</span>
                    </div>
                    <div className="text-xs text-white/50 mt-1">
                      {suggestion.qty} {suggestion.unit} • {suggestion.fat}g fat, {suggestion.carbs}g carbs, {suggestion.protein}g protein
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Loading indicator */}
          {isLoading && (
            <div className="flex items-center justify-center py-4">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-400 mr-3"></div>
              <span className="text-sm text-white/80 font-medium">Analyzing...</span>
            </div>
          )}

          {/* Error message */}
          {error && (
            <div data-testid="error-message" className="bg-red-500/20 border border-red-400/30 text-red-300 p-4 rounded-2xl backdrop-blur-sm">
              <div className="flex items-center space-x-2">
                <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span className="text-sm font-medium">{error}</span>
              </div>
            </div>
          )}

          {/* Instructions */}
          <div className="text-xs text-white/60 bg-white/5 border border-white/10 rounded-2xl p-4 backdrop-blur-sm">
            <p className="font-medium text-white/80 mb-2">Examples:</p>
            <ul className="list-disc list-inside space-y-1">
              <li>&quot;2 slices of whole wheat bread&quot;</li>
              <li>&quot;1 medium apple&quot;</li>
              <li>&quot;100g grilled chicken breast&quot;</li>
              <li>&quot;1 cup of cooked rice&quot;</li>
            </ul>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-6">
            <button
              type="submit"
              data-testid="text-submit-button"
              disabled={!inputText.trim() || isLoading}
              className="flex-1 bg-purple-500/20 hover:bg-purple-500/30 disabled:bg-white/5 disabled:text-white/40 border border-purple-400/30 hover:border-purple-400/50 disabled:border-white/10 text-purple-300 hover:text-purple-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:scale-100"
            >
              {isLoading ? 'Analyzing...' : 'Parse Food'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
