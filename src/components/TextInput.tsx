'use client';

import { useState, useEffect, useRef, useMemo } from 'react';
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
  const commonFoods = useMemo(() => [
    'apple', 'banana', 'orange', 'chicken breast', 'salmon', 'rice', 'pasta',
    'bread', 'egg', 'milk', 'yogurt', 'cheese', 'broccoli', 'spinach',
    'potato', 'sweet potato', 'avocado', 'almonds', 'oatmeal', 'quinoa'
  ], []);

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
    // User can click "Parse Food" button to parse the suggestion
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
      <div className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
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
              type="text"
              value={inputText}
              onChange={(e) => handleInputChange(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="e.g., 2 slices of bread, 1 apple, 100g chicken breast"
              className="w-full px-4 py-4 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all text-base"
              disabled={isLoading}
            />
          </div>

          {/* Suggestions */}
          {suggestions.length > 0 && (
            <div className="border border-white/20 rounded-2xl max-h-32 overflow-y-auto backdrop-blur-sm bg-white/5">
              {suggestions.map((suggestion, index) => (
                <button
                  key={index}
                  type="button"
                  onClick={() => handleSuggestionClick(suggestion)}
                  className="w-full text-left px-4 py-3 hover:bg-white/10 text-sm text-white/80 hover:text-white border-b border-white/10 last:border-b-0 transition-all"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          )}

          {/* Loading indicator */}
          {isLoading && (
            <div className="flex items-center justify-center py-4">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-400 mr-3"></div>
              <span className="text-sm text-white/80 font-medium">Analyzing...</span>
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
