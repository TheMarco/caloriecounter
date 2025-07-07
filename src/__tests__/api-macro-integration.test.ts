import { parseFood } from '@/utils/api';

// Mock fetch for API calls
global.fetch = jest.fn();

describe('API Macro Integration', () => {
  beforeEach(() => {
    (fetch as jest.Mock).mockClear();
  });

  it('should include macro data in parse food response', async () => {
    const mockResponse = {
      success: true,
      data: {
        food: 'apple',
        quantity: 1,
        unit: 'piece',
        kcal: 95,
        fat: 0.3,
        carbs: 25,
        protein: 0.5,
      },
    };

    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockResponse,
    });

    const result = await parseFood('one apple');

    expect(fetch).toHaveBeenCalledWith('/api/parse-food', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: 'one apple' }),
    });

    expect(result.success).toBe(true);
    expect(result.data).toEqual({
      food: 'apple',
      quantity: 1,
      unit: 'piece',
      kcal: 95,
      fat: 0.3,
      carbs: 25,
      protein: 0.5,
    });
  });

  it('should handle API responses without macro data gracefully', async () => {
    const mockResponse = {
      success: true,
      data: {
        food: 'unknown food',
        quantity: 1,
        unit: 'piece',
        kcal: 100,
        // No macro data
      },
    };

    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockResponse,
    });

    const result = await parseFood('unknown food');

    expect(result.success).toBe(true);
    expect(result.data?.fat).toBeUndefined();
    expect(result.data?.carbs).toBeUndefined();
    expect(result.data?.protein).toBeUndefined();
  });

  it('should handle API errors properly', async () => {
    (fetch as jest.Mock).mockRejectedValueOnce(new Error('Network error'));

    const result = await parseFood('test food');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Network error');
  });
});
