'use client';

import { MacroType } from '@/types';

interface MacroTabsProps {
  activeTab: MacroType;
  onTabChange: (tab: MacroType) => void;
}

const MACRO_TABS = [
  { 
    key: 'calories' as MacroType, 
    label: 'Calories', 
    color: 'text-blue-400',
    bgColor: 'bg-blue-500/20',
    borderColor: 'border-blue-400',
    icon: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    )
  },
  { 
    key: 'fat' as MacroType, 
    label: 'Fat', 
    color: 'text-green-400',
    bgColor: 'bg-green-500/20',
    borderColor: 'border-green-400',
    icon: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
      </svg>
    )
  },
  { 
    key: 'carbs' as MacroType, 
    label: 'Carbs', 
    color: 'text-orange-400',
    bgColor: 'bg-orange-500/20',
    borderColor: 'border-orange-400',
    icon: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
      </svg>
    )
  },
  { 
    key: 'protein' as MacroType, 
    label: 'Protein', 
    color: 'text-purple-400',
    bgColor: 'bg-purple-500/20',
    borderColor: 'border-purple-400',
    icon: (
      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
      </svg>
    )
  },
];

export function MacroTabs({ activeTab, onTabChange }: MacroTabsProps) {
  return (
    <div className="flex space-x-1 p-2 bg-black/20 rounded-2xl backdrop-blur-sm border border-white/10 mb-6">
      {MACRO_TABS.map((tab) => {
        const isActive = activeTab === tab.key;
        return (
          <button
            key={tab.key}
            onClick={() => onTabChange(tab.key)}
            className={`
              flex-1 flex items-center justify-center space-x-1 px-2 py-3 rounded-xl font-semibold text-xs sm:text-sm transition-all duration-200
              ${isActive
                ? `${tab.bgColor} ${tab.color} ${tab.borderColor} border-2 shadow-lg`
                : 'text-white/60 hover:text-white/80 hover:bg-white/5'
              }
            `}
          >
            <span className="w-4 h-4 sm:w-5 sm:h-5">{tab.icon}</span>
            <span className="hidden sm:inline">{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}
