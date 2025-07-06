'use client';

import type { TotalCardProps } from '@/types';
import { useSettings } from '@/hooks/useSettings';

export function TotalCard({ total, date }: Omit<TotalCardProps, 'target'>) {
  const { settings } = useSettings();
  const target = settings.dailyTarget;
  const percentage = target > 0 ? Math.min((total / target) * 100, 100) : 0;
  const remaining = Math.max(target - total, 0);
  const isOverTarget = total > target;

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      month: 'long', 
      day: 'numeric' 
    });
  };

  const getStatusColor = () => {
    if (isOverTarget) return 'text-red-600';
    if (percentage >= 80) return 'text-orange-600';
    if (percentage >= 60) return 'text-yellow-600';
    return 'text-green-600';
  };

  const getProgressColor = () => {
    if (isOverTarget) return 'bg-red-500';
    if (percentage >= 80) return 'bg-orange-500';
    if (percentage >= 60) return 'bg-yellow-500';
    return 'bg-green-500';
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow-sm border border-gray-200 dark:border-gray-600 p-6 mb-6">
      <div className="text-center">
        {/* Date */}
        <p className="text-sm text-gray-600 dark:text-gray-300 mb-2">
          {formatDate(date)}
        </p>

        {/* Main Total */}
        <div className="mb-4">
          <div className={`text-4xl font-bold mb-2 ${getStatusColor()}`}>
            {total.toLocaleString()}
          </div>
          <p className="text-lg text-gray-700 dark:text-gray-200">calories consumed</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-4">
          <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
            <div
              className={`h-3 rounded-full transition-all duration-300 ${getProgressColor()}`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            ></div>
          </div>
          <div className="flex justify-between text-xs text-gray-600 dark:text-gray-300 mt-1">
            <span>0</span>
            <span>{target.toLocaleString()}</span>
          </div>
        </div>

        {/* Status */}
        <div className="space-y-2">
          {isOverTarget ? (
            <div className="text-red-600 dark:text-red-400">
              <p className="font-medium">Over target by {(total - target).toLocaleString()} calories</p>
              <p className="text-sm">Consider lighter meals or more activity</p>
            </div>
          ) : (
            <div className="text-gray-700 dark:text-gray-200">
              <p className="font-medium">{remaining.toLocaleString()} calories remaining</p>
              <p className="text-sm">{percentage.toFixed(0)}% of daily target</p>
            </div>
          )}
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-4 mt-6 pt-4 border-t border-gray-200 dark:border-gray-600">
          <div className="text-center">
            <div className="text-lg font-semibold text-black dark:text-white">{percentage.toFixed(0)}%</div>
            <div className="text-xs text-gray-600 dark:text-gray-300">of target</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-semibold text-black dark:text-white">{target.toLocaleString()}</div>
            <div className="text-xs text-gray-600 dark:text-gray-300">daily goal</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-semibold text-black dark:text-white">
              {isOverTarget ? '+' : ''}{(total - target).toLocaleString()}
            </div>
            <div className="text-xs text-gray-600 dark:text-gray-300">vs target</div>
          </div>
        </div>
      </div>
    </div>
  );
}
