'use client';

import { useState, useEffect } from 'react';
import type { Entry } from '@/types';
import { UNITS } from '@/types';

interface EditEntryDialogProps {
  isOpen: boolean;
  entry: Entry | null;
  isLoading: boolean;
  onSave: (entry: Entry) => void;
  onCancel: () => void;
}

export function EditEntryDialog({ 
  isOpen, 
  entry, 
  isLoading, 
  onSave, 
  onCancel 
}: EditEntryDialogProps) {
  const [editedFood, setEditedFood] = useState('');
  const [editedQty, setEditedQty] = useState(0);
  const [editedQtyString, setEditedQtyString] = useState('');
  const [editedUnit, setEditedUnit] = useState('');
  const [editedKcal, setEditedKcal] = useState(0);
  const [originalKcalPerUnit, setOriginalKcalPerUnit] = useState(0);

  // Update local state when entry changes
  useEffect(() => {
    if (entry) {
      setEditedFood(entry.food);
      setEditedQty(entry.qty);
      setEditedQtyString(entry.qty === 0 ? '' : entry.qty.toString());
      setEditedUnit(entry.unit);
      setEditedKcal(entry.kcal);

      // Calculate calories per unit for automatic recalculation
      const kcalPerUnit = entry.qty > 0 ? entry.kcal / entry.qty : 0;
      setOriginalKcalPerUnit(kcalPerUnit);
    }
  }, [entry]);

  // Recalculate calories when quantity changes
  useEffect(() => {
    if (originalKcalPerUnit > 0 && editedQty > 0) {
      const newKcal = Math.round(originalKcalPerUnit * editedQty);
      setEditedKcal(newKcal);
    } else if (editedQty === 0) {
      setEditedKcal(0);
    }
  }, [editedQty, originalKcalPerUnit]);

  const handleQuantityChange = (value: string) => {
    setEditedQtyString(value);
    
    // Convert to number for calculations
    const numValue = value === '' ? 0 : parseFloat(value) || 0;
    setEditedQty(numValue);
  };

  const handleSave = () => {
    if (!entry) return;
    
    const updatedEntry: Entry = {
      ...entry,
      food: editedFood,
      qty: editedQty,
      unit: editedUnit,
      kcal: editedKcal,
    };
    
    onSave(updatedEntry);
  };

  if (!isOpen || !entry) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-blue-500/20 rounded-2xl border border-blue-400/30">
              <svg className="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-white">Edit Entry</h2>
          </div>
          <button
            onClick={onCancel}
            className="p-2 text-white/60 hover:text-white transition-colors rounded-xl hover:bg-white/10"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        {isLoading ? (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50 mx-auto mb-4"></div>
            <p className="text-white/70">Saving changes...</p>
          </div>
        ) : (
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
                  type="text"
                  inputMode="decimal"
                  value={editedQtyString}
                  onChange={(e) => handleQuantityChange(e.target.value)}
                  onBlur={(e) => {
                    // Clean up the input on blur
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
                  onChange={(e) => setEditedUnit(e.target.value)}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 backdrop-blur-sm transition-all"
                >
                  {UNITS.map((unit) => (
                    <option key={unit} value={unit} className="bg-gray-800 text-white">
                      {unit}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {/* Calories */}
            <div>
              <label className="block text-sm font-medium text-white/80 mb-2">
                Calories
              </label>
              <input
                type="number"
                value={editedKcal === 0 ? '' : editedKcal}
                onChange={(e) => setEditedKcal(e.target.value === '' ? 0 : Number(e.target.value))}
                className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                min="0"
                placeholder="0"
              />
            </div>

            {/* Summary */}
            <div className="bg-white/10 border border-white/20 p-4 rounded-2xl backdrop-blur-sm">
              <p className="text-sm text-white/80">
                <strong>Summary:</strong> {editedQty} {editedUnit} of {editedFood} = {editedKcal} calories
              </p>
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-6">
              <button
                onClick={handleSave}
                disabled={!editedFood.trim() || editedQty <= 0}
                className="flex-1 bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
              >
                Save Changes
              </button>
              <button
                onClick={onCancel}
                className="flex-1 bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
