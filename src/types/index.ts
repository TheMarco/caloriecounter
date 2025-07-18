// Core data types for the calorie counter app

export type Entry = {
  id: string;        // cuid2()
  dt: string;        // 'YYYY-MM-DD' local date
  ts: number;        // Unix ms timestamp
  food: string;
  qty: number;
  unit: string;
  kcal: number;
  fat: number;       // grams of fat
  carbs: number;     // grams of carbohydrates
  protein: number;   // grams of protein
  method: 'barcode' | 'voice' | 'text' | 'photo';
  confidence?: number;
};

export type User = {
  id: string;
  email: string;
  name?: string;
  createdAt: Date;
  updatedAt: Date;
};

// API response types
export type BarcodeResponse = {
  success: boolean;
  data?: {
    food: string;
    kcal: number;
    fat: number;
    carbs: number;
    protein: number;
    unit: string;
    serving_size?: number;
  };
  error?: string;
};

export type ParseFoodResponse = {
  success: boolean;
  data?: {
    food: string;
    quantity: number;
    unit: string;
    kcal?: number;
    fat?: number;
    carbs?: number;
    protein?: number;
    notes?: string;
  };
  error?: string;
};

export type StatsResponse = {
  success: boolean;
  data?: {
    daily: Array<{
      date: string;
      total_kcal: number;
    }>;
    weekly_avg?: number;
    monthly_avg?: number;
  };
  error?: string;
};

// UI component props
export type AddFabProps = {
  onScan: () => void;
  onVoice: () => void;
  onText: () => void;
  onPhoto: () => void;
};

export type EntryListProps = {
  entries: Entry[];
  onDelete: (id: string) => void;
  onEdit?: (entry: Entry) => void;
};

export type TotalCardProps = {
  total: number;
  target?: number;
  date: string;
};

// Macro tracking types
export type MacroType = 'calories' | 'fat' | 'carbs' | 'protein';

export type MacroTotals = {
  calories: number;
  fat: number;
  carbs: number;
  protein: number;
};

export type MacroTargets = {
  calories: number;
  fat: number;
  carbs: number;
  protein: number;
};

export type TabbedTotalCardProps = {
  totals: MacroTotals;
  targets: MacroTargets;
  date: string;
  calorieOffset?: number;
};

// Utility types
export type DateRange = '7d' | '30d' | '90d';

export type MethodType = Entry['method'];

// Constants
export const UNITS = ['g', 'ml', 'cup', 'tbsp', 'tsp', 'piece', 'slice'] as const;
export type Unit = typeof UNITS[number];

export const METHODS = ['barcode', 'voice', 'text', 'photo'] as const;
