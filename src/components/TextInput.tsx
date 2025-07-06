'use client';

import { useState, useEffect, useRef } from 'react';
import { parseFood } from '@/utils/api';
import type { ParseFoodResponse } from '@/types';

interface TextInputProps {
  onFoodParsed: (data: ParseFoodResponse['data']) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
}

export function TextInput({ onFoodParsed, onError, onClose, isActive }: TextInputProps) {
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Common food suggestions
  const commonFoods = [
    'apple', 'banana', 'orange', 'chicken breast', 'salmon', 'rice', 'pasta',
    'bread', 'egg', 'milk', 'yogurt', 'cheese', 'broccoli', 'spinach',
    'potato', 'sweet potato', 'avocado', 'almonds', 'oatmeal', 'quinoa'
  ];

  useEffect(() => {
    if (isActive && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isActive]);

  useEffect(() => {
    if (inputText.length >= 2) {
      const filtered = commonFoods.filter(food => 
        food.toLowerCase().includes(inputText.toLowerCase())
      );
      setSuggestions(filtered.slice(0, 5));
    } else {
      setSuggestions([]);
    }
  }, [inputText]);

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

      const response: ParseFoodResponse = await parseFood(inputText.trim());

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

  const handleSuggestionClick = (suggestion: string) => {
    setInputText(suggestion);
    setSuggestions([]);
    handleAutoparse(suggestion);
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
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
      <div className="bg-white rounded-lg p-6 m-4 max-w-md w-full">
        {/* Header */}
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">Add Food</h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 text-xl font-bold"
          >
            ✕
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              What did you eat?
            </label>
            <input
              ref={inputRef}
              type="text"
              value={inputText}
              onChange={(e) => handleInputChange(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="e.g., 2 slices of bread, 1 apple, 100g chicken breast"
              className="w-full px-3 py-2 border-2 border-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600 text-gray-900 bg-white placeholder-gray-500"
              disabled={isLoading}
            />
          </div>

          {/* Suggestions */}
          {suggestions.length > 0 && (
            <div className="border-2 border-gray-300 rounded-md max-h-32 overflow-y-auto">
              {suggestions.map((suggestion, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => handleSuggestionClick(suggestion)}
                  className="w-full text-left px-3 py-2 hover:bg-gray-100 text-sm text-gray-900 border-b border-gray-200 last:border-b-0"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          )}

          {/* Loading indicator */}
          {isLoading && (
            <div className="flex items-center justify-center py-2">
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-500 mr-2"></div>
              <span className="text-sm text-gray-900 font-medium">Analyzing...</span>
            </div>
          )}

          {/* Instructions */}
          <div className="text-xs text-gray-700">
            <p className="font-medium">Examples:</p>
            <ul className="list-disc list-inside mt-1 space-y-1">
              <li>&quot;2 slices of whole wheat bread&quot;</li>
              <li>&quot;1 medium apple&quot;</li>
              <li>&quot;100g grilled chicken breast&quot;</li>
              <li>&quot;1 cup of cooked rice&quot;</li>
            </ul>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={!inputText.trim() || isLoading}
              className="flex-1 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-300 text-white py-2 px-4 rounded-md font-medium"
            >
              {isLoading ? 'Analyzing...' : 'Parse Food'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-gray-500 hover:bg-gray-600 text-white py-2 px-4 rounded-md font-medium"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
