'use client';

import { useState, useEffect } from 'react';
import type { ParseFoodResponse } from '@/types';

interface FoodConfirmDialogProps {
  isOpen: boolean;
  foodData: ParseFoodResponse['data'] | null;
  isLoading: boolean;
  onConfirm: (data: { food: string; qty: number; unit: string; kcal: number }) => void;
  onCancel: () => void;
}

export function FoodConfirmDialog({ 
  isOpen, 
  foodData, 
  isLoading, 
  onConfirm, 
  onCancel 
}: FoodConfirmDialogProps) {
  const [editedFood, setEditedFood] = useState('');
  const [editedQty, setEditedQty] = useState(0);
  const [editedUnit, setEditedUnit] = useState('');
  const [editedKcal, setEditedKcal] = useState(0);
  const [originalKcalPerUnit, setOriginalKcalPerUnit] = useState(0);

  // Update local state when foodData changes
  useEffect(() => {
    if (foodData) {
      setEditedFood(foodData.food);
      setEditedQty(foodData.quantity);
      setEditedUnit(foodData.unit);
      setEditedKcal(foodData.kcal || 0);

      // Calculate calories per unit for automatic recalculation
      const kcalPerUnit = foodData.quantity > 0 ? (foodData.kcal || 0) / foodData.quantity : 0;
      setOriginalKcalPerUnit(kcalPerUnit);
    }
  }, [foodData]);

  // Recalculate calories when quantity changes
  useEffect(() => {
    if (originalKcalPerUnit > 0 && editedQty > 0) {
      const newKcal = Math.round(originalKcalPerUnit * editedQty);
      setEditedKcal(newKcal);
    } else if (editedQty === 0) {
      setEditedKcal(0);
    }
  }, [editedQty, originalKcalPerUnit]);

  const handleQuantityChange = (newQty: number) => {
    setEditedQty(newQty);
    // The useEffect above will automatically recalculate calories
  };

  const handleConfirm = () => {
    onConfirm({
      food: editedFood,
      qty: editedQty,
      unit: editedUnit,
      kcal: editedKcal,
    });
  };

  if (!isOpen) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-green-500/20 rounded-2xl border border-green-400/30">
              <svg className="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-white">Confirm Food Entry</h2>
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
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50 mx-auto mb-4"></div>
            <p className="text-white/70">Analyzing your food...</p>
          </div>
        ) : foodData ? (
          <div className="space-y-4">
            {/* Food Name */}
            <div>
              <label className="block text-sm font-medium text-white/80 mb-2">
                Food
              </label>
              <input
                type="text"
                value={editedFood}
                onChange={(e) => setEditedFood(e.target.value)}
                className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
              />
            </div>

            {/* Quantity and Unit */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Quantity
                </label>
                <input
                  type="number"
                  value={editedQty}
                  onChange={(e) => handleQuantityChange(Number(e.target.value))}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                  min="0"
                  step="0.1"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Unit
                </label>
                <select
                  value={editedUnit}
                  onChange={(e) => setEditedUnit(e.target.value)}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 backdrop-blur-sm transition-all"
                >
                  <option value="g" className="bg-gray-800 text-white">grams</option>
                  <option value="ml" className="bg-gray-800 text-white">ml</option>
                  <option value="cup" className="bg-gray-800 text-white">cup</option>
                  <option value="tbsp" className="bg-gray-800 text-white">tbsp</option>
                  <option value="tsp" className="bg-gray-800 text-white">tsp</option>
                  <option value="piece" className="bg-gray-800 text-white">piece</option>
                  <option value="slice" className="bg-gray-800 text-white">slice</option>
                  <option value="serving" className="bg-gray-800 text-white">serving</option>
                  <option value="oz" className="bg-gray-800 text-white">oz</option>
                  <option value="lb" className="bg-gray-800 text-white">lb</option>
                </select>
              </div>
            </div>

            {/* Calories */}
            <div>
              <label className="block text-sm font-medium text-white/80 mb-2">
                Calories
                <span className="text-xs text-white/50 ml-2">(auto-calculated)</span>
              </label>
              <input
                type="number"
                value={editedKcal}
                onChange={(e) => setEditedKcal(Number(e.target.value))}
                className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                min="0"
              />
              <p className="text-xs text-white/50 mt-1">
                Calories update automatically when you change the quantity
              </p>
            </div>

            {/* Notes */}
            {foodData.notes && (
              <div className="bg-blue-500/20 border border-blue-400/30 p-4 rounded-2xl backdrop-blur-sm">
                <p className="text-sm text-blue-300">
                  <strong>Note:</strong> {foodData.notes}
                </p>
              </div>
            )}

            {/* Summary */}
            <div className="bg-white/10 border border-white/20 p-4 rounded-2xl backdrop-blur-sm">
              <p className="text-sm text-white/80">
                <strong>Summary:</strong> {editedQty} {editedUnit} of {editedFood} = {editedKcal} calories
              </p>
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-6">
              <button
                onClick={handleConfirm}
                className="flex-1 bg-green-500/20 hover:bg-green-500/30 border border-green-400/30 hover:border-green-400/50 text-green-300 hover:text-green-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
              >
                Add to Log
              </button>
              <button
                onClick={onCancel}
                className="flex-1 bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="text-center py-8">
            <p className="text-red-400">Failed to parse food. Please try again.</p>
            <button
              onClick={onCancel}
              className="mt-4 bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white px-4 py-2 rounded-2xl transition-all duration-200 backdrop-blur-sm"
            >
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
