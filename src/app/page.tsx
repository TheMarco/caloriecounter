'use client';

import { useEffect, useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { initializeIDB, setTodayCalorieOffset, setCalorieOffset, getTodayCalorieOffset, getCalorieOffset } from '@/utils/idb';
import { BarcodeScanner } from '@/components/BarcodeScanner';
import { VoiceInput } from '@/components/VoiceInput';
import { TextInput } from '@/components/TextInput';
import { PhotoCapture } from '@/components/PhotoCapture';
import { FoodConfirmDialog } from '@/components/FoodConfirmDialog';
import { EditEntryDialog } from '@/components/EditEntryDialog';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { LoginForm } from '@/components/LoginForm';

import { TabbedTotalCard } from '@/components/TabbedTotalCard';
import { CalorieOffset } from '@/components/CalorieOffset';
import { CalorieOffsetDialog } from '@/components/CalorieOffsetDialog';
import { EntryList } from '@/components/EntryList';
import { useBarcode } from '@/hooks/useBarcode';
import { useVoiceInput } from '@/hooks/useVoiceInput';
import { useTextInput } from '@/hooks/useTextInput';
import { usePhoto } from '@/hooks/usePhoto';
import { useSettings } from '@/hooks/useSettings';
import { useTodayEntries } from '@/hooks/useTodayEntries';
import { useDayEntries } from '@/hooks/useDayEntries';
import { updateEntry } from '@/utils/idb';
import type { Entry, MacroType } from '@/types';
import {
  HomeIconComponent,
  ChartIconComponent,
  SettingsIconComponent,
  BarcodeIconComponent,
  MicrophoneIconComponent,
  PencilIconComponent,
  CameraIconComponent
} from '@/components/icons';

export default function Home() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const selectedDate = searchParams.get('date');
  const isHistoricalView = !!selectedDate;

  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState<MacroType>('calories');
  const [editingEntry, setEditingEntry] = useState<Entry | null>(null);
  const [isEditLoading, setIsEditLoading] = useState(false);
  const [deleteConfirmEntry, setDeleteConfirmEntry] = useState<Entry | null>(null);
  const [isDeleteLoading, setIsDeleteLoading] = useState(false);
  const [calorieOffset, setLocalCalorieOffset] = useState<number>(0);
  const [showOffsetDialog, setShowOffsetDialog] = useState(false);
  const [isOffsetLoading, setIsOffsetLoading] = useState(false);
  const barcode = useBarcode(isHistoricalView ? selectedDate || undefined : undefined);
  const voice = useVoiceInput(isHistoricalView ? selectedDate || undefined : undefined);
  const textInput = useTextInput(isHistoricalView ? selectedDate || undefined : undefined);
  const photo = usePhoto(isHistoricalView ? selectedDate || undefined : undefined);
  const todayEntries = useTodayEntries();
  const dayEntries = useDayEntries(selectedDate || '');
  const { settings } = useSettings();

  // Use appropriate data source based on view mode
  const currentEntries = isHistoricalView ? dayEntries : todayEntries;

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

  // Load calorie offset on mount and when view changes
  useEffect(() => {
    if (!isAuthenticated) return;

    const loadCalorieOffset = async () => {
      try {
        let offset: number;
        if (isHistoricalView && selectedDate) {
          offset = await getCalorieOffset(selectedDate);
        } else {
          offset = await getTodayCalorieOffset();
        }
        setLocalCalorieOffset(offset);
      } catch (error) {
        console.error('Failed to load calorie offset:', error);
        setLocalCalorieOffset(0);
      }
    };

    loadCalorieOffset();
  }, [isAuthenticated, isHistoricalView, selectedDate]);

  // Sync calorie offset with current view
  useEffect(() => {
    if (isHistoricalView) {
      setLocalCalorieOffset(dayEntries.calorieOffset);
    } else {
      // For today view, we'll get it from the component
    }
  }, [isHistoricalView, dayEntries.calorieOffset]);

  // Refresh entries when any input method completes
  useEffect(() => {
    if (!barcode.isScanning && !barcode.isLoading && !barcode.isProcessing && !barcode.showConfirmDialog &&
        !voice.isProcessing && !voice.showConfirmDialog &&
        !textInput.isProcessing && !textInput.showConfirmDialog &&
        !photo.isCapturing && !photo.isProcessing && !photo.showConfirmDialog) {
      console.log('🔄 Main page: Triggering entries refresh');
      if (isHistoricalView) {
        currentEntries.refreshData();
      } else {
        todayEntries.refreshEntries();
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [barcode.isScanning, barcode.isLoading, barcode.isProcessing, barcode.showConfirmDialog, voice.isProcessing, voice.showConfirmDialog, textInput.isProcessing, textInput.showConfirmDialog, photo.isCapturing, photo.isProcessing, photo.showConfirmDialog, isHistoricalView]);

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
      if (isHistoricalView) {
        await currentEntries.refreshData();
      } else {
        todayEntries.refreshEntries();
      }
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
      if (isHistoricalView) {
        await currentEntries.deleteEntry(deleteConfirmEntry.id);
      } else {
        await todayEntries.deleteEntry(deleteConfirmEntry.id);
      }
      // Entries will be refreshed by the delete function
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

  const handleOffsetChange = (offset: number) => {
    setLocalCalorieOffset(offset);
  };

  const handleOffsetEditClick = () => {
    setShowOffsetDialog(true);
  };

  const handleOffsetSave = async (offset: number) => {
    try {
      setIsOffsetLoading(true);

      if (isHistoricalView && selectedDate) {
        await setCalorieOffset(selectedDate, offset);
        await currentEntries.refreshData();
        setLocalCalorieOffset(offset);
      } else {
        await setTodayCalorieOffset(offset);
        await todayEntries.refreshEntries();
        setLocalCalorieOffset(offset);
      }

      setShowOffsetDialog(false);
    } catch (error) {
      console.error('Failed to save calorie offset:', error);
    } finally {
      setIsOffsetLoading(false);
    }
  };

  const handleOffsetCancel = () => {
    setShowOffsetDialog(false);
  };

  // Helper function to format date for entry list title
  const getEntryListTitle = () => {
    if (isHistoricalView && selectedDate) {
      const date = new Date(selectedDate);
      const formattedDate = date.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
      return formattedDate;
    }
    return "Today's Entries";
  };

  // Helper function to get subtitle for entry list
  const getEntryListSubtitle = () => {
    if (isHistoricalView) {
      return "food logged today";
    }
    return "Your daily meal log";
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

  if (currentEntries.isLoading) {
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
          {isHistoricalView ? (
            <div className="flex items-center justify-between">
              <button
                onClick={() => router.push('/history')}
                className="p-2 rounded-full bg-white/10 hover:bg-white/20 transition-all"
              >
                <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <div className="text-center">
                <h1 className="text-lg font-bold text-white">{currentEntries.formattedDate}</h1>
                <p className="text-white/60 text-sm">Edit entries for this day</p>
              </div>
              <div className="w-10 h-10"></div> {/* Spacer for centering */}
            </div>
          ) : (
            <div className="grid grid-cols-4 gap-3">
            <button
              data-testid="header-scan-button"
              onClick={handleScan}
              className="flex flex-col items-center justify-center p-4 rounded-3xl bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/40 text-blue-300 transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-blue-500/20 active:scale-95"
              title="Scan barcode"
            >
              <div className="mb-2">
                <BarcodeIconComponent size="lg" />
              </div>
              <span className="text-xs font-medium text-blue-200">Scan</span>
            </button>

            <button
              data-testid="header-voice-button"
              onClick={handleVoice}
              className="flex flex-col items-center justify-center p-4 rounded-3xl bg-green-500/20 hover:bg-green-500/30 border border-green-400/40 text-green-300 transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-green-500/20 active:scale-95"
              title="Voice input"
            >
              <div className="mb-2">
                <MicrophoneIconComponent size="lg" />
              </div>
              <span className="text-xs font-medium text-green-200">Voice</span>
            </button>

            <button
              data-testid="header-text-button"
              onClick={handleText}
              className="flex flex-col items-center justify-center p-4 rounded-3xl bg-purple-500/20 hover:bg-purple-500/30 border border-purple-400/40 text-purple-300 transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-purple-500/20 active:scale-95"
              title="Type food"
            >
              <div className="mb-2">
                <PencilIconComponent size="lg" />
              </div>
              <span className="text-xs font-medium text-purple-200">Type</span>
            </button>

            <button
              data-testid="header-photo-button"
              onClick={handlePhoto}
              className="flex flex-col items-center justify-center p-4 rounded-3xl bg-orange-500/20 hover:bg-orange-500/30 border border-orange-400/40 text-orange-300 transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-orange-500/20 active:scale-95"
              title="Take photo"
            >
              <div className="mb-2">
                <CameraIconComponent size="lg" />
              </div>
              <span className="text-xs font-medium text-orange-200">Photo</span>
            </button>
            </div>
          )}
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
            {/* Day's Total Card */}
            <TabbedTotalCard
              totals={currentEntries.macroTotals}
              targets={{
                calories: settings.dailyTarget,
                fat: settings.fatTarget,
                carbs: settings.carbsTarget,
                protein: settings.proteinTarget,
              }}
              date={currentEntries.date || (isHistoricalView ? selectedDate : undefined)}
              calorieOffset={isHistoricalView ? currentEntries.calorieOffset : calorieOffset}
              activeTab={activeTab}
              onTabChange={setActiveTab}
            />

            {/* Calorie Offset */}
            <CalorieOffset
              onOffsetChange={handleOffsetChange}
              onEditClick={handleOffsetEditClick}
              currentOffset={isHistoricalView ? currentEntries.calorieOffset : calorieOffset}
            />

            {/* Day's Entries */}
            <EntryList
              entries={currentEntries.entries}
              onDelete={currentEntries.deleteEntry}
              onEdit={handleEditEntry}
              isLoading={currentEntries.isRefreshing}
              onDeleteConfirm={handleDeleteConfirm}
              title={getEntryListTitle()}
              subtitle={getEntryListSubtitle()}
              showAddFood={isHistoricalView}
              onScan={isHistoricalView ? handleScan : undefined}
              onVoice={isHistoricalView ? handleVoice : undefined}
              onText={isHistoricalView ? handleText : undefined}
              onPhoto={isHistoricalView ? handlePhoto : undefined}
            />
          </>
        )}
      </main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-black/20 backdrop-blur-xl border-t border-white/10 transition-theme">
        <div className="max-w-md mx-auto px-6">
          <div className="flex justify-around py-4">
            {isHistoricalView ? (
              // Historical view - highlight History tab
              <>
                <a href="/" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
                  <div className="mb-1">
                    <HomeIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
                  </div>
                  <div className="text-xs font-medium">Today</div>
                </a>
                <button className="flex flex-col items-center py-2 px-4 text-blue-400">
                  <div className="mb-1">
                    <ChartIconComponent size="lg" solid className="text-blue-400" />
                  </div>
                  <div className="text-xs font-medium">History</div>
                </button>
                <a href="/settings" className="flex flex-col items-center py-2 px-4 text-white/60 hover:text-white transition-all duration-200 hover:scale-105">
                  <div className="mb-1">
                    <SettingsIconComponent size="lg" className="text-white/60 hover:text-white transition-colors" />
                  </div>
                  <div className="text-xs font-medium">Settings</div>
                </a>
              </>
            ) : (
              // Today view - highlight Today tab
              <>
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
              </>
            )}
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

      {/* Calorie Offset Dialog */}
      <CalorieOffsetDialog
        isOpen={showOffsetDialog}
        currentOffset={isHistoricalView ? currentEntries.calorieOffset : calorieOffset}
        isLoading={isOffsetLoading}
        onSave={handleOffsetSave}
        onCancel={handleOffsetCancel}
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
