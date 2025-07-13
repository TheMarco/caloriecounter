'use client';

import { useEffect, useState } from 'react';
import { initializeIDB } from '@/utils/idb';
import { BarcodeScanner } from '@/components/BarcodeScanner';
import { VoiceInput } from '@/components/VoiceInput';
import { TextInput } from '@/components/TextInput';
import { PhotoCapture } from '@/components/PhotoCapture';
import { FoodConfirmDialog } from '@/components/FoodConfirmDialog';
import { EditEntryDialog } from '@/components/EditEntryDialog';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { LoginForm } from '@/components/LoginForm';
import { AddFab } from '@/components/AddFab';
import { TabbedTotalCard } from '@/components/TabbedTotalCard';
import { EntryList } from '@/components/EntryList';
import { useBarcode } from '@/hooks/useBarcode';
import { useVoiceInput } from '@/hooks/useVoiceInput';
import { useTextInput } from '@/hooks/useTextInput';
import { usePhoto } from '@/hooks/usePhoto';
import { useSettings } from '@/hooks/useSettings';
import { useTodayEntries } from '@/hooks/useTodayEntries';
import { updateEntry } from '@/utils/idb';
import type { Entry, MacroType } from '@/types';
import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent
} from '@/components/icons';

export default function Home() {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState<MacroType>('calories');
  const [editingEntry, setEditingEntry] = useState<Entry | null>(null);
  const [isEditLoading, setIsEditLoading] = useState(false);
  const [deleteConfirmEntry, setDeleteConfirmEntry] = useState<Entry | null>(null);
  const [isDeleteLoading, setIsDeleteLoading] = useState(false);
  const barcode = useBarcode();
  const voice = useVoiceInput();
  const textInput = useTextInput();
  const photo = usePhoto();
  const todayEntries = useTodayEntries();
  const { settings } = useSettings();

  useEffect(() => {
    const loadData = async () => {
      try {
        // Check authentication
        const authCookie = document.cookie
          .split('; ')
          .find(row => row.startsWith('calorie-auth='));
        const isAuth = authCookie?.split('=')[1] === 'authenticated';
        setIsAuthenticated(isAuth);

        if (isAuth) {
          await initializeIDB();
        }
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
    if (!barcode.isScanning && !barcode.isLoading && !barcode.isProcessing && !barcode.showConfirmDialog &&
        !voice.isProcessing && !voice.showConfirmDialog &&
        !textInput.isProcessing && !textInput.showConfirmDialog &&
        !photo.isCapturing && !photo.isProcessing && !photo.showConfirmDialog) {
      console.log('🔄 Main page: Triggering entries refresh');
      todayEntries.refreshEntries();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [barcode.isScanning, barcode.isLoading, barcode.isProcessing, barcode.showConfirmDialog, voice.isProcessing, voice.showConfirmDialog, textInput.isProcessing, textInput.showConfirmDialog, photo.isCapturing, photo.isProcessing, photo.showConfirmDialog]);

  const handleScan = () => {
    barcode.startScanning();
  };

  const handleVoice = () => {
    voice.startListening();
  };

  const handleText = () => {
    textInput.startTextInput();
  };

  const handlePhoto = () => {
    photo.startCapture();
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

  const handleBarcodeConfirm = async (data: { food: string; qty: number; unit: string; kcal: number }) => {
    try {
      await barcode.handleConfirmFood(data);
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('Failed to save barcode entry:', error);
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

  const handlePhotoCapture = async (imageData: string, details?: { plateSize: string; servingType: string; additionalDetails: string }) => {
    try {
      console.log('📸 Main page: Photo captured, size:', imageData.length);
      console.log('📸 Main page: Using units:', settings.units);
      console.log('📸 Main page: Additional details:', details);
      await photo.handlePhotoCapture(imageData, settings.units, details);
      console.log('✅ Main page: Photo processing completed');
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('❌ Main page: Failed to process photo:', error);
      console.error('❌ Error details:', error);
      // Show error to user
      alert(`Photo processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const handlePhotoConfirm = async (data: { food: string; qty: number; unit: string; kcal: number }) => {
    try {
      await photo.handleConfirmFood(data);
      // Entries will be refreshed by the useEffect above
    } catch (error) {
      console.error('Failed to save photo entry:', error);
    }
  };

  const handlePhotoClearError = () => {
    // Clear the error and restart capture
    photo.handleCancelConfirm(); // This should clear the error state
    photo.startCapture();
  };

  const handlePhotoEditDetails = () => {
    // Close the confirmation dialog and restart photo capture
    photo.handleCancelConfirm();
    // Start photo capture again so user can retake and add details
    setTimeout(() => {
      photo.startCapture();
    }, 100); // Small delay to ensure state is cleared
  };

  const handleEditEntry = (entry: Entry) => {
    setEditingEntry(entry);
  };

  const handleSaveEdit = async (updatedEntry: Entry) => {
    try {
      setIsEditLoading(true);

      // Calculate proportional macro values if quantity changed
      const originalEntry = editingEntry;
      if (originalEntry && originalEntry.qty !== updatedEntry.qty) {
        const ratio = updatedEntry.qty / originalEntry.qty;
        updatedEntry.kcal = Math.round(originalEntry.kcal * ratio);
        updatedEntry.fat = Math.round((originalEntry.fat || 0) * ratio * 10) / 10;
        updatedEntry.carbs = Math.round((originalEntry.carbs || 0) * ratio * 10) / 10;
        updatedEntry.protein = Math.round((originalEntry.protein || 0) * ratio * 10) / 10;
      }

      await updateEntry(updatedEntry.id, {
        food: updatedEntry.food,
        qty: updatedEntry.qty,
        unit: updatedEntry.unit,
        kcal: updatedEntry.kcal,
        fat: updatedEntry.fat || 0,
        carbs: updatedEntry.carbs || 0,
        protein: updatedEntry.protein || 0,
      });
      setEditingEntry(null);
      // Refresh entries to show the updated data
      todayEntries.refreshEntries();
    } catch (error) {
      console.error('Failed to update entry:', error);
    } finally {
      setIsEditLoading(false);
    }
  };

  const handleCancelEdit = () => {
    setEditingEntry(null);
  };

  const handleDeleteConfirm = (entry: Entry) => {
    setDeleteConfirmEntry(entry);
  };

  const handleConfirmDelete = async () => {
    if (!deleteConfirmEntry) return;

    try {
      setIsDeleteLoading(true);
      await todayEntries.deleteEntry(deleteConfirmEntry.id);
      // Entries will be refreshed by the useEffect
    } catch (error) {
      console.error('Failed to delete entry:', error);
    } finally {
      setIsDeleteLoading(false);
      setDeleteConfirmEntry(null);
    }
  };

  const handleCancelDelete = () => {
    setDeleteConfirmEntry(null);
  };

  const handleLoginSuccess = async () => {
    setIsAuthenticated(true);
    try {
      await initializeIDB();
    } catch (error) {
      console.error('Failed to initialize IDB after login:', error);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen gradient-bg flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white mx-auto mb-4"></div>
          <p className="text-white/70">Loading...</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <LoginForm onSuccess={handleLoginSuccess} />;
  }

  if (todayEntries.isLoading) {
    return (
      <div className="min-h-screen gradient-bg flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white mx-auto mb-4"></div>
          <p className="text-white/70">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen gradient-bg transition-theme">
      {/* Header */}
      <header className="bg-black/20 backdrop-blur-xl border-b border-white/10 sticky top-0 z-10 transition-theme">
        <div className="max-w-md mx-auto px-6 py-6">
          <div className="flex items-center justify-center space-x-4">
            <img
              src="/icons/icon-192.png"
              alt="Calorie Counter"
              className="w-16 h-16"
            />
            <div className="text-center">
              <h1 className="text-2xl font-bold text-white">Calorie Counter</h1>
              <p className="text-white/70 text-sm">Track your daily nutrition</p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main data-testid="main-content" className="max-w-md mx-auto px-6 py-6 pb-24">
        {/* Only show loading on initial load, not on refreshes */}
        {isLoading && (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white/50 mx-auto mb-4"></div>
            <p className="text-white/70">Loading your data...</p>
          </div>
        )}

        {!isLoading && (
          <>
            {/* Today's Total Card */}
            <TabbedTotalCard
              totals={todayEntries.macroTotals}
              targets={{
                calories: settings.dailyTarget,
                fat: settings.fatTarget,
                carbs: settings.carbsTarget,
                protein: settings.proteinTarget,
              }}
              date={todayEntries.todayDate}
              activeTab={activeTab}
              onTabChange={setActiveTab}
            />

            {/* Quick Add Buttons */}
            <AddFab
              onScan={handleScan}
              onVoice={handleVoice}
              onText={handleText}
              onPhoto={handlePhoto}
            />

            {/* Today's Entries */}
            <EntryList
              entries={todayEntries.entries}
              onDelete={todayEntries.deleteEntry}
              onEdit={handleEditEntry}
              isLoading={todayEntries.isRefreshing}
              onDeleteConfirm={handleDeleteConfirm}
            />
          </>
        )}
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-black/20 backdrop-blur-xl border-t border-white/10 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-4">
            <button className="flex flex-col items-center py-2 px-4 text-blue-400">
              <div className="mb-1">
                <HomeIconComponent size="lg" solid className="text-blue-400" />
              </div>
              <div className="text-xs font-medium">Today</div>
            </button>
            <a href="/history" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
              <div className="mb-1">
                <ChartIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
              </div>
              <div className="text-xs font-medium">History</div>
            </a>
            <a href="/settings" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
              <div className="mb-1">
                <SettingsIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
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
        isProcessing={voice.isProcessing}
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
        units={settings.units}
        error={textInput.error}
      />

      {/* Photo Capture */}
      <PhotoCapture
        isActive={photo.isCapturing}
        onCapture={handlePhotoCapture}
        onError={photo.handleCaptureError}
        onClose={photo.stopCapture}
        isProcessing={photo.isProcessing}
        processingError={photo.error}
        onClearError={handlePhotoClearError}
      />

      {/* Barcode Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={barcode.showConfirmDialog}
        foodData={barcode.parsedFood}
        isLoading={barcode.isProcessing}
        onConfirm={handleBarcodeConfirm}
        onCancel={barcode.handleCancelConfirm}
        method="barcode"
      />

      {/* Voice Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={voice.showConfirmDialog}
        foodData={voice.parsedFood}
        isLoading={voice.isProcessing}
        onConfirm={handleVoiceConfirm}
        onCancel={voice.handleCancelConfirm}
        method="voice"
      />

      {/* Text Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={textInput.showConfirmDialog}
        foodData={textInput.parsedFood}
        isLoading={textInput.isProcessing}
        onConfirm={handleTextConfirm}
        onCancel={textInput.handleCancelConfirm}
        method="text"
      />

      {/* Photo Food Confirmation Dialog */}
      <FoodConfirmDialog
        isOpen={photo.showConfirmDialog}
        foodData={photo.parsedFood}
        isLoading={photo.isProcessing}
        onConfirm={handlePhotoConfirm}
        onCancel={photo.handleCancelConfirm}
        method="photo"
        onEditDetails={handlePhotoEditDetails}
      />

      {/* Edit Entry Dialog */}
      <EditEntryDialog
        isOpen={!!editingEntry}
        entry={editingEntry}
        isLoading={isEditLoading}
        onSave={handleSaveEdit}
        onCancel={handleCancelEdit}
      />

      {/* Delete Confirmation Dialog */}
      <ConfirmDialog
        isOpen={!!deleteConfirmEntry}
        title="Delete Entry"
        message={
          deleteConfirmEntry
            ? `Are you sure you want to delete "${deleteConfirmEntry.food}"? This action cannot be undone.`
            : ''
        }
        confirmText="Delete"
        cancelText="Cancel"
        onConfirm={handleConfirmDelete}
        onCancel={handleCancelDelete}
        isLoading={isDeleteLoading}
        variant="danger"
      />
    </div>
  );
}
