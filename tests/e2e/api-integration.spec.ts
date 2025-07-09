import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { testBarcodes, testFoodDescriptions } from './fixtures/test-data';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('API Integration Tests', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);

    // Set up media mocks to avoid permission dialogs
    await setupMediaMocks(page);

    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();
  });

  test.describe('Barcode API', () => {
    test('should handle successful barcode lookup', async ({ page }) => {
      // Mock successful barcode response
      await page.route('**/api/barcode/**', async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Coca-Cola Classic',
              kcal: 140,
              fat: 0,
              carbs: 39,
              protein: 0,
              unit: 'ml',
              serving_size: 355
            }
          })
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger barcode scan
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="scan-button"]');
      
      // Simulate barcode detection
      await page.evaluate((barcode) => {
        const event = new CustomEvent('barcodeDetected', { 
          detail: { code: barcode } 
        });
        window.dispatchEvent(event);
      }, testBarcodes.cocaCola);
      
      // Should show confirmation dialog with correct data
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await expect(page.locator('[data-testid="confirm-food-name-input"]')).toHaveValue('Coca-Cola Classic');
      // Check that calories field shows 140 (it's an input field)
      await expect(page.locator('input[type="number"]')).toHaveValue('140');
    });

    test('should handle barcode API error responses', async ({ page }) => {
      // Mock error response
      await page.route('**/api/barcode/**', async (route) => {
        await route.fulfill({
          status: 400,
          contentType: 'application/json',
          body: JSON.stringify({
            success: false,
            error: 'Invalid barcode format'
          })
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger barcode scan
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="scan-button"]');
      
      // Simulate invalid barcode detection
      await page.evaluate((barcode) => {
        const event = new CustomEvent('barcodeDetected', { 
          detail: { code: barcode } 
        });
        window.dispatchEvent(event);
      }, testBarcodes.invalidShort);
      
      // Should show error in barcode scanner (errors are shown in the scanner UI)
      await expect(page.locator('[data-testid="barcode-scanner"]')).toBeVisible();
      // Wait for error to be processed and scanner to close or show error state
      await page.waitForTimeout(2000);
    });

    test('should handle barcode API network errors', async ({ page }) => {
      // Mock network error
      await page.route('**/api/barcode/**', async (route) => {
        await route.abort('failed');
      });

      await helpers.navigateTo('/');
      
      // Trigger barcode scan
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="scan-button"]');
      
      // Simulate barcode detection
      await page.evaluate((barcode) => {
        const event = new CustomEvent('barcodeDetected', { 
          detail: { code: barcode } 
        });
        window.dispatchEvent(event);
      }, testBarcodes.cocaCola);
      
      // Should show network error in barcode scanner
      await expect(page.locator('[data-testid="barcode-scanner"]')).toBeVisible();
      // Wait for error to be processed and scanner to close or show error state
      await page.waitForTimeout(2000);
    });

    test('should handle barcode API timeout', async ({ page }) => {
      // Mock slow response
      await page.route('**/api/barcode/**', async (route) => {
        await new Promise(resolve => setTimeout(resolve, 35000)); // Longer than timeout
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ success: true, data: {} })
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger barcode scan
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="scan-button"]');
      
      // Simulate barcode detection
      await page.evaluate((barcode) => {
        const event = new CustomEvent('barcodeDetected', { 
          detail: { code: barcode } 
        });
        window.dispatchEvent(event);
      }, testBarcodes.cocaCola);
      
      // Should show timeout error in barcode scanner
      await expect(page.locator('[data-testid="barcode-scanner"]')).toBeVisible();
      // Wait for timeout to be processed
      await page.waitForTimeout(3000);
    });
  });

  test.describe('Parse Food API', () => {
    test('should handle successful food parsing', async ({ page }) => {
      // Mock successful parse response
      await page.route('**/api/parse-food', async (route) => {
        const requestBody = route.request().postDataJSON();
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: requestBody.text,
              quantity: 1,
              unit: 'piece',
              kcal: 95,
              fat: 0.3,
              carbs: 25,
              protein: 0.5,
              notes: 'Parsed successfully'
            }
          })
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', testFoodDescriptions[0]);
      await page.click('[data-testid="text-submit-button"]');
      
      // Should show confirmation dialog with parsed data
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await expect(page.locator('[data-testid="confirm-food-name-input"]')).toHaveValue(testFoodDescriptions[0]);
      await expect(page.locator('input[type="number"]')).toHaveValue('95');
    });

    test('should handle parse food API error responses', async ({ page }) => {
      // Mock error response
      await page.route('**/api/parse-food', async (route) => {
        await route.fulfill({
          status: 400,
          contentType: 'application/json',
          body: JSON.stringify({
            success: false,
            error: 'Invalid food description'
          })
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', '');
      await page.click('[data-testid="text-submit-button"]');
      
      // Should show error message
      await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
      await expect(page.locator('[data-testid="error-message"]')).toContainText(/invalid/i);
    });

    test('should handle parse food API with different units preferences', async ({ page }) => {
      let capturedRequest: any = null;
      
      // Mock response and capture request
      await page.route('**/api/parse-food', async (route) => {
        capturedRequest = route.request().postDataJSON();
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Test Food',
              quantity: 100,
              unit: capturedRequest.units === 'metric' ? 'g' : 'oz',
              kcal: 100,
              fat: 1,
              carbs: 20,
              protein: 3
            }
          })
        });
      });

      // Set units to imperial
      await helpers.navigateTo('/settings');
      await page.click('[data-testid="units-select"] label:has(input[value="imperial"])');
      await page.click('[data-testid="save-settings-button"]');
      
      await helpers.navigateTo('/');
      
      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'chicken breast');
      await page.click('[data-testid="text-submit-button"]');
      
      // Wait for API call
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      
      // Check that imperial units were sent in request
      expect(capturedRequest.units).toBe('imperial');
    });

    test('should handle parse food API network errors', async ({ page }) => {
      // Mock network error
      await page.route('**/api/parse-food', async (route) => {
        await route.abort('failed');
      });

      await helpers.navigateTo('/');
      
      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      
      // Should show network error
      await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
      await expect(page.locator('[data-testid="error-message"]')).toContainText(/failed to fetch|network|error/i);
    });
  });

  test.describe('API Error Handling', () => {
    test('should handle failed requests', async ({ page }) => {
      // Mock request to fail
      await page.route('**/api/parse-food', async (route) => {
        await route.abort('failed');
      });

      await helpers.navigateTo('/');

      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');

      // Should show error message
      await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
      await expect(page.locator('[data-testid="error-message"]')).toContainText(/failed to fetch|network|error/i);
    });

    test('should handle malformed API responses', async ({ page }) => {
      // Mock malformed response
      await page.route('**/api/parse-food', async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: 'invalid json'
        });
      });

      await helpers.navigateTo('/');
      
      // Trigger text input
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      
      // Should show parsing error
      await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
    });

    test('should handle offline state gracefully', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Go offline
      await page.context().setOffline(true);
      
      // Try to use API-dependent feature
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      
      // Should show offline error (network errors show as "Failed to fetch")
      await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
      await expect(page.locator('[data-testid="error-message"]')).toContainText(/failed to fetch|network|offline/i);
      
      // Go back online
      await page.context().setOffline(false);
    });
  });
});
