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
        return <BarcodeIconComponent size="sm" className="text-gray-500" />;
      case 'voice':
        return <MicrophoneIconComponent size="sm" className="text-gray-500" />;
      case 'text':
        return <PencilIconComponent size="sm" className="text-gray-500" />;
      default:
        return <PencilIconComponent size="sm" className="text-gray-500" />;
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white rounded-lg shadow-sm border mb-8">
        <div className="p-4 border-b">
          <h3 className="font-semibold">Today&apos;s Entries</h3>
        </div>
        <div className="p-4">
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-gray-200 rounded"></div>
                  <div className="flex-1">
                    <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                    <div className="h-3 bg-gray-200 rounded w-1/2"></div>
                  </div>
                  <div className="w-12 h-4 bg-gray-200 rounded"></div>
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
      <div className="bg-white rounded-lg shadow-sm border mb-8">
        <div className="p-4 border-b">
          <h3 className="font-semibold">Today&apos;s Entries</h3>
        </div>
        <div className="p-8 text-center">
          <div className="text-4xl mb-4">🍽️</div>
          <p className="text-gray-500 mb-2">No entries yet today</p>
          <p className="text-sm text-gray-400">
            Add your first meal using the buttons above!
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-sm border mb-8">
      <div className="p-4 border-b">
        <h3 className="font-semibold">Today&apos;s Entries</h3>
        <p className="text-sm text-gray-500">{entries.length} item{entries.length !== 1 ? 's' : ''}</p>
      </div>
      <div className="divide-y divide-gray-100">
        {entries.map((entry) => (
          <div
            key={entry.id}
            className="p-4 hover:bg-gray-50 transition-colors"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3 flex-1">
                {/* Method Icon */}
                <div className="text-lg" title={`Added via ${entry.method}`}>
                  {getMethodIcon(entry.method)}
                </div>

                {/* Food Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center space-x-2">
                    <h4 className="font-medium text-gray-900 truncate">
                      {entry.food}
                    </h4>
                    {entry.confidence && entry.confidence < 0.8 && (
                      <span className="text-xs bg-yellow-100 text-yellow-800 px-2 py-1 rounded">
                        Low confidence
                      </span>
                    )}
                  </div>
                  <div className="flex items-center space-x-2 text-sm text-gray-500">
                    <span>{entry.qty} {entry.unit}</span>
                    <span>•</span>
                    <span>{formatTime(entry.ts)}</span>
                  </div>
                </div>

                {/* Calories */}
                <div className="text-right">
                  <div className="font-semibold text-gray-900">
                    {entry.kcal} cal
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center space-x-2 ml-4">
                {onEdit && (
                  <button
                    onClick={() => onEdit(entry)}
                    className="p-2 text-gray-400 hover:text-blue-600 transition-colors"
                    title="Edit entry"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                )}
                
                <button
                  onClick={() => handleDeleteClick(entry)}
                  disabled={deletingId === entry.id}
                  className="p-2 text-gray-400 hover:text-red-600 transition-colors disabled:opacity-50"
                  title="Delete entry"
                >
                  {deletingId === entry.id ? (
                    <div className="w-4 h-4 animate-spin rounded-full border-2 border-red-600 border-t-transparent"></div>
                  ) : (
                    <DeleteIconComponent size="sm" className="text-gray-400 hover:text-red-600" />
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
