// Application constants

// Daily calorie targets
export const DEFAULT_CALORIE_TARGET = 2000;
export const MIN_CALORIE_TARGET = 1000;
export const MAX_CALORIE_TARGET = 5000;

// Daily macro targets (in grams)
export const DEFAULT_FAT_TARGET = 65;      // ~30% of 2000 calories
export const DEFAULT_CARBS_TARGET = 250;   // ~50% of 2000 calories
export const DEFAULT_PROTEIN_TARGET = 100; // ~20% of 2000 calories

export const MIN_FAT_TARGET = 20;
export const MAX_FAT_TARGET = 200;
export const MIN_CARBS_TARGET = 50;
export const MAX_CARBS_TARGET = 500;
export const MIN_PROTEIN_TARGET = 30;
export const MAX_PROTEIN_TARGET = 300;

// Date ranges for history view
export const DATE_RANGES = {
  '7d': { label: '7 Days', days: 7 },
  '30d': { label: '30 Days', days: 30 },
  '90d': { label: '90 Days', days: 90 },
} as const;

// Food units
export const FOOD_UNITS = [
  'g',
  'ml',
  'cup',
  'tbsp',
  'tsp',
  'piece',
  'slice',
  'serving',
  'oz',
  'lb',
] as const;

// Input methods
export const INPUT_METHODS = {
  barcode: {
    label: 'Barcode',
    description: 'Scan product barcode',
  },
  voice: {
    label: 'Voice',
    description: 'Speak your food',
  },
  text: {
    label: 'Text',
    description: 'Type food name',
  },
} as const;

// API configuration
export const API_CONFIG = {
  // OpenFoodFacts
  OPENFOODFACTS_BASE_URL: 'https://world.openfoodfacts.org/api/v0',
  
  // USDA FoodData Central
  USDA_BASE_URL: 'https://api.nal.usda.gov/fdc/v1',
  
  // OpenAI
  OPENAI_MODEL: 'gpt-4o',
  OPENAI_MAX_TOKENS: 150,
  
  // Whisper
  WHISPER_MODEL: 'whisper-1',
} as const;

// Local storage keys
export const STORAGE_KEYS = {
  LAST_DAY: 'lastDay',
  USER_PREFERENCES: 'userPreferences',
  CALORIE_TARGET: 'calorieTarget',
  ONBOARDING_COMPLETE: 'onboardingComplete',
} as const;

// IndexedDB configuration
export const IDB_CONFIG = {
  DB_NAME: 'caloriecounter',
  DB_VERSION: 1,
  STORES: {
    ENTRIES: 'entries',
    SYNC_QUEUE: 'syncQueue',
  },
} as const;

// UI constants
export const UI_CONFIG = {
  DEBOUNCE_DELAY: 500, // ms for text input debouncing
  ANIMATION_DURATION: 200, // ms for UI animations
  MAX_RECENT_FOODS: 10, // number of recent foods to show
} as const;

// Validation constants
export const VALIDATION = {
  MIN_FOOD_NAME_LENGTH: 2,
  MAX_FOOD_NAME_LENGTH: 100,
  MIN_QUANTITY: 0.1,
  MAX_QUANTITY: 10000,
  MIN_CALORIES: 0,
  MAX_CALORIES: 10000,
} as const;

// Error messages
export const ERROR_MESSAGES = {
  NETWORK_ERROR: 'Network error. Please check your connection.',
  BARCODE_NOT_FOUND: 'Product not found. Try entering manually.',
  VOICE_NOT_SUPPORTED: 'Voice input not supported in this browser.',
  CAMERA_NOT_SUPPORTED: 'Camera not supported in this browser.',
  PERMISSION_DENIED: 'Permission denied. Please allow access.',
  INVALID_BARCODE: 'Invalid barcode format.',
  PARSING_ERROR: 'Could not understand the food description.',
  SAVE_ERROR: 'Failed to save entry. Please try again.',
  DELETE_ERROR: 'Failed to delete entry. Please try again.',
} as const;

// Success messages
export const SUCCESS_MESSAGES = {
  ENTRY_SAVED: 'Food entry saved successfully!',
  ENTRY_DELETED: 'Entry deleted successfully!',
  ENTRY_UPDATED: 'Entry updated successfully!',
  DATA_SYNCED: 'Data synced to cloud!',
} as const;

// Chart configuration
export const CHART_CONFIG = {
  COLORS: {
    PRIMARY: '#000000',
    SECONDARY: '#666666',
    SUCCESS: '#22c55e',
    WARNING: '#f59e0b',
    ERROR: '#ef4444',
    BACKGROUND: '#f8fafc',
  },
  HEIGHT: 300,
  MARGIN: { top: 20, right: 30, left: 20, bottom: 5 },
} as const;

// PWA configuration
export const PWA_CONFIG = {
  CACHE_NAME: 'caloriecounter-v1',
  OFFLINE_FALLBACK: '/offline',
  SYNC_TAG: 'background-sync',
} as const;

// Feature flags
export const FEATURES = {
  VOICE_INPUT: true,
  BARCODE_SCANNING: true,
  CLOUD_SYNC: true,
  OFFLINE_MODE: true,
  ANALYTICS: false, // Disable for privacy
} as const;
