import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('Photo Food Entry', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);

    // Set up media mocks to avoid permission dialogs
    await setupMediaMocks(page);

    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();

    // Navigate to home page
    await helpers.navigateTo('/');
    await helpers.closeAllDialogs();
  });

  test.describe('Photo Capture Interface', () => {
    test('should open photo capture when photo button is clicked', async ({ page }) => {
      // Click photo button
      await page.locator('[data-testid="header-photo-button"]').click();

      // Check that photo capture dialog opens
      await expect(page.locator('[data-testid="photo-capture-dialog"]')).toBeVisible();
      
      // Should show camera interface
      await expect(page.locator('video')).toBeVisible();
      await expect(page.locator('[data-testid="capture-button"]')).toBeVisible();
      await expect(page.locator('[data-testid="photo-cancel-button"]')).toBeVisible();
    });

    test('should close photo capture with cancel button', async ({ page }) => {
      // Open photo capture
      await page.locator('[data-testid="header-photo-button"]').click();
      await expect(page.locator('[data-testid="photo-capture-dialog"]')).toBeVisible();

      // Click cancel button
      await page.click('[data-testid="photo-cancel-button"]');

      // Check dialog is closed
      await expect(page.locator('[data-testid="photo-capture-dialog"]')).not.toBeVisible();
    });

    test('should show camera permission error when denied', async ({ page }) => {
      // Mock camera permission denial
      await page.context().grantPermissions([]);
      
      // Click photo button
      await page.locator('[data-testid="header-photo-button"]').click();

      // Should show permission error
      await expect(page.locator('text=Camera access denied')).toBeVisible();
    });
  });

  test.describe('Photo Processing', () => {
    test('should show processing state after photo capture', async ({ page }) => {
      // Mock successful photo API response
      await page.route('/api/parse-photo', async route => {
        // Simulate processing delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Apple',
              quantity: 1,
              unit: 'piece',
              kcal: 95,
              fat: 0.3,
              carbs: 25,
              protein: 0.5,
              notes: 'Fresh red apple'
            }
          })
        });
      });

      // Open photo capture and simulate taking photo
      await page.locator('[data-testid="header-photo-button"]').click();
      await expect(page.locator('[data-testid="photo-capture-dialog"]')).toBeVisible();

      // Mock photo capture by clicking capture button
      await page.click('[data-testid="capture-button"]');
      
      // Should show processing state
      await expect(page.locator('text=Analyzing photo')).toBeVisible();
      await expect(page.locator('[data-testid="processing-spinner"]')).toBeVisible();
    });

    test('should show confirmation dialog after successful processing', async ({ page }) => {
      // Mock successful photo API response
      await page.route('/api/parse-photo', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Grilled Chicken Breast',
              quantity: 150,
              unit: 'g',
              kcal: 248,
              fat: 5.4,
              carbs: 0,
              protein: 46.2,
              notes: 'Lean protein source'
            }
          })
        });
      });

      // Open photo capture and simulate taking photo
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');
      
      // Wait for processing to complete and confirmation dialog to appear
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      
      // Check confirmation dialog content
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toContainText('Grilled Chicken Breast');
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toContainText('150 g');
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toContainText('248 calories');
      
      // Should show macro information
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toContainText('5.4g fat');
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toContainText('46.2g protein');
    });

    test('should handle photo processing errors gracefully', async ({ page }) => {
      // Mock API error response
      await page.route('/api/parse-photo', async route => {
        await route.fulfill({
          status: 400,
          contentType: 'application/json',
          body: JSON.stringify({
            success: false,
            error: 'Unable to identify food in the image'
          })
        });
      });

      // Open photo capture and simulate taking photo
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');

      // Should show error message
      await expect(page.locator('text=Unable to identify food in the image')).toBeVisible();
      await expect(page.locator('[data-testid="photo-error-message"]')).toBeVisible();
    });
  });

  test.describe('Additional Details', () => {
    test('should show additional details screen before processing', async ({ page }) => {
      // Open photo capture and simulate taking photo
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');

      // Should show additional details screen
      await expect(page.locator('[data-testid="photo-details-screen"]')).toBeVisible();
      await expect(page.locator('[data-testid="plate-size-select"]')).toBeVisible();
      await expect(page.locator('[data-testid="serving-type-select"]')).toBeVisible();
      await expect(page.locator('[data-testid="additional-details-input"]')).toBeVisible();
    });

    test('should allow customizing plate size and serving details', async ({ page }) => {
      // Mock successful API response
      await page.route('/api/parse-photo', async route => {
        const request = await route.request().postDataJSON();
        
        // Verify additional details are sent to API
        expect(request.details).toBeDefined();
        expect(request.details.plateSize).toBe('large');
        expect(request.details.servingType).toBe('full-portion');
        expect(request.details.additionalDetails).toBe('Extra sauce on the side');
        
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Pasta with Marinara Sauce',
              quantity: 300,
              unit: 'g',
              kcal: 450,
              fat: 8,
              carbs: 85,
              protein: 15
            }
          })
        });
      });

      // Open photo capture and take photo
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');

      // Fill in additional details
      await page.selectOption('[data-testid="plate-size-select"]', 'large');
      await page.selectOption('[data-testid="serving-type-select"]', 'full-portion');
      await page.fill('[data-testid="additional-details-input"]', 'Extra sauce on the side');
      
      // Confirm details
      await page.click('[data-testid="confirm-details-button"]');
      
      // Should proceed to processing
      await expect(page.locator('text=Analyzing photo')).toBeVisible();
    });
  });

  test.describe('Photo Entry Confirmation', () => {
    test('should confirm and add photo entry', async ({ page }) => {
      // Mock successful API response
      await page.route('/api/parse-photo', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Mixed Green Salad',
              quantity: 200,
              unit: 'g',
              kcal: 45,
              fat: 2.1,
              carbs: 8.5,
              protein: 3.2
            }
          })
        });
      });

      // Take photo and process
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');
      await page.click('[data-testid="confirm-details-button"]');
      
      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      
      // Confirm the entry
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Check that entry was added to the list
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]').first()).toContainText('Mixed Green Salad');
      
      // Should show photo method icon
      await expect(page.locator('[data-testid="entry-item"] [title*="photo"]')).toBeVisible();
    });

    test('should allow editing photo entry before confirmation', async ({ page }) => {
      // Mock API response
      await page.route('/api/parse-photo', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Banana',
              quantity: 1,
              unit: 'piece',
              kcal: 105,
              fat: 0.4,
              carbs: 27,
              protein: 1.3
            }
          })
        });
      });

      // Take photo and process
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');
      await page.click('[data-testid="confirm-details-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      
      // Edit the quantity
      await page.fill('[data-testid="quantity-input"]', '2');
      
      // Confirm the edited entry
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Check that entry was added with edited quantity
      await expect(page.locator('[data-testid="entry-item"]')).toContainText('2 piece');
    });

    test('should cancel photo entry confirmation', async ({ page }) => {
      // Mock API response
      await page.route('/api/parse-photo', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            data: {
              food: 'Orange',
              quantity: 1,
              unit: 'piece',
              kcal: 62,
              fat: 0.2,
              carbs: 15.4,
              protein: 1.2
            }
          })
        });
      });

      // Take photo and process
      await page.locator('[data-testid="header-photo-button"]').click();
      await page.click('[data-testid="capture-button"]');
      await page.click('[data-testid="confirm-details-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      
      // Cancel the entry
      await page.locator('[data-testid="cancel-button"]').click();
      
      // Check that no entry was added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(0);
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).not.toBeVisible();
    });
  });
});
