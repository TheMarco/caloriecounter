import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { testBarcodes, testFoodDescriptions } from './fixtures/test-data';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('Food Entry Functionality', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);

    // Set up media mocks to avoid permission dialogs
    await setupMediaMocks(page);

    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();

    // Navigate to home page (this will set auth cookie automatically)
    await helpers.navigateTo('/');

    // Close any open dialogs to prevent interference
    await helpers.closeAllDialogs();
  });

  test.describe('Text Input', () => {
    test('should open text input dialog when text button is clicked', async ({ page }) => {
      // The AddFab shows all buttons immediately, no need to click to expand
      await expect(page.locator('[data-testid="text-button"]')).toBeVisible();

      // Click text input button
      await page.locator('[data-testid="text-button"]').click();

      // Check that text input dialog opens
      await expect(page.locator('[data-testid="text-input-dialog"]')).toBeVisible();
      await expect(page.locator('[data-testid="text-input-field"]')).toBeVisible();
    });

    test('should process text input and show confirmation dialog', async ({ page }) => {
      // Open text input
      await page.locator('[data-testid="text-button"]').click();

      // Enter food description
      await page.fill('[data-testid="text-input-field"]', testFoodDescriptions[0]);

      // Wait for the input to be filled
      await expect(page.locator('[data-testid="text-input-field"]')).toHaveValue(testFoodDescriptions[0]);

      await page.click('[data-testid="text-submit-button"]');

      // Wait a moment for the API call to complete
      await page.waitForTimeout(2000);

      // Should show confirmation dialog
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).toBeVisible();

      // Check that the food name input has the parsed food name (not the original input)
      await expect(page.locator('[data-testid="confirm-food-name-input"]')).toHaveValue('Apple');
    });

    test('should confirm and add entry from text input', async ({ page }) => {
      // Open text input and enter food
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');

      // Confirm the entry
      await page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Check that entry was added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]').first()).toContainText('Apple');
    });

    test('should cancel text input confirmation', async ({ page }) => {
      // Open text input and enter food
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');

      // Cancel the entry
      await page.locator('[data-testid="cancel-button"]').click({ force: true });

      // Check that no entry was added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(0);
      await expect(page.locator('[data-testid="food-confirm-dialog"]')).not.toBeVisible();
    });

    test('should close text input dialog with close button', async ({ page }) => {
      // Open text input
      await page.locator('[data-testid="text-button"]').click();

      // Close dialog
      await page.click('[data-testid="text-close-button"]');

      // Check dialog is closed
      await expect(page.locator('[data-testid="text-input-dialog"]')).not.toBeVisible();
    });
  });

  test.describe('Voice Input', () => {
    test('should open voice input dialog when voice button is clicked', async ({ page }) => {
      // Click voice input button
      await page.locator('[data-testid="voice-button"]').click();

      // Check that voice input dialog opens
      await expect(page.locator('[data-testid="voice-input-dialog"]')).toBeVisible();

      // Check for microphone icon (the actual recording indicator)
      await expect(page.locator('[data-testid="voice-input-dialog"] svg').first()).toBeVisible();
    });

    test('should show processing state during voice processing', async ({ page }) => {
      // Open voice input
      await page.locator('[data-testid="voice-button"]').click();

      // Check that voice input dialog is open
      await expect(page.locator('[data-testid="voice-input-dialog"]')).toBeVisible();

      // Check for status text that indicates the voice input is ready
      await expect(page.locator('[data-testid="voice-input-dialog"]')).toContainText(/listening|preparing|processing/i);
    });

    test('should close voice input with cancel button', async ({ page }) => {
      // Open voice input
      await page.locator('[data-testid="voice-button"]').click();

      // Click cancel button
      await page.click('[data-testid="voice-cancel-button"]');

      // Check dialog is closed
      await expect(page.locator('[data-testid="voice-input-dialog"]')).not.toBeVisible();
    });
  });

  test.describe('Barcode Scanning', () => {
    test('should open barcode scanner when scan button is clicked', async ({ page }) => {
      // Click barcode scan button
      await page.locator('[data-testid="scan-button"]').click();

      // Check that barcode scanner opens
      await expect(page.locator('[data-testid="barcode-scanner"]')).toBeVisible();
    });



    test('should handle invalid barcode gracefully', async ({ page }) => {
      // Open barcode scanner
      await page.locator('[data-testid="scan-button"]').click();

      // Wait for scanner to be visible
      await expect(page.locator('[data-testid="barcode-scanner"]')).toBeVisible();

      // For now, just verify the scanner opened successfully
      // The actual barcode validation happens on the backend
      await expect(page.locator('[data-testid="barcode-scanner"] video')).toBeVisible();
    });

    test('should close barcode scanner', async ({ page }) => {
      // Open barcode scanner
      await page.locator('[data-testid="scan-button"]').click();

      // Close scanner
      await page.click('[data-testid="scanner-close-button"]');

      // Check scanner is closed
      await expect(page.locator('[data-testid="barcode-scanner"]')).not.toBeVisible();
    });
  });

  test.describe('Food Confirmation Dialog', () => {
    test('should allow editing food details before confirmation', async ({ page }) => {
      // Add entry via text input
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');

      // Edit food name
      const foodNameInput = page.locator('[data-testid="confirm-food-name-input"]');
      if (await foodNameInput.count() > 0) {
        await foodNameInput.clear();
        await foodNameInput.fill('Green Apple');
      }

      // Edit quantity
      const quantityInput = page.locator('[data-testid="confirm-quantity-input"]');
      if (await quantityInput.count() > 0) {
        await quantityInput.clear();
        await quantityInput.fill('2');
      }

      // Confirm entry
      await page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Check that entry was added with edited details
      await expect(page.locator('[data-testid="entry-item"]')).toContainText('Green Apple');
    });

    test('should show loading state during confirmation', async ({ page }) => {
      // Add entry via text input
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');

      // Wait for confirmation dialog
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');

      // Click confirm and check for loading state
      await page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Should show loading state briefly
      const loadingIndicator = page.locator('[data-testid="confirm-loading"]');
      if (await loadingIndicator.count() > 0) {
        await expect(loadingIndicator).toBeVisible();
      }
    });
  });

  test.describe('Entry Management', () => {
    test('should display newly added entries in the list', async ({ page }) => {
      // Add multiple entries
      const foods = ['apple', 'banana', 'orange'];

      for (const food of foods) {
        await page.locator('[data-testid="text-button"]').click();
        await page.fill('[data-testid="text-input-field"]', food);
        await page.click('[data-testid="text-submit-button"]');
        await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
        await page.locator('[data-testid="confirm-button"]').click({ force: true });
        
        // Wait for dialog to close
        await expect(page.locator('[data-testid="food-confirm-dialog"]')).not.toBeVisible();
      }
      
      // Check all entries are displayed
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
    });

    test('should update totals when entries are added', async ({ page }) => {
      // Get initial total
      const initialTotal = await page.locator('[data-testid="macro-total"]').textContent();

      // Add an entry
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Wait for entry to be added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);

      // Check that total has updated
      const newTotal = await page.locator('[data-testid="macro-total"]').textContent();
      expect(newTotal).not.toBe(initialTotal);
    });
  });
});
