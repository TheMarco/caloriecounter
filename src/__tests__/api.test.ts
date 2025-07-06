import { parseFood, lookupBarcode, isAPIError, getErrorMessage } from '@/utils/api';

// Mock fetch globally
global.fetch = jest.fn();

describe('API utilities', () => {
  beforeEach(() => {
    (fetch as jest.Mock).mockClear();
  });

  describe('parseFood', () => {
    it('should parse food successfully', async () => {
      const mockResponse = {
        success: true,
        data: {
          food: 'apple',
          quantity: 1,
          unit: 'piece',
          kcal: 95,
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

      expect(result).toEqual(mockResponse);
    });

    it('should handle API errors', async () => {
      (fetch as jest.Mock).mockRejectedValueOnce(new Error('Network error'));

      const result = await parseFood('test food');

      expect(result).toEqual({
        success: false,
        error: 'Network error',
      });
    });
  });

  describe('lookupBarcode', () => {
    it('should lookup barcode successfully', async () => {
      const mockResponse = {
        success: true,
        data: {
          food: 'Nutella',
          kcal: 539,
          unit: 'g',
          serving_size: 100,
        },
      };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await lookupBarcode('3017620422003');

      expect(fetch).toHaveBeenCalledWith('/api/barcode/3017620422003');
      expect(result).toEqual(mockResponse);
    });

    it('should handle barcode lookup errors', async () => {
      (fetch as jest.Mock).mockRejectedValueOnce(new Error('Product not found'));

      const result = await lookupBarcode('invalid-barcode');

      expect(result).toEqual({
        success: false,
        error: 'Product not found',
      });
    });
  });

  describe('isAPIError', () => {
    it('should return true for objects with message property', () => {
      const error = { message: 'Test error' };
      expect(isAPIError(error)).toBe(true);
    });

    it('should return false for objects without message property', () => {
      const notError = { code: 404 };
      expect(isAPIError(notError)).toBe(false);
    });

    it('should return false for null or undefined', () => {
      expect(isAPIError(null)).toBe(false);
      expect(isAPIError(undefined)).toBe(false);
    });

    it('should return false for primitive values', () => {
      expect(isAPIError('string')).toBe(false);
      expect(isAPIError(123)).toBe(false);
      expect(isAPIError(true)).toBe(false);
    });
  });

  describe('getErrorMessage', () => {
    it('should return message from API error objects', () => {
      const error = { message: 'Custom error message' };
      expect(getErrorMessage(error)).toBe('Custom error message');
    });

    it('should return default message for non-API errors', () => {
      expect(getErrorMessage('string error')).toBe('An unexpected error occurred');
      expect(getErrorMessage(null)).toBe('An unexpected error occurred');
      expect(getErrorMessage(undefined)).toBe('An unexpected error occurred');
    });

    it('should return default message for objects without message', () => {
      const error = { code: 500 };
      expect(getErrorMessage(error)).toBe('An unexpected error occurred');
    });
  });
});
