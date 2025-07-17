'use client';

import { useState, useEffect } from 'react';
import { getTodayCalorieOffset } from '@/utils/idb';

interface CalorieOffsetProps {
  onOffsetChange?: (offset: number) => void;
  onEditClick?: () => void;
  currentOffset?: number; // Allow parent to update the displayed offset
}

export function CalorieOffset({ onOffsetChange, onEditClick, currentOffset }: CalorieOffsetProps) {
  const [offset, setOffset] = useState<number>(0);
  const [isLoading, setIsLoading] = useState(true);

  // Load current offset on mount only if parent doesn't provide one
  useEffect(() => {
    const loadOffset = async () => {
      try {
        if (currentOffset !== undefined) {
          // Use parent's value
          setOffset(currentOffset);
        } else {
          // Load from storage
          const storedOffset = await getTodayCalorieOffset();
          setOffset(storedOffset);
        }
      } catch (error) {
        console.error('Failed to load calorie offset:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadOffset();
  }, [currentOffset]);

  // Update offset when parent provides a new value
  useEffect(() => {
    if (currentOffset !== undefined) {
      setOffset(currentOffset);
    }
  }, [currentOffset]);

  const handleEditClick = () => {
    onEditClick?.();
  };

  if (isLoading) {
    return (
      <div className="card-glass card-glass-hover rounded-3xl mb-6 transition-all duration-300 shadow-2xl">
        <div className="p-6 border-b border-white/20">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-red-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div>
              <h3 className="text-xl font-semibold text-white">Calories Burned</h3>
              <p className="text-white/60 text-sm">Loading...</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="card-glass card-glass-hover rounded-3xl mb-6 transition-all duration-300 shadow-2xl">
      <div className="p-6 border-b border-white/20">
        <div className="flex items-center space-x-4">
          <div className="p-3 bg-red-500/20 rounded-2xl">
            <svg className="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          </div>
          <div>
            <h3 className="text-xl font-semibold text-white">Calories Burned</h3>
            <p className="text-white/60 text-sm">Exercise & activity offset</p>
          </div>
        </div>
      </div>
      
      <div className="p-6">
        <div className="flex items-center justify-between">
          <div className="flex-1">
            <div className="text-center">
              <div className="text-4xl font-bold text-red-400 mb-2">
                {offset.toLocaleString()}
              </div>
              <p className="text-lg text-white/80 font-medium">calories burned</p>
            </div>

            <div className="text-center mt-4">
              <p className="text-sm text-white/60">
                {offset === 0 ? 'No workout logged today' : `${offset} calories burned today`}
              </p>
            </div>
          </div>

          <div className="ml-4">
            <button
              onClick={handleEditClick}
              className="p-3 bg-red-500/20 hover:bg-red-500/30 border border-red-400/40 text-red-300 rounded-2xl transition-all duration-200 hover:scale-105"
              title="Edit calories burned"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
