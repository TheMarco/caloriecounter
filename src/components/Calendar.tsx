'use client';

import { useState, useEffect } from 'react';
import { getTotalCaloriesForDate } from '@/utils/idb';

interface CalendarProps {
  onDateSelect: (date: string) => void;
  selectedDate?: string;
}

interface CalendarDay {
  date: string;
  day: number;
  isCurrentMonth: boolean;
  isToday: boolean;
  hasEntries: boolean;
  totalCalories: number;
}

export function Calendar({ onDateSelect, selectedDate }: CalendarProps) {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [calendarDays, setCalendarDays] = useState<CalendarDay[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const formatDateKey = (date: Date): string => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const generateCalendarDays = async (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    
    // First day of the month
    const firstDay = new Date(year, month, 1);
    // Last day of the month
    const lastDay = new Date(year, month + 1, 0);
    
    // Start from the Sunday of the week containing the first day
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - firstDay.getDay());
    
    // End at the Saturday of the week containing the last day
    const endDate = new Date(lastDay);
    endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));
    
    const days: CalendarDay[] = [];
    const today = new Date();
    const todayKey = formatDateKey(today);
    
    // Generate all days for the calendar grid
    const current = new Date(startDate);
    while (current <= endDate) {
      const dateKey = formatDateKey(current);
      const totalCalories = await getTotalCaloriesForDate(dateKey);
      
      days.push({
        date: dateKey,
        day: current.getDate(),
        isCurrentMonth: current.getMonth() === month,
        isToday: dateKey === todayKey,
        hasEntries: totalCalories > 0,
        totalCalories
      });
      
      current.setDate(current.getDate() + 1);
    }
    
    return days;
  };

  useEffect(() => {
    const loadCalendarData = async () => {
      setIsLoading(true);
      try {
        const days = await generateCalendarDays(currentDate);
        setCalendarDays(days);
      } catch (error) {
        console.error('Failed to load calendar data:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadCalendarData();
  }, [currentDate]);

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate(prev => {
      const newDate = new Date(prev);
      if (direction === 'prev') {
        newDate.setMonth(newDate.getMonth() - 1);
      } else {
        newDate.setMonth(newDate.getMonth() + 1);
      }
      return newDate;
    });
  };

  const handleDateClick = (day: CalendarDay) => {
    if (day.isToday) {
      // Navigate to home for today
      window.location.href = '/';
    } else {
      // Only allow past dates (not future dates)
      const today = new Date();
      const clickedDate = new Date(day.date);
      if (clickedDate < today) {
        onDateSelect(day.date);
      }
    }
  };

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  if (isLoading) {
    return (
      <div className="card-glass card-glass-hover rounded-3xl p-6 transition-all duration-300 shadow-2xl">
        <div className="flex items-center space-x-4 mb-6">
          <div className="p-3 bg-purple-500/20 rounded-2xl">
            <svg className="w-6 h-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002 2z" />
            </svg>
          </div>
          <div>
            <h2 className="text-xl font-semibold text-white">Calendar</h2>
            <p className="text-white/60 text-sm">Loading...</p>
          </div>
        </div>
        <div className="h-64 flex items-center justify-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-400"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="card-glass card-glass-hover rounded-3xl p-6 transition-all duration-300 shadow-2xl">
      {/* Header */}
      <div className="flex items-center space-x-4 mb-6">
        <div className="p-3 bg-purple-500/20 rounded-2xl">
          <svg className="w-6 h-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002 2z" />
          </svg>
        </div>
        <div className="flex-1">
          <h2 className="text-xl font-semibold text-white">Calendar</h2>
          <p className="text-white/60 text-sm">Tap any day to view and edit entries</p>
        </div>
      </div>

      {/* Month Navigation */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={() => navigateMonth('prev')}
          className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all duration-200 hover:scale-105"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        
        <h3 className="text-lg font-semibold text-white">
          {monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}
        </h3>
        
        <button
          onClick={() => navigateMonth('next')}
          className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all duration-200 hover:scale-105"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      {/* Day Headers */}
      <div className="grid grid-cols-7 gap-1 mb-2">
        {dayNames.map(day => (
          <div key={day} className="text-center text-xs font-medium text-white/60 py-2">
            {day}
          </div>
        ))}
      </div>

      {/* Calendar Grid */}
      <div className="grid grid-cols-7 gap-1">
        {calendarDays.map((day, index) => {
          const today = new Date();
          const dayDate = new Date(day.date);
          const isFuture = dayDate > today;
          const isClickable = day.isCurrentMonth && !isFuture;

          return (
            <button
              key={index}
              onClick={() => handleDateClick(day)}
              disabled={!isClickable}
              className={`
                relative aspect-square rounded-xl text-sm font-medium transition-all duration-200
                ${isClickable
                  ? 'hover:scale-105 hover:bg-white/20 cursor-pointer'
                  : 'cursor-not-allowed'
                }
                ${day.isCurrentMonth
                  ? isFuture
                    ? 'text-white/40'
                    : 'text-white'
                  : 'text-white/30'
                }
                ${day.isToday
                  ? 'bg-blue-500/30 border border-blue-400/50 text-blue-300 hover:bg-blue-500/40'
                  : isClickable
                    ? 'hover:bg-white/10'
                    : ''
                }
                ${selectedDate === day.date
                  ? 'bg-purple-500/30 border border-purple-400/50 text-purple-300'
                  : ''
                }
              `}
            >
              <span className="relative z-10">{day.day}</span>

              {/* Entry indicator */}
              {day.hasEntries && day.isCurrentMonth && (
                <div className="absolute bottom-1 left-1/2 transform -translate-x-1/2">
                  <div className="w-1.5 h-1.5 bg-green-400 rounded-full"></div>
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Legend */}
      <div className="flex items-center justify-center space-x-4 mt-6 pt-4 border-t border-white/10">
        <div className="flex items-center space-x-2">
          <div className="w-3 h-3 bg-blue-500/30 border border-blue-400/50 rounded"></div>
          <span className="text-xs text-white/60">Today</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-1.5 h-1.5 bg-green-400 rounded-full"></div>
          <span className="text-xs text-white/60">Has entries</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-3 h-3 bg-white/10 rounded opacity-40"></div>
          <span className="text-xs text-white/40">Future (disabled)</span>
        </div>
      </div>
    </div>
  );
}
