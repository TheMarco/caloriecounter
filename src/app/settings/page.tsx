'use client';

import { useState } from 'react';
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

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b-2 border-gray-200">
        <div className="max-w-md mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold text-center text-gray-900">Settings</h1>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-4 py-6 pb-20">
        
        {/* Daily Target */}
        <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Daily Calorie Target</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Target Calories per Day
              </label>
              <input
                type="number"
                value={settings.dailyTarget}
                onChange={(e) => updateSetting('dailyTarget', Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                min="1000"
                max="5000"
                step="50"
                disabled={isLoading}
              />
              <p className="text-xs text-gray-600 mt-1">
                Recommended: 1,800-2,400 calories for most adults
              </p>
            </div>
          </div>
        </div>

        {/* Preferences */}
        <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Preferences</h2>
          <div className="space-y-4">
            
            {/* Units */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Measurement Units
              </label>
              <div className="flex space-x-4">
                <label className="flex items-center">
                  <input
                    type="radio"
                    value="metric"
                    checked={settings.units === 'metric'}
                    onChange={(e) => updateSetting('units', e.target.value as 'metric')}
                    className="mr-2"
                    disabled={isLoading}
                  />
                  Metric (g, kg, ml, l)
                </label>
                <label className="flex items-center">
                  <input
                    type="radio"
                    value="imperial"
                    checked={settings.units === 'imperial'}
                    onChange={(e) => updateSetting('units', e.target.value as 'imperial')}
                    className="mr-2"
                    disabled={isLoading}
                  />
                  Imperial (oz, lb, fl oz, cups)
                </label>
              </div>
            </div>

            {/* Notifications */}
            <div className="flex items-center justify-between">
              <div>
                <label className="text-sm font-medium text-gray-700">
                  Enable Notifications
                </label>
                <p className="text-xs text-gray-600">
                  Get reminders to log your meals
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={settings.notifications}
                  onChange={(e) => updateSetting('notifications', e.target.checked)}
                  className="sr-only peer"
                  disabled={isLoading}
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
              </label>
            </div>

            {/* Dark Mode */}
            <div className="flex items-center justify-between">
              <div>
                <label className="text-sm font-medium text-gray-700">
                  Dark Mode
                </label>
                <p className="text-xs text-gray-600">
                  Switch to dark theme
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={settings.darkMode}
                  onChange={(e) => updateSetting('darkMode', e.target.checked)}
                  className="sr-only peer"
                  disabled={isLoading}
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 peer-disabled:opacity-50"></div>
              </label>
            </div>
          </div>
        </div>

        {/* Data Management */}
        <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Data Management</h2>
          <div className="space-y-4">
            <button
              onClick={handleClearData}
              className="w-full bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              Clear All Data
            </button>
            <p className="text-xs text-gray-700">
              This will permanently delete all your calorie entries and cannot be undone.
            </p>
          </div>
        </div>

        {/* App Info */}
        <div className="bg-white rounded-lg shadow-sm border p-6 mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">About</h2>
          <div className="space-y-2 text-sm text-gray-600">
            <div className="flex items-center space-x-2">
              <InfoIconComponent size="sm" className="text-gray-400" />
              <span>Calorie Counter PWA v1.0.0</span>
            </div>
            <p className="text-xs text-gray-700">
              A lightning-fast calorie tracking app with barcode scanning and voice input.
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-3">
          <button
            onClick={handleSave}
            disabled={isSaving || isLoading}
            className="w-full bg-blue-500 hover:bg-blue-600 disabled:bg-blue-300 text-white px-4 py-3 rounded-md font-medium transition-colors flex items-center justify-center space-x-2"
          >
            {isSaving ? (
              <div className="w-4 h-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
            ) : (
              <CheckIconComponent size="sm" className="text-white" />
            )}
            <span>{isSaving ? 'Saving...' : 'Save Settings'}</span>
          </button>
          
          <button
            onClick={handleReset}
            className="w-full bg-gray-500 hover:bg-gray-600 text-white px-4 py-3 rounded-md font-medium transition-colors"
          >
            Reset to Defaults
          </button>
        </div>
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
            <Link href="/history" className="flex flex-col items-center py-2 px-4 text-gray-600 hover:text-gray-900">
              <div className="mb-1">
                <ChartIconComponent size="lg" className="text-gray-600 hover:text-gray-900" />
              </div>
              <div className="text-xs font-medium">History</div>
            </Link>
            <button className="flex flex-col items-center py-2 px-4 text-gray-900">
              <div className="mb-1">
                <SettingsIconComponent size="lg" solid className="text-gray-900" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </button>
          </div>
        </div>
      </nav>
    </div>
  );
}
