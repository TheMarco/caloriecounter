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
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md flex items-center justify-center p-4 z-50">
      <div className="card-glass rounded-3xl shadow-2xl max-w-md w-full mx-4">
        {/* Header */}
        <div className="p-6 pb-4">
          <div className="flex items-center space-x-4">
            <div className={`w-14 h-14 rounded-2xl ${styles.iconBg} flex items-center justify-center flex-shrink-0 backdrop-blur-sm`}>
              {styles.icon}
            </div>
            <div className="flex-1">
              <h3 className="text-xl font-bold text-white">{title}</h3>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 pb-6">
          <p className="text-white/80 leading-relaxed font-medium">{message}</p>
        </div>

        {/* Actions */}
        <div className="px-6 py-6 border-t border-white/20 flex space-x-3 justify-end">
          <button
            onClick={onCancel}
            disabled={isLoading}
            className="px-6 py-3 text-white/80 bg-white/10 border border-white/20 rounded-2xl hover:bg-white/20 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 font-semibold hover:scale-105 active:scale-95 backdrop-blur-sm"
          >
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={`px-6 py-3 rounded-2xl transition-all duration-200 flex items-center space-x-2 font-semibold hover:scale-105 active:scale-95 disabled:scale-100 backdrop-blur-sm ${styles.confirmButton}`}
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
