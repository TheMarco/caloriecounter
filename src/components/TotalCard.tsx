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
    <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-8 mb-6 transition-theme">
      <div className="text-center">
        {/* Date */}
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-3 font-medium">
          {formatDate(date)}
        </p>

        {/* Main Total */}
        <div className="mb-6">
          <div className={`text-5xl font-bold mb-3 ${getStatusColor()}`}>
            {total.toLocaleString()}
          </div>
          <p className="text-lg text-gray-700 dark:text-gray-300 font-medium">calories consumed</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-6">
          <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-4 overflow-hidden">
            <div
              className={`h-4 rounded-full transition-all duration-500 ease-out ${getProgressColor()}`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            ></div>
          </div>
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400 mt-2 font-medium">
            <span>0</span>
            <span>{target.toLocaleString()}</span>
          </div>
        </div>

        {/* Status */}
        <div className="mb-6">
          {isOverTarget ? (
            <div className="bg-red-50 dark:bg-red-900/20 rounded-xl p-4 border border-red-200 dark:border-red-800/50">
              <p className="font-semibold text-red-700 dark:text-red-300">Over target by {(total - target).toLocaleString()} calories</p>
              <p className="text-sm text-red-600 dark:text-red-400 mt-1">Consider lighter meals or more activity</p>
            </div>
          ) : (
            <div className="bg-green-50 dark:bg-green-900/20 rounded-xl p-4 border border-green-200 dark:border-green-800/50">
              <p className="font-semibold text-green-700 dark:text-green-300">{remaining.toLocaleString()} calories remaining</p>
              <p className="text-sm text-green-600 dark:text-green-400 mt-1">{percentage.toFixed(0)}% of daily target</p>
            </div>
          )}
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-4 pt-6 border-t border-gray-200/50 dark:border-gray-700/50">
          <div className="text-center">
            <div className="text-xl font-bold text-black dark:text-white">{percentage.toFixed(0)}%</div>
            <div className="text-xs text-gray-600 dark:text-gray-400 mt-1 font-medium">of target</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-black dark:text-white">{target.toLocaleString()}</div>
            <div className="text-xs text-gray-600 dark:text-gray-400 mt-1 font-medium">daily goal</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-black dark:text-white">
              {isOverTarget ? '+' : ''}{(total - target).toLocaleString()}
            </div>
            <div className="text-xs text-gray-600 dark:text-gray-400 mt-1 font-medium">vs target</div>
          </div>
        </div>
      </div>
    </div>
  );
}
