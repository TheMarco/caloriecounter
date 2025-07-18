'use client';

import { useState, useEffect } from 'react';
import type { ParseFoodResponse } from '@/types';

interface FoodConfirmDialogProps {
  isOpen: boolean;
  foodData: ParseFoodResponse['data'] | null;
  isLoading: boolean;
  onConfirm: (data: { food: string; qty: number; unit: string; kcal: number; fat?: number; carbs?: number; protein?: number }) => void;
  onCancel: () => void;
  method?: 'barcode' | 'voice' | 'text' | 'photo';
  onEditDetails?: () => void;
}

export function FoodConfirmDialog({
  isOpen,
  foodData,
  isLoading,
  onConfirm,
  onCancel,
  method,
  onEditDetails
}: FoodConfirmDialogProps) {
  const [editedFood, setEditedFood] = useState('');
  const [editedQty, setEditedQty] = useState(0);
  const [editedQtyString, setEditedQtyString] = useState('');
  const [editedUnit, setEditedUnit] = useState('');
  const [editedKcal, setEditedKcal] = useState(0);
  const [editedFat, setEditedFat] = useState(0);
  const [editedCarbs, setEditedCarbs] = useState(0);
  const [editedProtein, setEditedProtein] = useState(0);
  const [originalData, setOriginalData] = useState<{
    quantity: number;
    unit: string;
    kcal: number;
    fat?: number;
    carbs?: number;
    protein?: number;
  } | null>(null);

  // Unit conversion function
  const convertUnits = (fromQty: number, fromUnit: string, toUnit: string): number => {
    if (fromUnit === toUnit) return fromQty;

    // Convert everything to grams first, then to target unit
    let grams = fromQty;

    // Convert from original unit to grams
    switch (fromUnit) {
      case 'ml': grams = fromQty; break; // Assume 1ml = 1g for most foods
      case 'cup': grams = fromQty * 240; break; // 1 cup ≈ 240g
      case 'tbsp': grams = fromQty * 15; break; // 1 tbsp ≈ 15g
      case 'tsp': grams = fromQty * 5; break; // 1 tsp ≈ 5g
      case 'oz': grams = fromQty * 28.35; break; // 1 oz ≈ 28.35g
      case 'lb': grams = fromQty * 453.6; break; // 1 lb ≈ 453.6g
      case 'piece': case 'slice': grams = fromQty * 50; break; // Estimate for individual items
      case 'bowl': grams = fromQty * 250; break; // 1 bowl ≈ 250g (typical serving bowl)
      case 'plate': grams = fromQty * 300; break; // 1 plate ≈ 300g (typical dinner plate portion)
      case 'serving': grams = fromQty * 150; break; // 1 serving ≈ 150g (general estimate)
      default: grams = fromQty; // 'g' or unknown
    }

    // Convert from grams to target unit
    switch (toUnit) {
      case 'ml': return grams; // Assume 1g = 1ml for most foods
      case 'cup': return grams / 240;
      case 'tbsp': return grams / 15;
      case 'tsp': return grams / 5;
      case 'oz': return grams / 28.35;
      case 'lb': return grams / 453.6;
      case 'piece': case 'slice': return grams / 50;
      case 'bowl': return grams / 250;
      case 'plate': return grams / 300;
      case 'serving': return grams / 150;
      default: return grams; // 'g' or unknown
    }
  };

  // Update local state when foodData changes
  useEffect(() => {
    if (foodData) {
      setEditedFood(foodData.food);
      setEditedQty(foodData.quantity);
      setEditedQtyString(foodData.quantity === 0 ? '' : foodData.quantity.toString());
      setEditedUnit(foodData.unit);
      setEditedKcal(foodData.kcal || 0);
      setEditedFat(foodData.fat || 0);
      setEditedCarbs(foodData.carbs || 0);
      setEditedProtein(foodData.protein || 0);

      // Store original data for conversions
      setOriginalData({
        quantity: foodData.quantity,
        unit: foodData.unit,
        kcal: foodData.kcal || 0,
        fat: foodData.fat || 0,
        carbs: foodData.carbs || 0,
        protein: foodData.protein || 0,
      });
    }
  }, [foodData]);

  // Recalculate calories and macros when quantity or unit changes
  useEffect(() => {
    if (originalData && originalData.quantity > 0) {
      // Convert current quantity to original units to calculate nutrition
      const originalEquivalentQty = convertUnits(editedQty, editedUnit, originalData.unit);
      const ratio = originalEquivalentQty / originalData.quantity;

      const newKcal = Math.round(originalData.kcal * ratio);
      const newFat = Math.round((originalData.fat || 0) * ratio * 10) / 10;
      const newCarbs = Math.round((originalData.carbs || 0) * ratio * 10) / 10;
      const newProtein = Math.round((originalData.protein || 0) * ratio * 10) / 10;

      setEditedKcal(Math.max(0, newKcal));
      setEditedFat(Math.max(0, newFat));
      setEditedCarbs(Math.max(0, newCarbs));
      setEditedProtein(Math.max(0, newProtein));
    } else if (editedQty === 0) {
      setEditedKcal(0);
      setEditedFat(0);
      setEditedCarbs(0);
      setEditedProtein(0);
    }
  }, [editedQty, editedUnit, originalData]);

  const handleQuantityChange = (value: string) => {
    setEditedQtyString(value);

    // Convert to number for calculations
    const numValue = value === '' ? 0 : parseFloat(value) || 0;
    setEditedQty(numValue);
    // The useEffect above will automatically recalculate calories
  };

  const handleUnitChange = (newUnit: string) => {
    setEditedUnit(newUnit);
    // The useEffect above will automatically recalculate calories
  };

  const handleConfirm = () => {
    onConfirm({
      food: editedFood,
      qty: editedQty,
      unit: editedUnit,
      kcal: editedKcal,
      fat: editedFat,
      carbs: editedCarbs,
      protein: editedProtein,
    });
  };

  if (!isOpen) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div data-testid="food-confirm-dialog" className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
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
            {/* Photo Analysis Warning */}
            {method === 'photo' && (
              <div className="bg-orange-500/10 border border-orange-400/30 rounded-2xl p-4 mb-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="flex-shrink-0">
                      <svg className="w-5 h-5 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                    </div>
                    <h4 className="text-sm font-medium text-orange-400">AI visual best estimate</h4>
                  </div>
                  {onEditDetails && (
                    <button
                      onClick={onEditDetails}
                      className="px-3 py-1.5 bg-orange-500/20 hover:bg-orange-500/30 border border-orange-400/40 text-orange-300 text-xs rounded-lg transition-colors"
                    >
                      Add / Edit Details
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Food Name */}
            <div>
              <label className="block text-sm font-medium text-white/80 mb-2">
                Food
              </label>
              <input
                data-testid="confirm-food-name-input"
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
                  data-testid="confirm-quantity-input"
                  type="text"
                  inputMode="decimal"
                  value={editedQtyString}
                  onChange={(e) => handleQuantityChange(e.target.value)}
                  onBlur={(e) => {
                    // Clean up the input on blur - remove leading zeros, ensure valid number
                    const numValue = parseFloat(e.target.value) || 0;
                    const cleanValue = numValue.toString();
                    setEditedQtyString(cleanValue);
                    setEditedQty(numValue);
                  }}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                  placeholder="0"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Unit
                </label>
                <select
                  value={editedUnit}
                  onChange={(e) => handleUnitChange(e.target.value)}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 backdrop-blur-sm transition-all"
                >
                  <option value="g" className="bg-gray-800 text-white">grams</option>
                  <option value="ml" className="bg-gray-800 text-white">ml</option>
                  <option value="cup" className="bg-gray-800 text-white">cup</option>
                  <option value="tbsp" className="bg-gray-800 text-white">tbsp</option>
                  <option value="tsp" className="bg-gray-800 text-white">tsp</option>
                  <option value="piece" className="bg-gray-800 text-white">piece</option>
                  <option value="slice" className="bg-gray-800 text-white">slice</option>
                  <option value="bowl" className="bg-gray-800 text-white">bowl</option>
                  <option value="plate" className="bg-gray-800 text-white">plate</option>
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
                value={editedKcal === 0 ? '' : editedKcal}
                onChange={(e) => setEditedKcal(e.target.value === '' ? 0 : Number(e.target.value))}
                className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                min="0"
                placeholder="0"
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
                data-testid="confirm-button"
                onClick={handleConfirm}
                className="flex-1 bg-green-500/20 hover:bg-green-500/30 border border-green-400/30 hover:border-green-400/50 text-green-300 hover:text-green-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
              >
                Add to Log
              </button>
              <button
                data-testid="cancel-button"
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
