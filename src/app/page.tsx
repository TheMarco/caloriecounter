'use client';

import { useEffect, useState } from 'react';
import { initializeIDB } from '@/utils/idb';
import { BarcodeScanner } from '@/components/BarcodeScanner';
import { VoiceInput } from '@/components/VoiceInput';
import { TextInput } from '@/components/TextInput';
import { FoodConfirmDialog } from '@/components/FoodConfirmDialog';
import { AddFab } from '@/components/AddFab';
import { TotalCard } from '@/components/TotalCard';
import { EntryList } from '@/components/EntryList';
import { useBarcode } from '@/hooks/useBarcode';
import { useVoiceInput } from '@/hooks/useVoiceInput';
import { useTextInput } from '@/hooks/useTextInput';
import { useTodayEntries } from '@/hooks/useTodayEntries';
import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent
} from '@/components/icons';

export default function Home() {
  const [isLoading, setIsLoading] = useState(true);
  const barcode = useBarcode();
  const voice = useVoiceInput();
  const textInput = useTextInput();
  const todayEntries = useTodayEntries();

  useEffect(() => {
    const loadData = async () => {
      try {
        initializeIDB();
      } catch (error) {
        console.error('Failed to initialize IDB:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadData();
  }, []);

  // Refresh entries when any input method completes
  useEffect(() => {
    if (!barcode.isScanning && !barcode.isLoading &&
        !voice.isProcessing && !voice.showConfirmDialog &&
        !textInput.isProcessing && !textInput.showConfirmDialog) {
      console.log('🔄 Main page: Triggering entries refresh');
      todayEntries.refreshEntries();
    }
  }, [barcode.isScanning, barcode.isLoading, voice.isProcessing, voice.showConfirmDialog, textInput.isProcessing, textInput.showConfirmDialog, todayEntries.refreshEntries]);

  const handleScan = () => {
    barcode.startScanning();
  };

  const handleVoice = () => {
    voice.startListening();
  };

  const handleText = () => {
    textInput.startTextInput();
  };



  const handleBarcodeDetected = async (code: string) => {
    try {
      console.log('🎯 Main page: Barcode detected:', code);
      await barcode.handleBarcodeDetected(code);
      console.log('✅ Main page: Barcode processing completed');
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('❌ Main page: Failed to process barcode:', error);
    }
  };

  const handleVoiceConfirm = async (data: { food: string; qty: number; unit: string; kcal: number }) => {
    try {
      await voice.handleConfirmFood(data);
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('Failed to save voice entry:', error);
    }
  };

  const handleTextConfirm = async (data: { food: string; qty: number; unit: string; kcal: number }) => {
    try {
      await textInput.handleConfirmFood(data);
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('Failed to save text entry:', error);
    }
  };

  if (isLoading || todayEntries.isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-black mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white dark:bg-black transition-theme">
      {/* Header */}
      <header className="bg-white/80 dark:bg-black/80 backdrop-blur-xl border-b border-gray-200/50 dark:border-gray-800/50 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-4">
          <h1 className="text-2xl font-bold text-center text-black dark:text-white">Calorie Counter</h1>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-md mx-auto px-6 py-6 pb-24">
        {todayEntries.isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 dark:border-blue-400 mx-auto mb-4"></div>
            <p className="text-gray-700 dark:text-gray-200">Loading your data...</p>
          </div>
        )}

        {/* Today's Total Card */}
        <TotalCard
          total={todayEntries.total}
          date={todayEntries.todayDate}
        />

        {/* Quick Add Buttons */}
        <AddFab
          onScan={handleScan}
          onVoice={handleVoice}
          onText={handleText}
        />

        {/* Today's Entries */}
        <EntryList
          entries={todayEntries.entries}
          onDelete={todayEntries.deleteEntry}
          isLoading={todayEntries.isLoading}
        />
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white/80 dark:bg-black/80 backdrop-blur-xl border-t border-gray-200/50 dark:border-gray-800/50 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-3">
            <button className="flex flex-col items-center py-2 px-4 text-blue-500 dark:text-blue-400">
              <div className="mb-1">
                <HomeIconComponent size="lg" solid className="text-blue-500 dark:text-blue-400" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </button>
            <a href="/history" className="flex flex-col items-center py-2 px-4 text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors">
              <div className="mb-1">
                <ChartIconComponent size="lg" className="text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">History</div>
            </a>
            <a href="/settings" className="flex flex-col items-center py-2 px-4 text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors">
              <div className="mb-1">
                <SettingsIconComponent size="lg" className="text-gray-600 dark:text-gray-400 hover:text-black dark:hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">Settings</div>
            </a>
          </div>
        </div>
      </nav>

      {/* Barcode Scanner */}
      <BarcodeScanner
        isActive={barcode.isScanning}
        onDetect={handleBarcodeDetected}
        onError={barcode.handleScanError}
        onClose={barcode.stopScanning}
      />

      {/* Voice Input */}
      <VoiceInput
        isActive={voice.isListening}
        onTranscript={voice.handleTranscript}
        onError={voice.handleVoiceError}
        onClose={voice.stopListening}
      />

      {/* Text Input */}
      <TextInput
        isActive={textInput.isActive}
        onFoodParsed={textInput.handleFoodParsed}
        onError={textInput.handleTextError}
        onClose={textInput.stopTextInput}
      />

      {/* Voice Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={voice.showConfirmDialog}
        foodData={voice.parsedFood}
        isLoading={voice.isProcessing}
        onConfirm={handleVoiceConfirm}
        onCancel={voice.handleCancelConfirm}
      />

      {/* Text Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={textInput.showConfirmDialog}
        foodData={textInput.parsedFood}
        isLoading={textInput.isProcessing}
        onConfirm={handleTextConfirm}
        onCancel={textInput.handleCancelConfirm}
      />
    </div>
  );
}
