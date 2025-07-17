'use client';

import { useState, useEffect } from 'react';

interface CalorieOffsetDialogProps {
  isOpen: boolean;
  currentOffset: number;
  isLoading: boolean;
  onSave: (offset: number) => void;
  onCancel: () => void;
}

export function CalorieOffsetDialog({
  isOpen,
  currentOffset,
  isLoading,
  onSave,
  onCancel
}: CalorieOffsetDialogProps) {
  const [offsetString, setOffsetString] = useState('');

  // Update local state when currentOffset changes
  useEffect(() => {
    if (isOpen) {
      // If offset is 0, show empty string so it appears as placeholder
      setOffsetString(currentOffset === 0 ? '' : currentOffset.toString());
    }
  }, [currentOffset, isOpen]);

  const handleOffsetChange = (value: string) => {
    // Allow empty string and numbers only
    if (value === '' || /^\d+$/.test(value)) {
      setOffsetString(value);
    }
  };

  const handleSave = () => {
    const numericValue = parseInt(offsetString) || 0;
    // Ensure non-negative value
    const validValue = Math.max(0, numericValue);
    onSave(validValue);
  };

  const handleKeyPress = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleSave();
    }
  };

  const handleFocus = () => {
    // Input is already empty for 0 values, so no need to clear
    // This function can remain for future enhancements if needed
  };

  if (!isOpen) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div data-testid="calorie-offset-dialog" className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-red-500/20 rounded-2xl border border-red-400/30">
              <svg className="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-white">Calories Burned</h2>
          </div>
          <button
            onClick={onCancel}
            className="text-white/60 hover:text-white text-xl font-bold p-2 rounded-xl hover:bg-white/10 transition-all"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-red-400 mx-auto mb-4"></div>
            <p className="text-white/70">Saving...</p>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Info */}
            <div className="bg-blue-500/10 border border-blue-400/30 rounded-2xl p-4">
              <div className="flex items-center space-x-3">
                <div className="flex-shrink-0">
                  <svg className="w-5 h-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div>
                  <h4 className="text-sm font-medium text-blue-400 mb-1">Exercise & Activity Offset</h4>
                  <p className="text-xs text-white/60">
                    Enter calories burned from exercise, gym, or other activities to see your net calorie intake.
                  </p>
                </div>
              </div>
            </div>

            {/* Calories Input */}
            <div>
              <label className="block text-sm font-medium text-white/80 mb-2">
                Calories Burned Today
              </label>
              <div className="relative">
                <input
                  data-testid="offset-input"
                  type="text"
                  inputMode="numeric"
                  value={offsetString}
                  onChange={(e) => handleOffsetChange(e.target.value)}
                  onKeyPress={handleKeyPress}
                  onFocus={handleFocus}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-red-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all text-center text-2xl font-semibold"
                  placeholder="0"
                  autoFocus
                />
                <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-white/60 text-sm">
                  calories
                </span>
              </div>
              <p className="text-xs text-white/50 mt-2 text-center">
                This will be subtracted from your food intake to show net calories
              </p>
            </div>

            {/* Preview */}
            {parseInt(offsetString) > 0 && (
              <div className="bg-green-500/10 border border-green-400/30 rounded-2xl p-4">
                <div className="text-center">
                  <p className="text-sm text-green-400 font-medium mb-1">
                    Net Calorie Calculation Preview
                  </p>
                  <p className="text-xs text-white/60">
                    Your food calories - {parseInt(offsetString) || 0} burned = Net intake
                  </p>
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex space-x-3 pt-4">
              <button
                onClick={onCancel}
                className="flex-1 px-4 py-3 border border-white/20 text-white/80 rounded-2xl hover:bg-white/5 transition-all font-medium"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex-1 px-4 py-3 bg-red-500 hover:bg-red-600 text-white rounded-2xl transition-all font-medium"
              >
                Save
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
