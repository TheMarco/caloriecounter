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
    // Parse the date string as local date to avoid timezone issues
    const [year, month, day] = dateStr.split('-').map(Number);
    const date = new Date(year, month - 1, day); // month is 0-indexed
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric'
    });
  };

  const getStatusColor = () => {
    if (isOverTarget) return 'text-red-400';
    if (percentage >= 80) return 'text-orange-400';
    if (percentage >= 60) return 'text-yellow-400';
    return 'text-green-400';
  };

  const getProgressColor = () => {
    if (isOverTarget) return 'bg-red-400';
    if (percentage >= 80) return 'bg-orange-400';
    if (percentage >= 60) return 'bg-yellow-400';
    return 'bg-green-400';
  };

  return (
    <div className="card-glass card-glass-hover rounded-3xl p-8 mb-6 transition-all duration-300 shadow-2xl">
      <div className="text-center">
        {/* Date */}
        <p className="text-sm text-white/60 mb-3 font-medium">
          {formatDate(date)}
        </p>

        {/* Main Total */}
        <div className="mb-6">
          <div className={`text-5xl font-bold mb-3 ${getStatusColor()}`}>
            {total.toLocaleString()}
          </div>
          <p className="text-lg text-white/80 font-medium">calories consumed</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-6">
          <div className="w-full bg-white/20 rounded-full h-4 overflow-hidden backdrop-blur-sm">
            <div
              className={`h-4 rounded-full transition-all duration-500 ease-out ${getProgressColor()}`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            ></div>
          </div>
          <div className="flex justify-between text-sm text-white/60 mt-2 font-medium">
            <span>0</span>
            <span>{target.toLocaleString()}</span>
          </div>
        </div>

        {/* Status */}
        <div className="mb-6">
          {isOverTarget ? (
            <div className="bg-red-500/20 rounded-2xl p-4 border border-red-400/30 backdrop-blur-sm">
              <p className="font-semibold text-red-300">Over target by {(total - target).toLocaleString()} calories</p>
              <p className="text-sm text-red-400 mt-1">Consider lighter meals or more activity</p>
            </div>
          ) : (
            <div className="bg-green-500/20 rounded-2xl p-4 border border-green-400/30 backdrop-blur-sm">
              <p className="font-semibold text-green-300">{remaining.toLocaleString()} calories remaining</p>
              <p className="text-sm text-green-400 mt-1">{percentage.toFixed(0)}% of daily target</p>
            </div>
          )}
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-4 pt-6 border-t border-white/20">
          <div className="text-center">
            <div className="text-xl font-bold text-white">{percentage.toFixed(0)}%</div>
            <div className="text-xs text-white/60 mt-1 font-medium">of target</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">{target.toLocaleString()}</div>
            <div className="text-xs text-white/60 mt-1 font-medium">daily goal</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">
              {isOverTarget ? '+' : ''}{(total - target).toLocaleString()}
            </div>
            <div className="text-xs text-white/60 mt-1 font-medium">vs target</div>
          </div>
        </div>
      </div>
    </div>
  );
}
