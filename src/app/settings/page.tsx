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
import { exportNutritionData } from '@/utils/csvExport';

export default function Settings() {
  const { settings, isLoading, updateSetting, resetSettings } = useSettings();
  const [isSaving, setIsSaving] = useState(false);
  const [isExporting, setIsExporting] = useState(false);
  const [showLicense, setShowLicense] = useState(false);
  const [licenseContent, setLicenseContent] = useState<string>('');
  const [mounted, setMounted] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  // String representations for input fields to allow empty values
  const [dailyTargetString, setDailyTargetString] = useState('');
  const [fatTargetString, setFatTargetString] = useState('');
  const [carbsTargetString, setCarbsTargetString] = useState('');
  const [proteinTargetString, setProteinTargetString] = useState('');

  useEffect(() => {
    setMounted(true);
  }, []);

  // Update string values when settings change
  useEffect(() => {
    if (settings) {
      setDailyTargetString(settings.dailyTarget.toString());
      setFatTargetString(settings.fatTarget.toString());
      setCarbsTargetString(settings.carbsTarget.toString());
      setProteinTargetString(settings.proteinTarget.toString());
    }
  }, [settings]);

  const showMessage = (message: string, isError = false) => {
    if (isError) {
      setErrorMessage(message);
      setSuccessMessage('');
    } else {
      setSuccessMessage(message);
      setErrorMessage('');
    }
    setTimeout(() => {
      setSuccessMessage('');
      setErrorMessage('');
    }, 3000);
  };

  const validateInput = (value: string, min: number, max: number): number | null => {
    const num = parseFloat(value);
    if (isNaN(num) || num < min || num > max) {
      return null;
    }
    return num;
  };

  const handleSaveSettings = async () => {
    setIsSaving(true);

    try {
      // Validate all inputs
      const dailyTarget = validateInput(dailyTargetString, 1000, 5000);
      const fatTarget = validateInput(fatTargetString, 20, 200);
      const carbsTarget = validateInput(carbsTargetString, 50, 500);
      const proteinTarget = validateInput(proteinTargetString, 30, 300);

      if (dailyTarget === null) {
        showMessage('Daily calorie target must be between 1000 and 5000', true);
        return;
      }
      if (fatTarget === null) {
        showMessage('Fat target must be between 20g and 200g', true);
        return;
      }
      if (carbsTarget === null) {
        showMessage('Carbs target must be between 50g and 500g', true);
        return;
      }
      if (proteinTarget === null) {
        showMessage('Protein target must be between 30g and 300g', true);
        return;
      }

      // Save all settings including units (which might have been changed separately)
      const success = await Promise.all([
        updateSetting('dailyTarget', dailyTarget),
        updateSetting('fatTarget', fatTarget),
        updateSetting('carbsTarget', carbsTarget),
        updateSetting('proteinTarget', proteinTarget),
        updateSetting('units', settings.units), // Include current units setting
      ]);

      if (success.every(Boolean)) {
        showMessage('Settings saved successfully!');
      } else {
        showMessage('Failed to save some settings', true);
      }
    } catch (error) {
      console.error('Error saving settings:', error);
      showMessage('Failed to save settings', true);
    } finally {
      setIsSaving(false);
    }
  };

  const handleResetToDefaults = async () => {
    if (window.confirm('Are you sure you want to reset all settings to defaults?')) {
      const success = resetSettings();
      if (success) {
        showMessage('Settings reset to defaults');
      } else {
        showMessage('Failed to reset settings', true);
      }
    }
  };

  const handleExportData = async () => {
    setIsExporting(true);
    try {
      await exportNutritionData();
      showMessage('Data exported successfully!');
    } catch (error) {
      console.error('Export error:', error);
      showMessage('Failed to export data', true);
    } finally {
      setIsExporting(false);
    }
  };

  const handleUnitsChange = async (newUnits: 'metric' | 'imperial') => {
    const success = await updateSetting('units', newUnits);
    if (!success) {
      showMessage('Failed to save units preference', true);
    }
  };

  const loadLicense = async () => {
    try {
      const response = await fetch('/LICENSE');
      if (response.ok) {
        const text = await response.text();
        setLicenseContent(text);
        setShowLicense(true);
      } else {
        showMessage('License file not found', true);
      }
    } catch (error) {
      console.error('Failed to load license:', error);
      showMessage('Failed to load license', true);
    }
  };

  if (!mounted || isLoading) {
    return (
      <div className="min-h-screen gradient-bg flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen gradient-bg text-white">
      {/* Header */}
      <header className="sticky top-0 z-40 backdrop-blur-md bg-black/20 border-b border-white/10">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link
                href="/"
                data-testid="back-button"
                className="p-2 text-white/60 hover:text-white transition-colors rounded-xl hover:bg-white/10"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
              </Link>
              <div className="p-2 bg-blue-500/20 rounded-xl border border-blue-400/30">
                <SettingsIconComponent size="md" className="text-blue-400" />
              </div>
              <h1 className="text-2xl font-bold">Settings</h1>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-6 pb-24">
        {/* Success/Error Messages */}
        {successMessage && (
          <div data-testid="success-message" className="mb-6 p-4 bg-green-500/20 border border-green-400/30 rounded-2xl">
            <div className="flex items-center space-x-2">
              <CheckIconComponent size="sm" className="text-green-400" />
              <span className="text-green-300">{successMessage}</span>
            </div>
          </div>
        )}

        {errorMessage && (
          <div data-testid="validation-error" className="mb-6 p-4 bg-red-500/20 border border-red-400/30 rounded-2xl">
            <div className="flex items-center space-x-2">
              <InfoIconComponent size="sm" className="text-red-400" />
              <span className="text-red-300">{errorMessage}</span>
            </div>
          </div>
        )}

        {/* Daily Goals Section */}
        <section data-testid="daily-goals-section" className="mb-8">
          <div className="card-glass rounded-3xl p-6">
            <h2 className="text-xl font-semibold mb-6 flex items-center space-x-3">
              <div className="p-2 bg-green-500/20 rounded-xl border border-green-400/30">
                <svg className="w-5 h-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <span>Daily Goals</span>
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Daily Calorie Target */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Daily Calorie Target
                </label>
                <div className="relative">
                  <input
                    data-testid="daily-target-input"
                    type="number"
                    value={dailyTargetString}
                    onChange={(e) => setDailyTargetString(e.target.value)}
                    className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                    placeholder="2000"
                    min="1000"
                    max="5000"
                  />
                  <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-white/60 text-sm">
                    kcal
                  </span>
                </div>
                <p className="text-xs text-white/60 mt-1">Range: 1000-5000 calories</p>
              </div>

              {/* Fat Target */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Daily Fat Target
                </label>
                <div className="relative">
                  <input
                    data-testid="fat-target-input"
                    type="number"
                    value={fatTargetString}
                    onChange={(e) => setFatTargetString(e.target.value)}
                    className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                    placeholder="65"
                    min="20"
                    max="200"
                  />
                  <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-white/60 text-sm">
                    g
                  </span>
                </div>
                <p className="text-xs text-white/60 mt-1">Range: 20-200 grams</p>
              </div>

              {/* Carbs Target */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Daily Carbs Target
                </label>
                <div className="relative">
                  <input
                    data-testid="carbs-target-input"
                    type="number"
                    value={carbsTargetString}
                    onChange={(e) => setCarbsTargetString(e.target.value)}
                    className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                    placeholder="250"
                    min="50"
                    max="500"
                  />
                  <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-white/60 text-sm">
                    g
                  </span>
                </div>
                <p className="text-xs text-white/60 mt-1">Range: 50-500 grams</p>
              </div>

              {/* Protein Target */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Daily Protein Target
                </label>
                <div className="relative">
                  <input
                    data-testid="protein-target-input"
                    type="number"
                    value={proteinTargetString}
                    onChange={(e) => setProteinTargetString(e.target.value)}
                    className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all"
                    placeholder="100"
                    min="30"
                    max="300"
                  />
                  <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-white/60 text-sm">
                    g
                  </span>
                </div>
                <p className="text-xs text-white/60 mt-1">Range: 30-300 grams</p>
              </div>
            </div>
          </div>
        </section>

        {/* Preferences Section */}
        <section data-testid="preferences-section" className="mb-8">
          <div className="card-glass rounded-3xl p-6">
            <div className="flex items-center space-x-3 mb-6">
              <div className="p-3 bg-green-500/20 rounded-2xl border border-green-400/30">
                <svg className="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </div>
              <div>
                <h2 className="text-2xl font-bold text-white">Preferences</h2>
                <p className="text-white/60">Customize your app experience</p>
              </div>
            </div>

            {/* Measurement Units */}
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-white mb-4">Measurement Units</h3>
              <div data-testid="units-select" className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Metric Card */}
                <label className={`relative p-6 rounded-3xl border-2 transition-all duration-200 cursor-pointer ${
                  settings.units === 'metric'
                    ? 'border-blue-400 bg-blue-500/20 shadow-lg shadow-blue-500/20'
                    : 'border-white/20 bg-white/5 hover:border-white/30 hover:bg-white/10'
                }`}>
                  <input
                    type="radio"
                    name="units"
                    value="metric"
                    checked={settings.units === 'metric'}
                    onChange={(e) => handleUnitsChange(e.target.value as 'metric' | 'imperial')}
                    className="sr-only"
                  />
                  <div className="flex flex-col items-center text-center">
                    <h4 className="text-xl font-bold text-white mb-2">Metric</h4>
                    <p className="text-white/70">g, kg, ml, l</p>
                  </div>
                  {settings.units === 'metric' && (
                    <div className="absolute top-4 right-4">
                      <div className="w-6 h-6 bg-blue-400 rounded-full flex items-center justify-center">
                        <CheckIconComponent size="sm" className="text-white" />
                      </div>
                    </div>
                  )}
                </label>

                {/* Imperial Card */}
                <label className={`relative p-6 rounded-3xl border-2 transition-all duration-200 cursor-pointer ${
                  settings.units === 'imperial'
                    ? 'border-blue-400 bg-blue-500/20 shadow-lg shadow-blue-500/20'
                    : 'border-white/20 bg-white/5 hover:border-white/30 hover:bg-white/10'
                }`}>
                  <input
                    type="radio"
                    name="units"
                    value="imperial"
                    checked={settings.units === 'imperial'}
                    onChange={(e) => handleUnitsChange(e.target.value as 'metric' | 'imperial')}
                    className="sr-only"
                  />
                  <div className="flex flex-col items-center text-center">
                    <h4 className="text-xl font-bold text-white mb-2">Imperial</h4>
                    <p className="text-white/70">oz, lb, fl oz, cups</p>
                  </div>
                  {settings.units === 'imperial' && (
                    <div className="absolute top-4 right-4">
                      <div className="w-6 h-6 bg-blue-400 rounded-full flex items-center justify-center">
                        <CheckIconComponent size="sm" className="text-white" />
                      </div>
                    </div>
                  )}
                </label>
              </div>
            </div>
          </div>
        </section>

        {/* Action Buttons */}
        <section className="mb-8">
          <div className="card-glass rounded-3xl p-6">
            <h2 className="text-xl font-semibold mb-6 flex items-center space-x-3">
              <div className="p-2 bg-orange-500/20 rounded-xl border border-orange-400/30">
                <svg className="w-5 h-5 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
                </svg>
              </div>
              <span>Actions</span>
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Save Settings */}
              <button
                data-testid="save-settings-button"
                onClick={handleSaveSettings}
                disabled={isSaving}
                className="flex items-center justify-center space-x-2 bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
              >
                {isSaving ? (
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-300"></div>
                ) : (
                  <CheckIconComponent size="sm" />
                )}
                <span>{isSaving ? 'Saving...' : 'Save Settings'}</span>
              </button>

              {/* Export Data */}
              <button
                data-testid="export-data-button"
                onClick={handleExportData}
                disabled={isExporting}
                className="flex items-center justify-center space-x-2 bg-green-500/20 hover:bg-green-500/30 border border-green-400/30 hover:border-green-400/50 text-green-300 hover:text-green-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
              >
                {isExporting ? (
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-green-300"></div>
                ) : (
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                )}
                <span>{isExporting ? 'Exporting...' : 'Export Data'}</span>
              </button>

              {/* Reset to Defaults */}
              <button
                data-testid="reset-to-defaults-button"
                onClick={handleResetToDefaults}
                className="flex items-center justify-center space-x-2 bg-red-500/20 hover:bg-red-500/30 border border-red-400/30 hover:border-red-400/50 text-red-300 hover:text-red-200 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <span>Reset to Defaults</span>
              </button>
            </div>
          </div>
        </section>

        {/* About Section */}
        <section className="mb-8">
          <div className="card-glass rounded-3xl p-6">
            <div className="flex items-center space-x-3 mb-6">
              <div className="p-3 bg-purple-500/20 rounded-2xl border border-purple-400/30">
                <InfoIconComponent size="md" className="text-purple-400" />
              </div>
              <div>
                <h2 className="text-2xl font-bold text-white">About</h2>
                <p className="text-white/60">App information and licensing</p>
              </div>
            </div>

            <div className="text-center space-y-6">
              <div>
                <p className="text-white/80 text-lg">
                  Copyright © 2025 by Marco van Hylckama Vlieg
                </p>
              </div>

              <div>
                <a
                  href="https://ai-created.com/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-400 hover:text-blue-300 underline text-lg"
                >
                  https://ai-created.com/
                </a>
              </div>

              <div>
                <button
                  data-testid="license-button"
                  onClick={loadLicense}
                  className="bg-purple-500/20 hover:bg-purple-500/30 border border-purple-400/30 hover:border-purple-400/50 text-purple-300 hover:text-purple-200 py-3 px-8 rounded-3xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                >
                  License
                </button>
              </div>
            </div>
          </div>
        </section>
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

      {/* License Dialog */}
      {showLicense && (
        <div data-testid="license-dialog" className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className="card-glass rounded-3xl p-6 max-w-2xl w-full max-h-[80vh] overflow-hidden">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-semibold">License</h3>
              <button
                data-testid="close-license-button"
                onClick={() => setShowLicense(false)}
                className="p-2 text-white/60 hover:text-white transition-colors rounded-xl hover:bg-white/10"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="overflow-y-auto max-h-[60vh] text-sm text-white/80 whitespace-pre-wrap font-mono">
              {licenseContent}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
