'use client';

import { WarningIconComponent } from '@/components/icons';

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
          confirmButton: 'bg-red-500/20 hover:bg-red-500/30 border border-red-400/30 hover:border-red-400/50 text-red-300 hover:text-red-200',
          iconBg: 'bg-red-500/20 border border-red-400/30'
        };
      case 'warning':
        return {
          icon: <WarningIconComponent size="lg" className="text-yellow-400" />,
          confirmButton: 'bg-yellow-500/20 hover:bg-yellow-500/30 border border-yellow-400/30 hover:border-yellow-400/50 text-yellow-300 hover:text-yellow-200',
          iconBg: 'bg-yellow-500/20 border border-yellow-400/30'
        };
      case 'info':
        return {
          icon: <WarningIconComponent size="lg" className="text-blue-400" />,
          confirmButton: 'bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200',
          iconBg: 'bg-blue-500/20 border border-blue-400/30'
        };
    }
  };

  const styles = getVariantStyles();

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0 }}>
      <div className="card-glass rounded-3xl p-6 m-4 max-w-md w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className={`p-3 ${styles.iconBg} rounded-2xl`}>
              {styles.icon}
            </div>
            <h2 className="text-xl font-semibold text-white">{title}</h2>
          </div>
          <button
            onClick={onCancel}
            className="text-white/60 hover:text-white text-xl font-bold p-2 rounded-xl hover:bg-white/10 transition-all"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="space-y-4">
          <p className="text-white/80 leading-relaxed">{message}</p>

          {/* Actions */}
          <div className="flex gap-3 pt-6">
            <button
              onClick={onConfirm}
              disabled={isLoading}
              className={`flex-1 py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 ${styles.confirmButton}`}
            >
              {isLoading ? (
                <div className="flex items-center justify-center space-x-2">
                  <div className="w-4 h-4 animate-spin rounded-full border-2 border-current border-t-transparent"></div>
                  <span>Processing...</span>
                </div>
              ) : (
                confirmText
              )}
            </button>
            <button
              onClick={onCancel}
              disabled={isLoading}
              className="flex-1 bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white py-3 px-4 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {cancelText}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
