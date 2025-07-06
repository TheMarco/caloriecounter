'use client';

import type { TotalCardProps } from '@/types';

export function TotalCard({ total, target = 2000, date }: TotalCardProps) {
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
    <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
      <div className="text-center">
        {/* Date */}
        <p className="text-sm text-gray-500 mb-2">
          {formatDate(date)}
        </p>

        {/* Main Total */}
        <div className="mb-4">
          <div className={`text-4xl font-bold mb-2 ${getStatusColor()}`}>
            {total.toLocaleString()}
          </div>
          <p className="text-lg text-gray-600">calories consumed</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-4">
          <div className="w-full bg-gray-200 rounded-full h-3">
            <div 
              className={`h-3 rounded-full transition-all duration-300 ${getProgressColor()}`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            ></div>
          </div>
          <div className="flex justify-between text-xs text-gray-500 mt-1">
            <span>0</span>
            <span>{target.toLocaleString()}</span>
          </div>
        </div>

        {/* Status */}
        <div className="space-y-2">
          {isOverTarget ? (
            <div className="text-red-600">
              <p className="font-medium">Over target by {(total - target).toLocaleString()} calories</p>
              <p className="text-sm">Consider lighter meals or more activity</p>
            </div>
          ) : (
            <div className="text-gray-600">
              <p className="font-medium">{remaining.toLocaleString()} calories remaining</p>
              <p className="text-sm">{percentage.toFixed(0)}% of daily target</p>
            </div>
          )}
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-4 mt-6 pt-4 border-t border-gray-100">
          <div className="text-center">
            <div className="text-lg font-semibold text-gray-900">{percentage.toFixed(0)}%</div>
            <div className="text-xs text-gray-500">of target</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-semibold text-gray-900">{target.toLocaleString()}</div>
            <div className="text-xs text-gray-500">daily goal</div>
          </div>
          <div className="text-center">
            <div className="text-lg font-semibold text-gray-900">
              {isOverTarget ? '+' : ''}{(total - target).toLocaleString()}
            </div>
            <div className="text-xs text-gray-500">vs target</div>
          </div>
        </div>
      </div>
    </div>
  );
}
