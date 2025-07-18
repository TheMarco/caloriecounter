import { getDailyMacroTotals } from './idb';

export async function generateCSVData(days: number = 365): Promise<string> {
  try {
    // Get all daily totals for the specified number of days
    const dailyTotals = await getDailyMacroTotals(days);
    
    // Filter out days with no data (all zeros)
    const dataWithEntries = dailyTotals.filter(day => 
      day.totals.calories > 0 || day.totals.fat > 0 || day.totals.carbs > 0 || day.totals.protein > 0
    );
    
    // Create CSV header
    const header = 'date,calories,carbs,fat,protein';
    
    // Create CSV rows
    const rows = dataWithEntries.map(day => {
      const { date, totals } = day;
      return `${date},${totals.calories},${totals.carbs.toFixed(1)},${totals.fat.toFixed(1)},${totals.protein.toFixed(1)}`;
    });
    
    // Combine header and rows
    return [header, ...rows].join('\n');
  } catch (error) {
    console.error('Error generating CSV data:', error);
    throw new Error('Failed to generate CSV data');
  }
}

export function downloadCSV(csvData: string, filename: string = 'nutrition-data.csv'): void {
  try {
    // Create blob with CSV data
    const blob = new Blob([csvData], { type: 'text/csv;charset=utf-8;' });
    
    // Create download link
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    
    // Add to DOM, click, and remove
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // Clean up URL object
    URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Error downloading CSV:', error);
    throw new Error('Failed to download CSV file');
  }
}

export async function exportNutritionData(): Promise<void> {
  try {
    const csvData = await generateCSVData();
    const today = (() => {
      const date = new Date();
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
    })();
    const filename = `nutrition-data-${today}.csv`;
    downloadCSV(csvData, filename);
  } catch (error) {
    console.error('Error exporting nutrition data:', error);
    throw error;
  }
}
