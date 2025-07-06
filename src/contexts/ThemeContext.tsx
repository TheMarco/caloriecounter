'use client';

import { createContext, useContext, useEffect, useState, useCallback } from 'react';

type Theme = 'light' | 'dark';

interface ThemeContextType {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
  isDark: boolean;
  isLight: boolean;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const THEME_STORAGE_KEY = 'calorie-counter-theme';

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>('light');
  const [mounted, setMounted] = useState(false);

  // Load theme from localStorage on mount
  useEffect(() => {
    try {
      // First check for saved theme preference
      const savedTheme = localStorage.getItem(THEME_STORAGE_KEY) as Theme;
      if (savedTheme && (savedTheme === 'light' || savedTheme === 'dark')) {
        setThemeState(savedTheme);
      } else {
        // Check system preference
        const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        const initialTheme = systemPrefersDark ? 'dark' : 'light';
        setThemeState(initialTheme);
        localStorage.setItem(THEME_STORAGE_KEY, initialTheme);
      }
    } catch (error) {
      console.error('Failed to load theme:', error);
      setThemeState('light');
    } finally {
      setMounted(true);
    }
  }, []);

  // Apply theme to document
  useEffect(() => {
    if (!mounted) return;

    const root = document.documentElement;
    const body = document.body;

    // Remove both classes first to avoid conflicts
    root.classList.remove('dark', 'light');
    body.classList.remove('dark', 'light');

    // Add the current theme class
    root.classList.add(theme);
    body.classList.add(theme);

    // Save to localStorage
    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch (error) {
      console.error('Failed to save theme:', error);
    }

    // Dispatch custom event for other components to listen to
    window.dispatchEvent(new CustomEvent('theme-changed', { detail: { theme } }));
  }, [theme, mounted]);

  const toggleTheme = useCallback(() => {
    setThemeState(prev => prev === 'light' ? 'dark' : 'light');
  }, []);

  const setTheme = useCallback((newTheme: Theme) => {
    if (newTheme !== theme) {
      setThemeState(newTheme);
    }
  }, [theme]);

  const contextValue = {
    theme,
    toggleTheme,
    setTheme,
    isDark: theme === 'dark',
    isLight: theme === 'light'
  };

  // Prevent hydration mismatch by not rendering until mounted
  if (!mounted) {
    return (
      <div className="min-h-screen bg-white">
        <div className="animate-pulse">
          {children}
        </div>
      </div>
    );
  }

  return (
    <ThemeContext.Provider value={contextValue}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}
