'use client';

import { useState } from 'react';
import type { Entry } from '@/types';
import {
  MicrophoneIconComponent,
  PencilIconComponent,
  DeleteIconComponent,
  BarcodeIconComponent
} from '@/components/icons';
import { ConfirmDialog } from '@/components/ConfirmDialog';

interface EntryListProps {
  entries: Entry[];
  onDelete: (id: string) => void;
  onEdit?: (entry: Entry) => void;
  isLoading?: boolean;
}

export function EntryList({ entries, onDelete, onEdit, isLoading }: EntryListProps) {
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{
    isOpen: boolean;
    entry: Entry | null;
  }>({ isOpen: false, entry: null });

  const handleDeleteClick = (entry: Entry) => {
    setConfirmDelete({ isOpen: true, entry });
  };

  const handleConfirmDelete = async () => {
    if (!confirmDelete.entry) return;

    try {
      setDeletingId(confirmDelete.entry.id);
      await onDelete(confirmDelete.entry.id);
      setConfirmDelete({ isOpen: false, entry: null });
    } catch (error) {
      console.error('Failed to delete entry:', error);
    } finally {
      setDeletingId(null);
    }
  };

  const handleCancelDelete = () => {
    setConfirmDelete({ isOpen: false, entry: null });
  };

  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  };

  const getMethodIcon = (method: string) => {
    switch (method) {
      case 'barcode':
        return <BarcodeIconComponent size="sm" className="text-gray-600 dark:text-gray-400" />;
      case 'voice':
        return <MicrophoneIconComponent size="sm" className="text-gray-600 dark:text-gray-400" />;
      case 'text':
        return <PencilIconComponent size="sm" className="text-gray-600 dark:text-gray-400" />;
      default:
        return <PencilIconComponent size="sm" className="text-gray-600 dark:text-gray-400" />;
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 mb-8 transition-theme">
        <div className="p-6 border-b border-gray-200/50 dark:border-gray-700/50">
          <h3 className="text-lg font-semibold text-black dark:text-white">Today&apos;s Entries</h3>
        </div>
        <div className="p-6">
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse">
                <div className="flex items-center space-x-4">
                  <div className="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-xl"></div>
                  <div className="flex-1">
                    <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded-lg w-3/4 mb-2"></div>
                    <div className="h-3 bg-gray-200 dark:bg-gray-700 rounded-lg w-1/2"></div>
                  </div>
                  <div className="w-16 h-4 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (entries.length === 0) {
    return (
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 mb-8 transition-theme hover:shadow-md hover:scale-105 duration-200">
        <div className="p-6 border-b border-gray-200/50 dark:border-gray-700/50">
          <h3 className="text-lg font-semibold text-black dark:text-white">Today&apos;s Entries</h3>
        </div>
        <div className="p-8 text-center">
          <div className="text-5xl mb-4">🍽️</div>
          <p className="text-gray-700 dark:text-gray-200 mb-2 font-medium">No entries yet today</p>
          <p className="text-sm text-gray-600 dark:text-gray-400">
            Add your first meal using the buttons above!
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-800/50 mb-8 transition-theme hover:shadow-md hover:scale-105 duration-200">
      <div className="p-6 border-b border-gray-200/50 dark:border-gray-700/50">
        <h3 className="text-lg font-semibold text-black dark:text-white">Today&apos;s Entries</h3>
        <p className="text-sm text-gray-600 dark:text-gray-400 mt-1 font-medium">{entries.length} item{entries.length !== 1 ? 's' : ''}</p>
      </div>
      <div className="divide-y divide-gray-200/50 dark:divide-gray-700/50">
        {entries.map((entry) => (
          <div
            key={entry.id}
            className="p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-all duration-200"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4 flex-1">
                {/* Method Icon */}
                <div className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center" title={`Added via ${entry.method}`}>
                  {getMethodIcon(entry.method)}
                </div>

                {/* Food Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center space-x-2 mb-1">
                    <h4 className="font-semibold text-black dark:text-white truncate text-base">
                      {entry.food}
                    </h4>
                    {entry.confidence && entry.confidence < 0.8 && (
                      <span className="text-xs bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300 px-2 py-1 rounded-lg font-medium">
                        Low confidence
                      </span>
                    )}
                  </div>
                  <div className="flex items-center space-x-2 text-sm text-gray-600 dark:text-gray-400 font-medium">
                    <span>{entry.qty} {entry.unit}</span>
                    <span>•</span>
                    <span>{formatTime(entry.ts)}</span>
                  </div>
                </div>

                {/* Calories */}
                <div className="text-right">
                  <div className="font-bold text-lg text-black dark:text-white">
                    {entry.kcal}
                  </div>
                  <div className="text-xs text-gray-600 dark:text-gray-400 font-medium">
                    cal
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center space-x-2 ml-4">
                {onEdit && (
                  <button
                    onClick={() => onEdit(entry)}
                    className="p-3 text-gray-500 dark:text-gray-400 hover:text-blue-600 dark:hover:text-blue-400 transition-colors rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800"
                    title="Edit entry"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                )}
                
                <button
                  onClick={() => handleDeleteClick(entry)}
                  disabled={deletingId === entry.id}
                  className="p-3 text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors disabled:opacity-50 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800"
                  title="Delete entry"
                >
                  {deletingId === entry.id ? (
                    <div className="w-5 h-5 animate-spin rounded-full border-2 border-red-600 border-t-transparent"></div>
                  ) : (
                    <DeleteIconComponent size="sm" className="w-5 h-5 text-gray-500 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400" />
                  )}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Confirmation Dialog */}
      <ConfirmDialog
        isOpen={confirmDelete.isOpen}
        title="Delete Entry"
        message={
          confirmDelete.entry
            ? `Are you sure you want to delete "${confirmDelete.entry.food}"? This action cannot be undone.`
            : ''
        }
        confirmText="Delete"
        cancelText="Cancel"
        onConfirm={handleConfirmDelete}
        onCancel={handleCancelDelete}
        isLoading={deletingId === confirmDelete.entry?.id}
        variant="danger"
      />
    </div>
  );
}
