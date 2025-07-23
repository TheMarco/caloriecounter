'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { getDailyMacroTotalsWithOffset } from '@/utils/idb';
import { Calendar } from '@/components/Calendar';
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
  const router = useRouter();
  const [selectedRange, setSelectedRange] = useState<DateRange>('7d');
  const [activeTab, setActiveTab] = useState<MacroType>('calories');
  const [localData, setLocalData] = useState<Array<{ date: string; totals: MacroTotals; offset: number }>>([]);
  const [isLoadingLocal, setIsLoadingLocal] = useState(true);
  const { settings } = useSettings();
  
  // Load local data from IndexedDB
  useEffect(() => {
    const loadLocalData = async () => {
      try {
        setIsLoadingLocal(true);
        const days = selectedRange === '7d' ? 7 : selectedRange === '30d' ? 30 : 90;
        const data = await getDailyMacroTotalsWithOffset(days);
        setLocalData(data);
      } catch (error) {
        console.error('Failed to load local data:', error);
      } finally {
        setIsLoadingLocal(false);
      }
    };

    loadLocalData();
  }, [selectedRange]);

  const chartData = localData.map(item => {
    const [year, month, day] = item.date.split('-').map(Number);
    const date = new Date(year, month - 1, day);
    const netCalories = Math.max(0, item.totals.calories - item.offset);
    return {
      date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      calories: item.totals.calories,
      netCalories: netCalories,
      fat: item.totals.fat,
      carbs: item.totals.carbs,
      protein: item.totals.protein,
      offset: item.offset,
      fullDate: item.date,
    };
  });

  // Removed getCurrentValues function since we removed the statistics cards

  const getUnit = () => {
    switch (activeTab) {
      case 'calories': return 'calories';
      case 'fat':
      case 'carbs':
      case 'protein': return 'grams';
      default: return '';
    }
  };

  const getLabel = () => {
    switch (activeTab) {
      case 'calories': return 'Calories';
      case 'fat': return 'Fat';
      case 'carbs': return 'Carbs';
      case 'protein': return 'Protein';
      default: return '';
    }
  };

  const getColor = () => {
    switch (activeTab) {
      case 'calories': return '#3b82f6';
      case 'fat': return '#10b981';
      case 'carbs': return '#f59e0b';
      case 'protein': return '#8b5cf6';
      default: return '#3b82f6';
    }
  };

  const getTargetValue = () => {
    switch (activeTab) {
      case 'calories': return settings.dailyTarget;
      case 'fat': return settings.fatTarget;
      case 'carbs': return settings.carbsTarget;
      case 'protein': return settings.proteinTarget;
      default: return 0;
    }
  };

  const getTargetLineColor = () => {
    const baseColor = getColor();
    const hex = baseColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    return `rgba(${r}, ${g}, ${b}, 0.9)`;
  };

  const getTargetLineGlowColor = () => {
    const baseColor = getColor();
    const hex = baseColor.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    return `rgba(${r}, ${g}, ${b}, 0.25)`;
  };

  const isLoading = isLoadingLocal;
  const handleDateSelect = (date: string) => {
    router.push(`/?date=${date}`);
  };

  return (
    <div className="min-h-screen gradient-bg transition-theme">
      <header className="bg-black/20 backdrop-blur-xl border-b border-white/10 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <Link href="/" className="p-2 rounded-full bg-white/10 hover:bg-white/20 transition-all">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
            </Link>
            <h1 className="text-2xl font-bold text-white">History</h1>
            <div className="w-10 h-10"></div>
          </div>
          <p className="text-white/70 text-center mt-2 text-sm">Your calorie tracking history</p>
        </div>
      </header>

      <main className="max-w-md mx-auto px-6 py-6 pb-24">
        <div data-testid="chart-container" className="card-glass card-glass-hover rounded-3xl mb-6 transition-all duration-300 shadow-2xl overflow-hidden">
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
                    <CartesianGrid strokeDasharray="3 3" stroke="currentColor" className="text-gray-200 dark:text-gray-700" />
                    <XAxis dataKey="date" tick={{ fontSize: 12 }} stroke="currentColor" className="text-gray-600 dark:text-gray-400" />
                    <YAxis tick={{ fontSize: 12 }} stroke="currentColor" className="text-gray-600 dark:text-gray-400" domain={[0, (dataMax: number) => {
                      const targetValue = getTargetValue();
                      const maxValue = Math.max(dataMax, targetValue);
                      return Math.ceil(maxValue * 1.1);
                    }]} />
                    <Tooltip
                      labelFormatter={(label, payload) => {
                        if (payload && payload[0]) {
                          const [year, month, day] = payload[0].payload.fullDate.split('-').map(Number);
                          const date = new Date(year, month - 1, day);
                          return date.toLocaleDateString('en-US', {
                            weekday: 'long',
                            month: 'long',
                            day: 'numeric'
                          });
                        }
                        return label;
                      }}
                      formatter={(value: number, name: string) => {
                        if (activeTab === 'calories') {
                          const label = name === 'Raw Intake' ? 'Raw calories consumed' :
                                       name === 'Net Intake' ? 'Net calories (after offset)' :
                                       getLabel();
                          return [`${value.toLocaleString()} ${getUnit()}`, label];
                        } else {
                          return [`${value.toFixed(1)} ${getUnit()}`, getLabel()];
                        }
                      }}
                      contentStyle={{
                        backgroundColor: 'var(--card-background)',
                        border: '1px solid var(--card-border)',
                        borderRadius: '12px',
                        fontSize: '14px',
                        color: 'var(--foreground)',
                        boxShadow: '0 10px 25px rgba(0, 0, 0, 0.1)'
                      }}
                    />
                    {activeTab === 'calories' ? (
                      <>
                        <Line type="monotone" dataKey="calories" stroke={getColor()} strokeWidth={3} dot={{ fill: getColor(), strokeWidth: 2, r: 5 }} activeDot={{ r: 7, stroke: getColor(), strokeWidth: 3, fill: '#ffffff' }} name="Raw Intake" />
                        <Line type="monotone" dataKey="netCalories" stroke="#ef4444" strokeWidth={3} dot={{ fill: '#ef4444', strokeWidth: 2, r: 5 }} activeDot={{ r: 7, stroke: '#ef4444', strokeWidth: 3, fill: '#ffffff' }} name="Net Intake" />
                      </>
                    ) : (
                      <Line type="monotone" dataKey={activeTab} stroke={getColor()} strokeWidth={3} dot={{ fill: getColor(), strokeWidth: 2, r: 5 }} activeDot={{ r: 7, stroke: getColor(), strokeWidth: 3, fill: '#ffffff' }} />
                    )}
                    <ReferenceLine y={getTargetValue()} stroke={getTargetLineGlowColor()} strokeDasharray="6 3" strokeWidth={5} />
                    <ReferenceLine y={getTargetValue()} stroke={getTargetLineColor()} strokeDasharray="6 3" strokeWidth={2.5} label={{
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
                    }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Legend - always present to maintain consistent card height */}
            <div className="mt-4 flex justify-center h-6">
              {activeTab === 'calories' && chartData.length > 0 ? (
                <div className="flex items-center space-x-6 text-sm">
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-0.5 bg-blue-500 rounded"></div>
                    <span className="text-white/80">Raw calorie intake</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-3 h-0.5 bg-red-500 rounded"></div>
                    <span className="text-white/80">Net calorie intake</span>
                  </div>
                </div>
              ) : (
                <div></div>
              )}
            </div>
          </div>

          <div className="px-6 pb-6">
            <div className="border-t border-white/10 pt-4">
              <div data-testid="date-range-selector" className="flex justify-center">
                <div className="flex bg-white/5 rounded-2xl p-1 backdrop-blur-sm border border-white/10">
                  {(['7d', '30d', '90d'] as DateRange[]).map((range) => (
                    <button
                      key={range}
                      data-testid={`range-${range}`}
                      onClick={() => setSelectedRange(range)}
                      className={`px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200 ${
                        selectedRange === range
                          ? 'bg-blue-500/40 text-blue-300 shadow-lg'
                          : 'text-white/70 hover:text-white hover:bg-white/10'
                      }`}
                    >
                      {range === '7d' ? '7 days' : range === '30d' ? '30 days' : '90 days'}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="mb-6">
          <Calendar onDateSelect={handleDateSelect} />
        </div>
      </main>

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
