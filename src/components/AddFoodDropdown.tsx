'use client';

import { useState } from 'react';
import {
  BarcodeIconComponent,
  MicrophoneIconComponent,
  PencilIconComponent,
  CameraIconComponent
} from '@/components/icons';

interface AddFoodDropdownProps {
  onScan: () => void;
  onVoice: () => void;
  onText: () => void;
  onPhoto: () => void;
}

export function AddFoodDropdown({ onScan, onVoice, onText, onPhoto }: AddFoodDropdownProps) {
  const [isOpen, setIsOpen] = useState(false);

  const options = [
    {
      id: 'scan',
      label: 'Scan',
      icon: <BarcodeIconComponent size="sm" className="text-blue-400" />,
      onClick: () => {
        onScan();
        setIsOpen(false);
      }
    },
    {
      id: 'voice',
      label: 'Voice',
      icon: <MicrophoneIconComponent size="sm" className="text-green-400" />,
      onClick: () => {
        onVoice();
        setIsOpen(false);
      }
    },
    {
      id: 'type',
      label: 'Type',
      icon: <PencilIconComponent size="sm" className="text-purple-400" />,
      onClick: () => {
        onText();
        setIsOpen(false);
      }
    },
    {
      id: 'photo',
      label: 'Photo',
      icon: <CameraIconComponent size="sm" className="text-orange-400" />,
      onClick: () => {
        onPhoto();
        setIsOpen(false);
      }
    }
  ];

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-3 w-full px-4 py-3 bg-white/10 hover:bg-white/20 rounded-2xl transition-all duration-200 border border-white/20"
      >
        <div className="p-2 bg-blue-500/20 rounded-xl">
          <svg className="w-4 h-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
          </svg>
        </div>
        <span className="text-white font-medium">Add a food</span>
        <svg 
          className={`w-4 h-4 text-white/60 ml-auto transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`} 
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setIsOpen(false)}
          />
          
          {/* Dropdown */}
          <div className="absolute bottom-full left-0 right-0 mb-2 bg-gray-900/95 backdrop-blur-xl rounded-2xl border border-white/20 shadow-2xl z-50 overflow-hidden">
            {options.map((option) => (
              <button
                key={option.id}
                onClick={option.onClick}
                className="flex items-center space-x-3 w-full px-4 py-3 hover:bg-white/10 transition-all duration-200 first:rounded-t-2xl last:rounded-b-2xl"
              >
                <div className="p-2 bg-white/10 rounded-xl">
                  {option.icon}
                </div>
                <span className="text-white font-medium">{option.label}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
