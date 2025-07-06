'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { getDailyTotals } from '@/utils/idb';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import type { DateRange } from '@/types';
import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent
} from '@/components/icons';

export default function HistoryPage() {
  const [selectedRange, setSelectedRange] = useState<DateRange>('7d');
  const [localData, setLocalData] = useState<Array<{ date: string; total: number }>>([]);
  const [isLoadingLocal, setIsLoadingLocal] = useState(true);
  
  // Only using local IndexedDB data

  // Load local data from IndexedDB
  useEffect(() => {
    const loadLocalData = async () => {
      try {
        setIsLoadingLocal(true);
        const days = selectedRange === '7d' ? 7 : selectedRange === '30d' ? 30 : 90;
        const data = await getDailyTotals(days);
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
  const chartData = localData.map(item => ({
    date: new Date(item.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
    calories: item.total,
    fullDate: item.date,
  }));

  const totalCalories = localData.reduce((sum, item) => sum + item.total, 0);
  const averageCalories = localData.length > 0 ? Math.round(totalCalories / localData.length) : 0;
  const maxCalories = Math.max(...localData.map(item => item.total), 0);
  const daysWithData = localData.filter(item => item.total > 0).length;

  const isLoading = isLoadingLocal;

  return (
    <div className="min-h-screen bg-white dark:bg-black transition-theme">
      {/* Header */}
      <header className="bg-white/80 dark:bg-black/80 backdrop-blur-xl border-b border-gray-200/50 dark:border-gray-800/50 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold text-black dark:text-white">History</h1>
            <Link
              href="/"
              className="text-blue-500 dark:text-blue-400 hover:text-blue-600 dark:hover:text-blue-300 font-medium transition-colors flex items-center space-x-1"
            >
              <span>←</span>
              <span>Back</span>
            </Link>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-6 py-6 pb-24">
        {/* Date Range Selector */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 mb-6 transition-theme">
          <h2 className="text-lg font-semibold text-black dark:text-white mb-4">Time Period</h2>
          <div className="grid grid-cols-3 gap-3">
            {(['7d', '30d', '90d'] as DateRange[]).map((range) => (
              <button
                key={range}
                onClick={() => setSelectedRange(range)}
                className={`py-3 px-4 rounded-xl text-sm font-medium transition-all duration-200 ${
                  selectedRange === range
                    ? 'bg-blue-500 dark:bg-blue-600 text-white shadow-lg shadow-blue-500/25'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:scale-105'
                }`}
              >
                {range === '7d' ? '7 Days' : range === '30d' ? '30 Days' : '90 Days'}
              </button>
            ))}
          </div>
        </div>

        {/* Statistics Cards */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-5 transition-theme hover:shadow-md hover:scale-105 duration-200">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-500 dark:text-blue-400">
                {isLoading ? '...' : averageCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">Daily Average</div>
            </div>
          </div>

          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-5 transition-theme hover:shadow-md hover:scale-105 duration-200">
            <div className="text-center">
              <div className="text-2xl font-bold text-green-500 dark:text-green-400">
                {isLoading ? '...' : maxCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">Highest Day</div>
            </div>
          </div>

          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-5 transition-theme hover:shadow-md hover:scale-105 duration-200">
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-500 dark:text-purple-400">
                {isLoading ? '...' : totalCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Calories</div>
            </div>
          </div>

          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-5 transition-theme hover:shadow-md hover:scale-105 duration-200">
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-500 dark:text-orange-400">
                {isLoading ? '...' : daysWithData}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">Active Days</div>
            </div>
          </div>
        </div>

        {/* Chart */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 mb-6 transition-theme">
          <h2 className="text-lg font-semibold text-black dark:text-white mb-6">Daily Calories</h2>

          {isLoading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 dark:border-blue-400"></div>
            </div>
          ) : chartData.length === 0 ? (
            <div className="h-64 flex items-center justify-center">
              <div className="text-center">
                <div className="mb-4 flex justify-center">
                  <ChartIconComponent size="xl" className="text-gray-400 dark:text-gray-600" />
                </div>
                <p className="text-gray-700 dark:text-gray-300 font-medium">No data available</p>
                <p className="text-sm text-gray-500 dark:text-gray-500 mt-1">Start logging your meals to see trends!</p>
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
                  />
                  <Tooltip
                    labelFormatter={(label, payload) => {
                      if (payload && payload[0]) {
                        return new Date(payload[0].payload.fullDate).toLocaleDateString('en-US', {
                          weekday: 'long',
                          month: 'long',
                          day: 'numeric'
                        });
                      }
                      return label;
                    }}
                    formatter={(value: number) => [`${value.toLocaleString()} calories`, 'Calories']}
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
                    dataKey="calories"
                    stroke="#3b82f6"
                    strokeWidth={3}
                    dot={{ fill: '#3b82f6', strokeWidth: 2, r: 5 }}
                    activeDot={{ r: 7, stroke: '#3b82f6', strokeWidth: 3, fill: '#ffffff' }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>

        {/* Insights */}
        {!isLoading && chartData.length > 0 && (
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 p-6 transition-theme">
            <h2 className="text-lg font-semibold text-black dark:text-white mb-4">Insights</h2>
            <div className="space-y-3">
              {averageCalories > 2200 && (
                <div className="flex items-center space-x-3 p-3 bg-orange-50 dark:bg-orange-900/20 rounded-xl border border-orange-200 dark:border-orange-800/50">
                  <span className="text-lg">⚠️</span>
                  <span className="text-sm text-orange-700 dark:text-orange-300">Your average is above 2200 calories per day</span>
                </div>
              )}
              {averageCalories < 1500 && daysWithData > 3 && (
                <div className="flex items-center space-x-3 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800/50">
                  <span className="text-lg">💡</span>
                  <span className="text-sm text-blue-700 dark:text-blue-300">Your average is quite low. Make sure you&apos;re eating enough!</span>
                </div>
              )}
              {daysWithData === localData.length && localData.length >= 7 && (
                <div className="flex items-center space-x-3 p-3 bg-green-50 dark:bg-green-900/20 rounded-xl border border-green-200 dark:border-green-800/50">
                  <span className="text-lg">🎉</span>
                  <span className="text-sm text-green-700 dark:text-green-300">Great consistency! You&apos;ve logged every day.</span>
                </div>
              )}
              {maxCalories > averageCalories * 1.5 && (
                <div className="flex items-center space-x-3 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-xl border border-purple-200 dark:border-purple-800/50">
                  <span className="text-lg">📈</span>
                  <span className="text-sm text-purple-700 dark:text-purple-300">You had some high-calorie days. Consider balancing with lighter meals.</span>
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white/80 dark:bg-black/80 backdrop-blur-xl border-t border-gray-200/50 dark:border-gray-800/50 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-3">
            <Link href="/" className="flex flex-col items-center py-2 px-4 text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors">
              <div className="mb-1">
                <HomeIconComponent size="lg" className="text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-blue-500 dark:text-blue-400">
              <div className="mb-1">
                <ChartIconComponent size="lg" solid className="text-blue-500 dark:text-blue-400" />
              </div>
              <div className="text-xs font-medium">History</div>
            </button>
            <Link href="/settings" className="flex flex-col items-center py-2 px-4 text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors">
              <div className="mb-1">
                <SettingsIconComponent size="lg" className="text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </Link>
          </div>
        </div>
      </nav>
    </div>
  );
}
