'use client';


import type { Entry } from '@/types';
import {
  MicrophoneIconComponent,
  PencilIconComponent,
  DeleteIconComponent,
  BarcodeIconComponent
} from '@/components/icons';


interface EntryListProps {
  entries: Entry[];
  onDelete: (id: string) => void;
  onEdit?: (entry: Entry) => void;
  isLoading?: boolean;
  onDeleteConfirm?: (entry: Entry) => void;
}

export function EntryList({ entries, onDelete, onEdit, isLoading, onDeleteConfirm }: EntryListProps) {
  const handleDeleteClick = (entry: Entry) => {
    if (onDeleteConfirm) {
      onDeleteConfirm(entry);
    } else {
      // Fallback to direct delete if no confirmation handler provided
      onDelete(entry.id);
    }
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
      <div data-testid="entry-list" className="card-glass card-glass-hover rounded-3xl mb-8 transition-all duration-300 shadow-2xl">
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
    <div data-testid="entry-list" className="card-glass card-glass-hover rounded-3xl mb-8 transition-all duration-300 shadow-2xl">
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
            data-testid="entry-item"
            className="p-6 hover:bg-white/5 transition-all duration-200"
          >
            {/* Header Row - Food name and actions */}
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-start space-x-3 flex-1 min-w-0">
                {/* Method Icon */}
                <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center backdrop-blur-sm flex-shrink-0 mt-0.5" title={`Added via ${entry.method}`}>
                  {getMethodIcon(entry.method)}
                </div>

                {/* Food Name */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-start space-x-2 mb-1">
                    <h4 className="font-semibold text-white text-lg leading-tight break-words">
                      {entry.food || 'Unknown food'}
                    </h4>
                    {entry.confidence && entry.confidence < 0.8 && (
                      <span className="text-xs bg-yellow-500/20 border border-yellow-400/30 text-yellow-300 px-2 py-1 rounded-lg font-medium backdrop-blur-sm flex-shrink-0 mt-0.5">
                        Low confidence
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center space-x-2 ml-3 flex-shrink-0">
                {onEdit && (
                  <button
                    data-testid="edit-button"
                    onClick={() => onEdit(entry)}
                    className="w-9 h-9 rounded-full text-white/60 hover:text-blue-400 transition-colors hover:bg-white/10 backdrop-blur-sm flex items-center justify-center"
                    title="Edit entry"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                )}

                <button
                  data-testid="delete-button"
                  onClick={() => handleDeleteClick(entry)}
                  className="w-9 h-9 rounded-full text-white/60 hover:text-red-400 transition-colors hover:bg-white/10 backdrop-blur-sm flex items-center justify-center"
                  title="Delete entry"
                >
                  <DeleteIconComponent size="sm" className="w-4 h-4 text-white/60 hover:text-red-400" />
                </button>
              </div>
            </div>

            {/* Bottom Row - Quantity, time, and calories */}
            <div className="flex items-center justify-between pl-13">
              <div className="flex items-center space-x-3 text-sm text-white/70 font-medium">
                <span className="bg-white/10 px-3 py-1.5 rounded-xl backdrop-blur-sm">
                  {entry.qty || 0} {entry.unit || 'g'}
                </span>
                <span className="text-white/50">
                  {formatTime(entry.ts)}
                </span>
              </div>

              {/* Calories - Prominent display */}
              <div className="bg-gradient-to-r from-orange-500/20 to-red-500/20 border border-orange-400/30 px-4 py-2 rounded-xl backdrop-blur-sm">
                <div className="text-right">
                  <div className="font-bold text-xl text-white leading-none">
                    {entry.kcal || 0}
                  </div>
                  <div className="text-xs text-orange-300 font-medium">
                    calories
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>


    </div>
  );
}
