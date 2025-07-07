'use client';

import { WarningIconComponent, CheckIconComponent } from '@/components/icons';

interface ConfirmDialogProps {
  isOpen: boolean;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  onConfirm: () => void;
  onCancel: () => void;
  isLoading?: boolean;
  variant?: 'danger' | 'warning' | 'info';
}

export function ConfirmDialog({
  isOpen,
  title,
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  onConfirm,
  onCancel,
  isLoading = false,
  variant = 'warning'
}: ConfirmDialogProps) {
  if (!isOpen) return null;

  const getVariantStyles = () => {
    switch (variant) {
      case 'danger':
        return {
          icon: <WarningIconComponent size="lg" className="text-red-400" />,
          confirmButton: 'bg-red-600/90 hover:bg-red-500 border border-red-500/50 hover:border-red-400 text-white hover:text-white',
          iconBg: 'bg-red-500/30 border border-red-400/50'
        };
      case 'warning':
        return {
          icon: <WarningIconComponent size="lg" className="text-yellow-400" />,
          confirmButton: 'bg-yellow-600/90 hover:bg-yellow-500 border border-yellow-500/50 hover:border-yellow-400 text-white hover:text-white',
          iconBg: 'bg-yellow-500/30 border border-yellow-400/50'
        };
      case 'info':
        return {
          icon: <WarningIconComponent size="lg" className="text-blue-400" />,
          confirmButton: 'bg-blue-600/90 hover:bg-blue-500 border border-blue-500/50 hover:border-blue-400 text-white hover:text-white',
          iconBg: 'bg-blue-500/30 border border-blue-400/50'
        };
    }
  };

  const styles = getVariantStyles();

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center p-4 z-50">
      <div className="bg-gray-900/95 backdrop-blur-xl border border-gray-700/50 rounded-3xl shadow-2xl max-w-md w-full mx-4">
        {/* Header */}
        <div className="p-6 pb-4">
          <div className="flex items-center space-x-4">
            <div className={`w-14 h-14 rounded-2xl ${styles.iconBg} flex items-center justify-center flex-shrink-0`}>
              {styles.icon}
            </div>
            <div className="flex-1">
              <h3 className="text-xl font-bold text-white">{title}</h3>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 pb-6">
          <p className="text-gray-200 leading-relaxed font-medium">{message}</p>
        </div>

        {/* Actions */}
        <div className="px-6 py-6 border-t border-gray-700/50 flex space-x-3 justify-end">
          <button
            onClick={onCancel}
            disabled={isLoading}
            className="px-6 py-3 text-gray-300 bg-gray-800/80 border border-gray-600/50 rounded-2xl hover:bg-gray-700/80 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 font-semibold hover:scale-105 active:scale-95"
          >
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={`px-6 py-3 rounded-2xl transition-all duration-200 flex items-center space-x-2 font-semibold hover:scale-105 active:scale-95 disabled:scale-100 ${styles.confirmButton}`}
          >
            {isLoading ? (
              <>
                <div className="w-4 h-4 animate-spin rounded-full border-2 border-current border-t-transparent"></div>
                <span>Processing...</span>
              </>
            ) : (
              <>
                <CheckIconComponent size="sm" className="text-current" />
                <span>{confirmText}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
