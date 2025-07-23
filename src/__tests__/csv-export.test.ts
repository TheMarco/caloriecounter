import { generateCSVData } from '@/utils/csvExport';
import { addEntry, clearAllData, todayKey, setTodayCalorieOffset } from '@/utils/idb';

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

    expect(lines[0]).toBe('date,calories_consumed,calories_burned,net_calories,carbs,fat,protein');
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
    expect(lines[0]).toBe('date,calories_consumed,calories_burned,net_calories,carbs,fat,protein');

    const dataRow = lines[1];
    const today = todayKey(); // Use the same function that addEntry uses
    expect(dataRow).toBe(`${today},200,0,200,20.3,10.5,15.7`);
  });

  it('should filter out days with no data', async () => {
    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');

    // Should only have header, no data rows
    expect(lines.length).toBe(1);
    expect(lines[0]).toBe('date,calories_consumed,calories_burned,net_calories,carbs,fat,protein');
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
    const today = todayKey(); // Use the same function that addEntry uses
    expect(dataRow).toBe(`${today},250,0,250,25.2,12.5,20.3`);
  });

  it('should include workout data and calculate net calories', async () => {
    // Add a test entry
    await addEntry({
      food: 'Test Food',
      qty: 100,
      unit: 'g',
      kcal: 500,
      fat: 10.0,
      carbs: 20.0,
      protein: 15.0,
      method: 'text',
    });

    // Add workout data (calories burned)
    await setTodayCalorieOffset(200);

    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');

    expect(lines.length).toBe(2); // Header + 1 data row
    expect(lines[0]).toBe('date,calories_consumed,calories_burned,net_calories,carbs,fat,protein');

    const dataRow = lines[1];
    const today = todayKey();
    // Net calories should be 500 - 200 = 300
    expect(dataRow).toBe(`${today},500,200,300,20.0,10.0,15.0`);
  });

  it('should include days with only workout data (no food entries)', async () => {
    // Add only workout data, no food entries
    await setTodayCalorieOffset(300);

    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');

    expect(lines.length).toBe(2); // Header + 1 data row
    expect(lines[0]).toBe('date,calories_consumed,calories_burned,net_calories,carbs,fat,protein');

    const dataRow = lines[1];
    const today = todayKey();
    // Net calories should be 0 - 300 = 0 (clamped to minimum 0)
    expect(dataRow).toBe(`${today},0,300,0,0.0,0.0,0.0`);
  });

  it('should handle net calories calculation correctly when burned > consumed', async () => {
    // Add a small food entry
    await addEntry({
      food: 'Light Snack',
      qty: 50,
      unit: 'g',
      kcal: 100,
      fat: 2.0,
      carbs: 5.0,
      protein: 3.0,
      method: 'text',
    });

    // Add more calories burned than consumed
    await setTodayCalorieOffset(250);

    const csvData = await generateCSVData(7);
    const lines = csvData.split('\n');

    expect(lines.length).toBe(2); // Header + 1 data row

    const dataRow = lines[1];
    const today = todayKey();
    // Net calories should be max(0, 100 - 250) = 0
    expect(dataRow).toBe(`${today},100,250,0,5.0,2.0,3.0`);
  });
});
