'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { getDailyMacroTotals } from '@/utils/idb';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import { MacroTabs } from '@/components/MacroTabs';
import { useSettings } from '@/hooks/useSettings';
import type { DateRange, MacroType, MacroTotals } from '@/types';
import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent
} from '@/components/icons';

export default function HistoryPage() {
  const [selectedRange, setSelectedRange] = useState<DateRange>('7d');
  const [activeTab, setActiveTab] = useState<MacroType>('calories');
  const [localData, setLocalData] = useState<Array<{ date: string; totals: MacroTotals }>>([]);
  const [isLoadingLocal, setIsLoadingLocal] = useState(true);
  const { settings } = useSettings();
  
  // Only using local IndexedDB data

  // Load local data from IndexedDB
  useEffect(() => {
    const loadLocalData = async () => {
      try {
        setIsLoadingLocal(true);
        const days = selectedRange === '7d' ? 7 : selectedRange === '30d' ? 30 : 90;
        const data = await getDailyMacroTotals(days);
        setLocalData(data);
      } catch (error) {
        console.error('Failed to load local data:', error);
      } finally {
        setIsLoadingLocal(false);
      }
    };

    loadLocalData();
  }, [selectedRange]);

  // Use local data for now (cloud data when auth is implemented)
  const chartData = localData.map(item => {
    // Parse the date string as local date to avoid timezone issues
    const [year, month, day] = item.date.split('-').map(Number);
    const date = new Date(year, month - 1, day); // month is 0-indexed
    return {
      date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      calories: item.totals.calories,
      fat: item.totals.fat,
      carbs: item.totals.carbs,
      protein: item.totals.protein,
      fullDate: item.date,
    };
  });

  const getCurrentValues = () => {
    const values = localData.map(item => item.totals[activeTab]);
    const total = values.reduce((sum, value) => sum + value, 0);
    const average = localData.length > 0 ? Math.round(total / localData.length) : 0;
    const max = Math.max(...values, 0);
    const daysWithData = values.filter(value => value > 0).length;
    return { total, average, max, daysWithData };
  };

  const { total: currentTotal, average: currentAverage, max: currentMax, daysWithData } = getCurrentValues();

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
        return 'Calories';
      case 'fat':
        return 'Fat';
      case 'carbs':
        return 'Carbs';
      case 'protein':
        return 'Protein';
      default:
        return '';
    }
  };

  const getColor = () => {
    switch (activeTab) {
      case 'calories':
        return '#3b82f6'; // blue
      case 'fat':
        return '#10b981'; // green
      case 'carbs':
        return '#f59e0b'; // orange
      case 'protein':
        return '#8b5cf6'; // purple
      default:
        return '#3b82f6';
    }
  };

  const getTargetValue = () => {
    switch (activeTab) {
      case 'calories':
        return settings.dailyTarget;
      case 'fat':
        return settings.fatTarget;
      case 'carbs':
        return settings.carbsTarget;
      case 'protein':
        return settings.proteinTarget;
      default:
        return 0;
    }
  };

  const getTargetLineColor = () => {
    const baseColor = getColor();
    // Convert hex to rgba with opacity
    const hex = baseColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    return `rgba(${r}, ${g}, ${b}, 0.9)`;
  };

  const getTargetLineGlowColor = () => {
    const baseColor = getColor();
    // Convert hex to rgba with lower opacity for glow
    const hex = baseColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    return `rgba(${r}, ${g}, ${b}, 0.25)`;
  };

  const isLoading = isLoadingLocal;

  return (
    <div className="min-h-screen gradient-bg transition-theme">
      {/* Header */}
      <header className="bg-black/20 backdrop-blur-xl border-b border-white/10 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <Link href="/" className="p-2 rounded-full bg-white/10 hover:bg-white/20 transition-all">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
            </Link>
            <h1 className="text-2xl font-bold text-white">History</h1>
            <div className="w-10 h-10"></div> {/* Spacer for centering */}
          </div>
          <p className="text-white/70 text-center mt-2 text-sm">Your calorie tracking history</p>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-6 py-6 pb-24">
        {/* Date Range Selector */}
        <div data-testid="date-range-selector" className="card-glass card-glass-hover rounded-3xl p-6 mb-6 transition-all duration-300 shadow-2xl">
          <div className="flex items-center space-x-4 mb-4">
            <div className="p-3 bg-blue-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-white">Time Period</h2>
              <p className="text-white/60 text-sm">Select date range to view</p>
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3">
            {(['7d', '30d', '90d'] as DateRange[]).map((range) => (
              <button
                key={range}
                data-testid={`range-${range}`}
                onClick={() => setSelectedRange(range)}
                className={`py-3 px-4 rounded-2xl text-sm font-medium transition-all duration-200 backdrop-blur-sm ${
                  selectedRange === range
                    ? 'bg-blue-500/30 border border-blue-400/50 text-blue-300 shadow-lg'
                    : 'bg-white/10 border border-white/20 text-white/80 hover:bg-white/20 hover:scale-105'
                }`}
              >
                {range === '7d' ? '7 Days' : range === '30d' ? '30 Days' : '90 Days'}
              </button>
            ))}
          </div>
        </div>

        {/* Statistics Cards */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="card-glass card-glass-hover rounded-3xl p-5 transition-all duration-300 shadow-2xl">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-400">
                {isLoading ? '...' : activeTab === 'calories' ? currentAverage.toLocaleString() : currentAverage.toFixed(1)}
              </div>
              <div className="text-sm text-white/60 mt-1">Daily Average</div>
            </div>
          </div>

          <div className="card-glass card-glass-hover rounded-3xl p-5 transition-all duration-300 shadow-2xl">
            <div className="text-center">
              <div className="text-2xl font-bold text-green-400">
                {isLoading ? '...' : activeTab === 'calories' ? currentMax.toLocaleString() : currentMax.toFixed(1)}
              </div>
              <div className="text-sm text-white/60 mt-1">Highest Day</div>
            </div>
          </div>

          <div className="card-glass card-glass-hover rounded-3xl p-5 transition-all duration-300 shadow-2xl">
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-400">
                {isLoading ? '...' : activeTab === 'calories' ? currentTotal.toLocaleString() : currentTotal.toFixed(1)}
              </div>
              <div className="text-sm text-white/60 mt-1">Total {getLabel()}</div>
            </div>
          </div>

          <div className="card-glass card-glass-hover rounded-3xl p-5 transition-all duration-300 shadow-2xl">
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-400">
                {isLoading ? '...' : daysWithData}
              </div>
              <div className="text-sm text-white/60 mt-1">Active Days</div>
            </div>
          </div>
        </div>

        {/* Chart */}
        <div data-testid="chart-container" className="card-glass card-glass-hover rounded-3xl mb-6 transition-all duration-300 shadow-2xl overflow-hidden">
          {/* Macro Tabs at top of chart card */}
          <MacroTabs activeTab={activeTab} onTabChange={setActiveTab} />

          <div className="p-6">
            <div className="flex items-center space-x-4 mb-6">
              <div className="p-3 bg-green-500/20 rounded-2xl">
                <svg className="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <div>
                <h2 className="text-xl font-semibold text-white">Daily {getLabel()}</h2>
                <p className="text-white/60 text-sm">Your {getLabel().toLowerCase()} trends over time</p>
              </div>
            </div>

          {isLoading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50"></div>
            </div>
          ) : chartData.length === 0 ? (
            <div className="h-64 flex items-center justify-center">
              <div className="text-center">
                <div className="mb-4 flex justify-center">
                  <ChartIconComponent size="xl" className="text-white/40" />
                </div>
                <p className="text-white/80 font-medium">No data available</p>
                <p className="text-sm text-white/60 mt-1">Start logging your meals to see trends!</p>
              </div>
            </div>
          ) : (
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <CartesianGrid
                    strokeDasharray="3 3"
                    stroke="currentColor"
                    className="text-gray-200 dark:text-gray-700"
                  />
                  <XAxis
                    dataKey="date"
                    tick={{ fontSize: 12 }}
                    stroke="currentColor"
                    className="text-gray-600 dark:text-gray-400"
                  />
                  <YAxis
                    tick={{ fontSize: 12 }}
                    stroke="currentColor"
                    className="text-gray-600 dark:text-gray-400"
                    domain={[0, (dataMax: number) => {
                      const targetValue = getTargetValue();
                      const maxValue = Math.max(dataMax, targetValue);
                      // Add 10% padding above the highest value (either data or target)
                      return Math.ceil(maxValue * 1.1);
                    }]}
                  />
                  <Tooltip
                    labelFormatter={(label, payload) => {
                      if (payload && payload[0]) {
                        // Parse the date string as local date to avoid timezone issues
                        const [year, month, day] = payload[0].payload.fullDate.split('-').map(Number);
                        const date = new Date(year, month - 1, day); // month is 0-indexed
                        return date.toLocaleDateString('en-US', {
                          weekday: 'long',
                          month: 'long',
                          day: 'numeric'
                        });
                      }
                      return label;
                    }}
                    formatter={(value: number) => [
                      `${activeTab === 'calories' ? value.toLocaleString() : value.toFixed(1)} ${getUnit()}`,
                      getLabel()
                    ]}
                    contentStyle={{
                      backgroundColor: 'var(--card-background)',
                      border: '1px solid var(--card-border)',
                      borderRadius: '12px',
                      fontSize: '14px',
                      color: 'var(--foreground)',
                      boxShadow: '0 10px 25px rgba(0, 0, 0, 0.1)'
                    }}
                  />
                  <Line
                    type="monotone"
                    dataKey={activeTab}
                    stroke={getColor()}
                    strokeWidth={3}
                    dot={{ fill: getColor(), strokeWidth: 2, r: 5 }}
                    activeDot={{ r: 7, stroke: getColor(), strokeWidth: 3, fill: '#ffffff' }}
                  />
                  {/* Target line glow effect */}
                  <ReferenceLine
                    y={getTargetValue()}
                    stroke={getTargetLineGlowColor()}
                    strokeDasharray="6 3"
                    strokeWidth={5}
                  />
                  {/* Main target line */}
                  <ReferenceLine
                    y={getTargetValue()}
                    stroke={getTargetLineColor()}
                    strokeDasharray="6 3"
                    strokeWidth={2.5}
                    label={{
                      value: `Target: ${activeTab === 'calories' ? getTargetValue().toLocaleString() : getTargetValue().toFixed(0)} ${getUnit()}`,
                      position: 'top',
                      offset: 8,
                      style: {
                        fill: 'rgba(255, 255, 255, 0.95)',
                        fontSize: '10px',
                        fontWeight: '700',
                        textShadow: '0 1px 2px rgba(0, 0, 0, 0.8)',
                        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
                      }
                    }}
                  />

                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
          </div>
        </div>


      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-black/20 backdrop-blur-xl border-t border-white/10 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-4">
            <Link href="/" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
              <div className="mb-1">
                <HomeIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-blue-400">
              <div className="mb-1">
                <ChartIconComponent size="lg" solid className="text-blue-400" />
              </div>
              <div className="text-xs font-medium">History</div>
            </button>
            <Link href="/settings" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
              <div className="mb-1">
                <SettingsIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </Link>
          </div>
        </div>
      </nav>
    </div>
  );
}
