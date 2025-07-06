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
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-md mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold">History</h1>
            <Link
              href="/"
              className="text-blue-600 hover:text-blue-800 font-medium"
            >
              ← Back
            </Link>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-4 py-6 pb-20">
        {/* Date Range Selector */}
        <div className="bg-white rounded-lg shadow-sm border p-4 mb-6">
          <h2 className="font-semibold mb-3">Time Period</h2>
          <div className="grid grid-cols-3 gap-2">
            {(['7d', '30d', '90d'] as DateRange[]).map((range) => (
              <button
                key={range}
                onClick={() => setSelectedRange(range)}
                className={`py-2 px-3 rounded-md text-sm font-medium transition-colors ${
                  selectedRange === range
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {range === '7d' ? '7 Days' : range === '30d' ? '30 Days' : '90 Days'}
              </button>
            ))}
          </div>
        </div>

        {/* Statistics Cards */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-white rounded-lg shadow-sm border p-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">
                {isLoading ? '...' : averageCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-700">Daily Average</div>
            </div>
          </div>
          
          <div className="bg-white rounded-lg shadow-sm border p-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                {isLoading ? '...' : maxCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-700">Highest Day</div>
            </div>
          </div>
          
          <div className="bg-white rounded-lg shadow-sm border p-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">
                {isLoading ? '...' : totalCalories.toLocaleString()}
              </div>
              <div className="text-sm text-gray-700">Total Calories</div>
            </div>
          </div>
          
          <div className="bg-white rounded-lg shadow-sm border p-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">
                {isLoading ? '...' : daysWithData}
              </div>
              <div className="text-sm text-gray-700">Active Days</div>
            </div>
          </div>
        </div>

        {/* Chart */}
        <div className="bg-white rounded-lg shadow-sm border p-4 mb-6">
          <h2 className="font-semibold mb-4">Daily Calories</h2>
          
          {isLoading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          ) : chartData.length === 0 ? (
            <div className="h-64 flex items-center justify-center text-gray-700">
              <div className="text-center">
                <div className="mb-4 flex justify-center">
                <ChartIconComponent size="xl" className="text-gray-400" />
              </div>
                <p>No data available</p>
                <p className="text-sm">Start logging your meals to see trends!</p>
              </div>
            </div>
          ) : (
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis 
                    dataKey="date" 
                    tick={{ fontSize: 12 }}
                    stroke="#666"
                  />
                  <YAxis 
                    tick={{ fontSize: 12 }}
                    stroke="#666"
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
                      backgroundColor: 'white',
                      border: '1px solid #e5e7eb',
                      borderRadius: '8px',
                      fontSize: '14px'
                    }}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="calories" 
                    stroke="#3b82f6" 
                    strokeWidth={2}
                    dot={{ fill: '#3b82f6', strokeWidth: 2, r: 4 }}
                    activeDot={{ r: 6, stroke: '#3b82f6', strokeWidth: 2 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>

        {/* Insights */}
        {!isLoading && chartData.length > 0 && (
          <div className="bg-white rounded-lg shadow-sm border p-4">
            <h2 className="font-semibold mb-3">Insights</h2>
            <div className="space-y-2 text-sm">
              {averageCalories > 2200 && (
                <div className="flex items-center space-x-2 text-orange-600">
                  <span>⚠️</span>
                  <span>Your average is above 2200 calories per day</span>
                </div>
              )}
              {averageCalories < 1500 && daysWithData > 3 && (
                <div className="flex items-center space-x-2 text-blue-600">
                  <span>💡</span>
                  <span>Your average is quite low. Make sure you&apos;re eating enough!</span>
                </div>
              )}
              {daysWithData === localData.length && localData.length >= 7 && (
                <div className="flex items-center space-x-2 text-green-600">
                  <span>🎉</span>
                  <span>Great consistency! You&apos;ve logged every day.</span>
                </div>
              )}
              {maxCalories > averageCalories * 1.5 && (
                <div className="flex items-center space-x-2 text-purple-600">
                  <span>📈</span>
                  <span>You had some high-calorie days. Consider balancing with lighter meals.</span>
                </div>
              )}
            </div>
          </div>
        )}
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t-2 border-gray-200">
        <div className="max-w-md mx-auto px-4">
          <div className="flex justify-around py-2">
            <Link href="/" className="flex flex-col items-center py-2 px-4 text-gray-600 hover:text-gray-900">
              <div className="mb-1">
                <HomeIconComponent size="lg" className="text-gray-600 hover:text-gray-900" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-gray-900">
              <div className="mb-1">
                <ChartIconComponent size="lg" solid className="text-gray-900" />
              </div>
              <div className="text-xs font-medium">History</div>
            </button>
            <Link href="/settings" className="flex flex-col items-center py-2 px-4 text-gray-600 hover:text-gray-900">
              <div className="mb-1">
                <SettingsIconComponent size="lg" className="text-gray-600 hover:text-gray-900" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </Link>
          </div>
        </div>
      </nav>
    </div>
  );
}
