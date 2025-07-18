'use client';

import { MacroTabs } from './MacroTabs';
import type { TabbedTotalCardProps, MacroType } from '@/types';

interface TabbedTotalCardWithTabProps extends TabbedTotalCardProps {
  activeTab: MacroType;
  onTabChange: (tab: MacroType) => void;
}

export function TabbedTotalCard({ totals, targets, date, calorieOffset = 0, activeTab, onTabChange }: TabbedTotalCardWithTabProps) {

  const formatDate = (dateStr: string) => {
    if (!dateStr) {
      return 'Today';
    }
    // Parse the date string as local date to avoid timezone issues
    const [year, month, day] = dateStr.split('-').map(Number);
    const date = new Date(year, month - 1, day); // month is 0-indexed
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric'
    });
  };

  const getCurrentData = () => {
    const rawCurrent = totals[activeTab];
    // For calories, show net amount (consumed - offset), for other macros show raw amount
    const current = activeTab === 'calories' ? Math.max(0, rawCurrent - calorieOffset) : rawCurrent;
    const target = targets[activeTab];
    const percentage = target > 0 ? Math.min((current / target) * 100, 100) : 0;
    const remaining = Math.max(target - current, 0);
    const isOverTarget = current > target;

    return { current, rawCurrent, target, percentage, remaining, isOverTarget };
  };

  const getStatusColor = () => {
    const { isOverTarget, percentage } = getCurrentData();
    if (isOverTarget) return 'text-red-400';
    if (percentage >= 80) return 'text-orange-400';
    if (percentage >= 60) return 'text-yellow-400';
    return 'text-green-400';
  };

  const getProgressColor = () => {
    const { isOverTarget, percentage } = getCurrentData();
    if (isOverTarget) return 'bg-red-400';
    if (percentage >= 80) return 'bg-orange-400';
    if (percentage >= 60) return 'bg-yellow-400';
    return 'bg-green-400';
  };

  const getUnit = () => {
    switch (activeTab) {
      case 'calories':
        return 'calories';
      case 'fat':
      case 'carbs':
      case 'protein':
        return 'grams';
      default:
        return '';
    }
  };

  const getLabel = () => {
    switch (activeTab) {
      case 'calories':
        return 'calories consumed';
      case 'fat':
        return 'fat consumed';
      case 'carbs':
        return 'carbs consumed';
      case 'protein':
        return 'protein consumed';
      default:
        return '';
    }
  };

  const { current, rawCurrent, target, percentage, remaining, isOverTarget } = getCurrentData();

  return (
    <div data-testid="totals-card" className="card-glass card-glass-hover rounded-3xl mb-6 transition-all duration-300 shadow-2xl overflow-hidden">
      {/* Tabs at top of card */}
      <MacroTabs activeTab={activeTab} onTabChange={onTabChange} />

      <div className="p-8">
        {/* Date */}
        <div className="text-center mb-6">
          <p className="text-sm text-white/60 mb-3 font-medium">
            {formatDate(date)}
          </p>
        </div>

      <div className="text-center">
        {/* Main Total */}
        <div data-testid="macro-display" className="mb-6">
          <div data-testid="macro-total" className={`text-5xl font-bold mb-3 ${getStatusColor()}`}>
            {activeTab === 'calories' ? current.toLocaleString() : current.toFixed(1)}
          </div>
          {activeTab === 'calories' && calorieOffset > 0 ? (
            <div className="mb-2">
              <p className="text-sm text-white/60">
                {rawCurrent.toLocaleString()} - {calorieOffset.toLocaleString()} = {current.toLocaleString()}
              </p>
            </div>
          ) : null}
          <p className="text-lg text-white/80 font-medium">
            {activeTab === 'calories' && calorieOffset > 0 ? 'net calories consumed' : getLabel()}
          </p>
        </div>

        {/* Progress Bar */}
        <div className="mb-6">
          <div className="w-full bg-white/20 rounded-full h-3 backdrop-blur-sm overflow-hidden">
            <div 
              className={`h-full rounded-full transition-all duration-500 ${getProgressColor()}`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            />
          </div>
        </div>

        {/* Status */}
        <div className="mb-6">
          {isOverTarget ? (
            <div className="bg-red-500/20 rounded-2xl p-4 border border-red-400/30 backdrop-blur-sm">
              <p className="font-semibold text-red-300">
                Over target by {activeTab === 'calories' ? (current - target).toLocaleString() : (current - target).toFixed(1)} {getUnit()}
              </p>
              <p className="text-sm text-red-400 mt-1">Consider adjusting your intake</p>
            </div>
          ) : (
            <div className="bg-green-500/20 rounded-2xl p-4 border border-green-400/30 backdrop-blur-sm">
              <p className="font-semibold text-green-300">
                {activeTab === 'calories' ? remaining.toLocaleString() : remaining.toFixed(1)} {getUnit()} remaining
              </p>
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
            <div className="text-xl font-bold text-white">
              {activeTab === 'calories' ? target.toLocaleString() : target.toFixed(0)}
            </div>
            <div className="text-xs text-white/60 mt-1 font-medium">daily goal</div>
          </div>
          <div className="text-center">
            <div className="text-xl font-bold text-white">
              {isOverTarget ? '+' : ''}{activeTab === 'calories' ? (current - target).toLocaleString() : (current - target).toFixed(1)}
            </div>
            <div className="text-xs text-white/60 mt-1 font-medium">vs target</div>
          </div>
        </div>
      </div>
      </div>
    </div>
  );
}
