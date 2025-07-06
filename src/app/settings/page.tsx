'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useSettings } from '@/hooks/useSettings';

import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent,
  CheckIconComponent,
  InfoIconComponent
} from '@/components/icons';

export default function Settings() {
  const { settings, isLoading, updateSetting, resetSettings } = useSettings();
  const [isSaving, setIsSaving] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      // Settings are automatically saved when changed, so just show success
      alert('Settings saved successfully!');
    } catch {
      alert('Failed to save settings. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleReset = async () => {
    if (confirm('Are you sure you want to reset all settings to default?')) {
      const success = resetSettings();
      if (success) {
        alert('Settings reset to defaults successfully!');
      } else {
        alert('Failed to reset settings. Please try again.');
      }
    }
  };

  const handleClearData = () => {
    if (confirm('Are you sure you want to clear all your calorie data? This cannot be undone.')) {
      // Clear IndexedDB data
      if (typeof window !== 'undefined' && 'indexedDB' in window) {
        indexedDB.deleteDatabase('keyval-store');
        alert('All data cleared successfully!');
      }
    }
  };

  // Prevent hydration mismatch
  if (!mounted) {
    return (
      <div className="min-h-screen bg-black">
        <div className="animate-pulse">
          <header className="bg-black shadow-sm border-b border-gray-800">
            <div className="max-w-md mx-auto px-6 py-4">
              <h1 className="text-2xl font-bold text-center text-white">Settings</h1>
            </div>
          </header>
          <main className="max-w-md mx-auto px-6 py-6">
            <div className="bg-gray-900 rounded-2xl shadow-sm border border-gray-800 p-6 mb-6">
              <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
              <div className="h-10 bg-gray-700 rounded"></div>
            </div>
          </main>
        </div>
      </div>
    );
  }

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
            <h1 className="text-2xl font-bold text-white">Settings</h1>
            <div className="w-10 h-10"></div> {/* Spacer for centering */}
          </div>
          <p className="text-white/70 text-center mt-2 text-sm">Customize your experience</p>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-6 py-6 pb-24">

        {isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50 mx-auto mb-4"></div>
            <p className="text-white/70">Loading settings...</p>
          </div>
        )}

        {/* Daily Target */}
        <div className="card-glass card-glass-hover rounded-3xl p-6 mb-6 transition-all duration-300 shadow-2xl">
          <div className="flex items-center space-x-4 mb-6">
            <div className="p-3 bg-blue-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-white">Daily Calorie Target</h2>
              <p className="text-white/60 text-sm">Set your daily calorie goal</p>
            </div>
          </div>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-white/80 mb-3">
                Target Calories per Day
              </label>
              <input
                type="number"
                value={settings.dailyTarget}
                onChange={(e) => updateSetting('dailyTarget', Number(e.target.value))}
                className="w-full px-4 py-4 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 bg-white/10 text-white placeholder-white/50 transition-all font-medium text-lg backdrop-blur-sm"
                min="1000"
                max="5000"
                step="50"
                disabled={isLoading}
              />
              <p className="text-sm text-white/50 mt-3 font-medium">
                Recommended: 1,800-2,400 calories for most adults
              </p>
            </div>
          </div>
        </div>

        {/* Preferences */}
        <div className="card-glass card-glass-hover rounded-3xl p-6 mb-6 transition-all duration-300 shadow-2xl">
          <div className="flex items-center space-x-4 mb-6">
            <div className="p-3 bg-green-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-white">Preferences</h2>
              <p className="text-white/60 text-sm">Customize your app experience</p>
            </div>
          </div>
          <div className="space-y-6">

            {/* Units */}
            <div>
              <label className="block text-sm font-semibold text-white/80 mb-4">
                Measurement Units
              </label>
              <div className="grid grid-cols-2 gap-3">
                <label className={`flex items-center p-4 rounded-2xl border-2 cursor-pointer transition-all duration-200 backdrop-blur-sm ${
                  settings.units === 'metric'
                    ? 'border-blue-400 bg-blue-500/20 text-blue-300'
                    : 'border-white/20 hover:border-white/30 text-white hover:bg-white/10'
                }`}>
                  <input
                    type="radio"
                    value="metric"
                    checked={settings.units === 'metric'}
                    onChange={(e) => updateSetting('units', e.target.value as 'metric')}
                    className="sr-only"
                    disabled={isLoading}
                  />
                  <div className="text-center w-full">
                    <div className="font-semibold">Metric</div>
                    <div className="text-xs mt-1 opacity-75">g, kg, ml, l</div>
                  </div>
                </label>
                <label className={`flex items-center p-4 rounded-2xl border-2 cursor-pointer transition-all duration-200 backdrop-blur-sm ${
                  settings.units === 'imperial'
                    ? 'border-blue-400 bg-blue-500/20 text-blue-300'
                    : 'border-white/20 hover:border-white/30 text-white hover:bg-white/10'
                }`}>
                  <input
                    type="radio"
                    value="imperial"
                    checked={settings.units === 'imperial'}
                    onChange={(e) => updateSetting('units', e.target.value as 'imperial')}
                    className="sr-only"
                    disabled={isLoading}
                  />
                  <div className="text-center w-full">
                    <div className="font-semibold">Imperial</div>
                    <div className="text-xs mt-1 opacity-75">oz, lb, fl oz, cups</div>
                  </div>
                </label>
              </div>
            </div>




          </div>
        </div>

        {/* Data Management */}
        <div className="card-glass card-glass-hover rounded-3xl p-6 mb-6 transition-all duration-300 shadow-2xl">
          <div className="flex items-center space-x-4 mb-6">
            <div className="p-3 bg-red-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-white">Data Management</h2>
              <p className="text-white/60 text-sm">Manage your stored data</p>
            </div>
          </div>
          <div className="space-y-4">
            <button
              onClick={handleClearData}
              className="w-full bg-red-500/20 hover:bg-red-500/30 border border-red-400/30 hover:border-red-400/50 text-red-300 hover:text-red-200 px-6 py-4 rounded-2xl text-sm font-semibold transition-all duration-200 backdrop-blur-sm"
            >
              Clear All Data
            </button>
            <p className="text-sm text-white/60 font-medium">
              This will permanently delete all your calorie entries and cannot be undone.
            </p>
          </div>
        </div>

        {/* App Info */}
        <div className="card-glass card-glass-hover rounded-3xl p-6 mb-8 transition-all duration-300 shadow-2xl">
          <div className="flex items-center space-x-4 mb-6">
            <div className="p-3 bg-purple-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h2 className="text-xl font-semibold text-white">About</h2>
              <p className="text-white/60 text-sm">Learn more about this app</p>
            </div>
          </div>
          <div className="space-y-4">
            <div className="flex items-center space-x-3 p-4 bg-blue-500/20 rounded-2xl border border-blue-400/30 backdrop-blur-sm">
              <InfoIconComponent size="sm" className="text-blue-400" />
              <span className="font-semibold text-blue-300">Calorie Counter PWA v1.0.0</span>
            </div>
            <p className="text-sm text-white/70 font-medium leading-relaxed">
              A lightning-fast calorie tracking app with barcode scanning and voice input.
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-4">
          <button
            onClick={handleSave}
            disabled={isSaving || isLoading}
            className="w-full bg-blue-500 hover:bg-blue-600 disabled:bg-blue-300 text-white px-6 py-4 rounded-xl font-semibold transition-all duration-200 flex items-center justify-center space-x-3 hover:scale-105 active:scale-95 disabled:scale-100"
          >
            {isSaving ? (
              <div className="w-5 h-5 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            ) : (
              <CheckIconComponent size="sm" className="text-white" />
            )}
            <span>{isSaving ? 'Saving...' : 'Save Settings'}</span>
          </button>

          <button
            onClick={handleReset}
            className="w-full bg-gray-500 hover:bg-gray-600 text-white px-6 py-4 rounded-xl font-semibold transition-all duration-200 hover:scale-105 active:scale-95"
          >
            Reset to Defaults
          </button>
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
            <Link href="/history" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
              <div className="mb-1">
                <ChartIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">History</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-blue-400">
              <div className="mb-1">
                <SettingsIconComponent size="lg" solid className="text-blue-400" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </button>
          </div>
        </div>
      </nav>
    </div>
  );
}
