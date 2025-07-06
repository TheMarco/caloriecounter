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
          icon: <WarningIconComponent size="lg" className="text-red-500" />,
          confirmButton: 'bg-red-500 hover:bg-red-600 disabled:bg-red-300',
          iconBg: 'bg-red-100 dark:bg-red-900'
        };
      case 'warning':
        return {
          icon: <WarningIconComponent size="lg" className="text-yellow-500" />,
          confirmButton: 'bg-yellow-500 hover:bg-yellow-600 disabled:bg-yellow-300',
          iconBg: 'bg-yellow-100 dark:bg-yellow-900'
        };
      case 'info':
        return {
          icon: <WarningIconComponent size="lg" className="text-blue-500" />,
          confirmButton: 'bg-blue-500 hover:bg-blue-600 disabled:bg-blue-300',
          iconBg: 'bg-blue-100 dark:bg-blue-900'
        };
    }
  };

  const styles = getVariantStyles();

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-xl max-w-md w-full mx-4 border border-gray-200/50 dark:border-gray-800/50">
        {/* Header */}
        <div className="p-6 pb-4">
          <div className="flex items-center space-x-4">
            <div className={`w-14 h-14 rounded-2xl ${styles.iconBg} flex items-center justify-center flex-shrink-0`}>
              {styles.icon}
            </div>
            <div className="flex-1">
              <h3 className="text-xl font-bold text-black dark:text-white">{title}</h3>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 pb-6">
          <p className="text-gray-700 dark:text-gray-200 leading-relaxed font-medium">{message}</p>
        </div>

        {/* Actions */}
        <div className="px-6 py-6 bg-gray-50/50 dark:bg-gray-800/50 rounded-b-2xl flex space-x-3 justify-end">
          <button
            onClick={onCancel}
            disabled={isLoading}
            className="px-6 py-3 text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 font-semibold hover:scale-105 active:scale-95"
          >
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={`px-6 py-3 text-white rounded-xl transition-all duration-200 flex items-center space-x-2 font-semibold hover:scale-105 active:scale-95 disabled:scale-100 ${styles.confirmButton}`}
          >
            {isLoading ? (
              <>
                <div className="w-4 h-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                <span>Processing...</span>
              </>
            ) : (
              <>
                <CheckIconComponent size="sm" className="text-white" />
                <span>{confirmText}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
