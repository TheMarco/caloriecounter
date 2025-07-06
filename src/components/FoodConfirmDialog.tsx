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

  // Update local state when foodData changes
  useEffect(() => {
    if (foodData) {
      setEditedFood(foodData.food);
      setEditedQty(foodData.quantity);
      setEditedUnit(foodData.unit);
      setEditedKcal(foodData.kcal || 0);
    }
  }, [foodData]);

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
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
      <div className="bg-white rounded-lg p-6 m-4 max-w-md w-full">
        {/* Header */}
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">Confirm Food Entry</h2>
          <button
            onClick={onCancel}
            className="text-gray-500 hover:text-gray-700 text-xl font-bold"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p className="text-gray-600">Analyzing your food...</p>
          </div>
        ) : foodData ? (
          <div className="space-y-4">
            {/* Food Name */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Food
              </label>
              <input
                type="text"
                value={editedFood}
                onChange={(e) => setEditedFood(e.target.value)}
                className="w-full px-3 py-2 border-2 border-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600 text-gray-900 bg-white"
              />
            </div>

            {/* Quantity and Unit */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Quantity
                </label>
                <input
                  type="number"
                  value={editedQty}
                  onChange={(e) => setEditedQty(Number(e.target.value))}
                  className="w-full px-3 py-2 border-2 border-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600 text-gray-900 bg-white"
                  min="0"
                  step="0.1"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Unit
                </label>
                <select
                  value={editedUnit}
                  onChange={(e) => setEditedUnit(e.target.value)}
                  className="w-full px-3 py-2 border-2 border-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600 text-gray-900 bg-white"
                >
                  <option value="g">grams</option>
                  <option value="ml">ml</option>
                  <option value="cup">cup</option>
                  <option value="tbsp">tbsp</option>
                  <option value="tsp">tsp</option>
                  <option value="piece">piece</option>
                  <option value="slice">slice</option>
                  <option value="serving">serving</option>
                  <option value="oz">oz</option>
                  <option value="lb">lb</option>
                </select>
              </div>
            </div>

            {/* Calories */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Calories
              </label>
              <input
                type="number"
                value={editedKcal}
                onChange={(e) => setEditedKcal(Number(e.target.value))}
                className="w-full px-3 py-2 border-2 border-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-blue-600 text-gray-900 bg-white"
                min="0"
              />
            </div>

            {/* Notes */}
            {foodData.notes && (
              <div className="bg-blue-50 p-3 rounded">
                <p className="text-sm text-blue-700">
                  <strong>Note:</strong> {foodData.notes}
                </p>
              </div>
            )}

            {/* Summary */}
            <div className="bg-gray-50 p-3 rounded">
              <p className="text-sm text-gray-700">
                <strong>Summary:</strong> {editedQty} {editedUnit} of {editedFood} = {editedKcal} calories
              </p>
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-4">
              <button
                onClick={handleConfirm}
                className="flex-1 bg-green-500 hover:bg-green-600 text-white py-2 px-4 rounded-md font-medium"
              >
                Add to Log
              </button>
              <button
                onClick={onCancel}
                className="flex-1 bg-gray-500 hover:bg-gray-600 text-white py-2 px-4 rounded-md font-medium"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="text-center py-8">
            <p className="text-red-600">Failed to parse food. Please try again.</p>
            <button
              onClick={onCancel}
              className="mt-4 bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded"
            >
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
