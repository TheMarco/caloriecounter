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
        return <BarcodeIconComponent size="sm" className="text-blue-400" />;
      case 'voice':
        return <MicrophoneIconComponent size="sm" className="text-green-400" />;
      case 'text':
        return <PencilIconComponent size="sm" className="text-purple-400" />;
      default:
        return <PencilIconComponent size="sm" className="text-purple-400" />;
    }
  };

  if (isLoading) {
    return (
      <div className="card-glass rounded-3xl mb-8 transition-all duration-300 shadow-2xl">
        <div className="p-6 border-b border-white/20">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-orange-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 className="text-xl font-semibold text-white">Today&apos;s Entries</h3>
              <p className="text-white/60 text-sm">Loading your meals...</p>
            </div>
          </div>
        </div>
        <div className="p-6">
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse">
                <div className="flex items-center space-x-4">
                  <div className="w-10 h-10 bg-white/20 rounded-xl"></div>
                  <div className="flex-1">
                    <div className="h-4 bg-white/20 rounded-lg w-3/4 mb-2"></div>
                    <div className="h-3 bg-white/20 rounded-lg w-1/2"></div>
                  </div>
                  <div className="w-16 h-4 bg-white/20 rounded-lg"></div>
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
      <div className="card-glass card-glass-hover rounded-3xl mb-8 transition-all duration-300 shadow-2xl">
        <div className="p-6 border-b border-white/20">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-orange-500/20 rounded-2xl">
              <svg className="w-6 h-6 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 className="text-xl font-semibold text-white">Today&apos;s Entries</h3>
              <p className="text-white/60 text-sm">Your daily meal log</p>
            </div>
          </div>
        </div>
        <div className="p-8 text-center">
          <div className="text-5xl mb-4">🍽️</div>
          <p className="text-white/80 mb-2 font-medium">No entries yet today</p>
          <p className="text-sm text-white/60">
            Add your first meal using the buttons above!
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="card-glass card-glass-hover rounded-3xl mb-8 transition-all duration-300 shadow-2xl">
      <div className="p-6 border-b border-white/20">
        <div className="flex items-center space-x-4">
          <div className="p-3 bg-orange-500/20 rounded-2xl">
            <svg className="w-6 h-6 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div>
            <h3 className="text-xl font-semibold text-white">Today&apos;s Entries</h3>
            <p className="text-white/60 text-sm">{entries.length} item{entries.length !== 1 ? 's' : ''} logged</p>
          </div>
        </div>
      </div>
      <div className="divide-y divide-white/10">
        {entries.map((entry) => (
          <div
            key={entry.id}
            className="p-6 hover:bg-white/5 transition-all duration-200"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4 flex-1">
                {/* Method Icon */}
                <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center backdrop-blur-sm" title={`Added via ${entry.method}`}>
                  {getMethodIcon(entry.method)}
                </div>

                {/* Food Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center space-x-2 mb-1">
                    <h4 className="font-semibold text-white truncate text-base">
                      {entry.food}
                    </h4>
                    {entry.confidence && entry.confidence < 0.8 && (
                      <span className="text-xs bg-yellow-500/20 border border-yellow-400/30 text-yellow-300 px-2 py-1 rounded-lg font-medium backdrop-blur-sm">
                        Low confidence
                      </span>
                    )}
                  </div>
                  <div className="flex items-center space-x-2 text-sm text-white/60 font-medium">
                    <span>{entry.qty} {entry.unit}</span>
                    <span>•</span>
                    <span>{formatTime(entry.ts)}</span>
                  </div>
                </div>

                {/* Calories */}
                <div className="text-right">
                  <div className="font-bold text-lg text-white">
                    {entry.kcal}
                  </div>
                  <div className="text-xs text-white/60 font-medium">
                    cal
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center space-x-2 ml-4">
                {onEdit && (
                  <button
                    onClick={() => onEdit(entry)}
                    className="p-3 text-white/60 hover:text-blue-400 transition-colors rounded-xl hover:bg-white/10 backdrop-blur-sm"
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
                  className="p-3 text-white/60 hover:text-red-400 transition-colors disabled:opacity-50 rounded-xl hover:bg-white/10 backdrop-blur-sm"
                  title="Delete entry"
                >
                  {deletingId === entry.id ? (
                    <div className="w-5 h-5 animate-spin rounded-full border-2 border-red-400 border-t-transparent"></div>
                  ) : (
                    <DeleteIconComponent size="sm" className="w-5 h-5 text-white/60 hover:text-red-400" />
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
