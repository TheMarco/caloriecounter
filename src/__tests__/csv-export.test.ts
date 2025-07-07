import { generateCSVData } from '@/utils/csvExport';
import { addEntry, clearAllData } from '@/utils/idb';

// Mock IndexedDB
import 'fake-indexeddb/auto';

describe('CSV Export', () => {
  beforeEach(async () => {
    await clearAllData();
  });

  afterEach(async () => {
    await clearAllData();
  });

  it('should generate CSV with correct headers', async () => {
    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');
    
    expect(lines[0]).toBe('date,calories,carbs,fat,protein');
  });

  it('should generate CSV with entry data', async () => {
    // Add a test entry
    await addEntry({
      food: 'Test Food',
      qty: 100,
      unit: 'g',
      kcal: 200,
      fat: 10.5,
      carbs: 20.3,
      protein: 15.7,
      method: 'text',
    });

    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');
    
    expect(lines.length).toBe(2); // Header + 1 data row
    expect(lines[0]).toBe('date,calories,carbs,fat,protein');
    
    const dataRow = lines[1];
    const today = new Date().toISOString().slice(0, 10);
    expect(dataRow).toBe(`${today},200,20.3,10.5,15.7`);
  });

  it('should filter out days with no data', async () => {
    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');
    
    // Should only have header, no data rows
    expect(lines.length).toBe(1);
    expect(lines[0]).toBe('date,calories,carbs,fat,protein');
  });

  it('should handle multiple entries on same day', async () => {
    // Add multiple entries
    await addEntry({
      food: 'Food 1',
      qty: 100,
      unit: 'g',
      kcal: 100,
      fat: 5,
      carbs: 10,
      protein: 8,
      method: 'text',
    });

    await addEntry({
      food: 'Food 2',
      qty: 50,
      unit: 'g',
      kcal: 150,
      fat: 7.5,
      carbs: 15.2,
      protein: 12.3,
      method: 'text',
    });

    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');
    
    expect(lines.length).toBe(2); // Header + 1 data row (totals for the day)
    
    const dataRow = lines[1];
    const today = new Date().toISOString().slice(0, 10);
    expect(dataRow).toBe(`${today},250,25.2,12.5,20.3`);
  });
});
