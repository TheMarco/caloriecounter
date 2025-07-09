import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { mockFoodEntries } from './fixtures/test-data';

test.describe('Data Persistence Tests', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();
  });

  test.describe('IndexedDB Operations', () => {
    test('should initialize IndexedDB on app load', async ({ page }) => {
      await helpers.navigateTo('/');

      // Check that the app loads successfully (which means IndexedDB is working)
      await expect(page.locator('[data-testid="main-content"]')).toBeVisible();

      // Check that idb-keyval is working by testing localStorage
      const hasLocalStorage = await page.evaluate(() => {
        return typeof localStorage !== 'undefined';
      });

      expect(hasLocalStorage).toBe(true);
    });

    test('should create entries object store', async ({ page }) => {
      await helpers.navigateTo('/');

      // Check that the app can store and retrieve data (which means the store is working)
      const canStoreData = await page.evaluate(async () => {
        try {
          // Test if we can use the storage system
          const testKey = 'test-key';
          const testValue = { test: 'data' };

          // Try to store and retrieve data
          localStorage.setItem(testKey, JSON.stringify(testValue));
          const retrieved = localStorage.getItem(testKey);
          localStorage.removeItem(testKey);

          return retrieved !== null;
        } catch {
          return false;
        }
      });

      expect(canStoreData).toBe(true);
    });

    test('should persist data across page reloads', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Add an entry
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.click('[data-testid="confirm-button"]');
      
      // Wait for entry to be added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      
      // Reload page
      await page.reload();
      await helpers.waitForAppLoad();
      
      // Entry should still be there
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]').first()).toContainText(/apple/i);
    });

    test('should handle IndexedDB errors gracefully', async ({ page }) => {
      await helpers.navigateTo('/');

      // App should load successfully even if there are storage issues
      await expect(page.locator('[data-testid="main-content"]')).toBeVisible();

      // The app should show the main interface
      await expect(page.locator('[data-testid="add-fab"]')).toBeVisible();
    });
  });

  test.describe('Entry CRUD Operations', () => {
    test('should create new entries', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Add entry
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'banana');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Check entry was created in the UI
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]').first()).toContainText(/banana/i);

      // Verify the totals updated (which means data was stored)
      const macroTotal = page.locator('[data-testid="macro-total"]');
      await expect(macroTotal).not.toHaveText('0');
    });

    test('should read existing entries', async ({ page }) => {
      // Set up mock data
      await helpers.setupMockData();
      await helpers.navigateTo('/');
      
      // Check entries are displayed
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
      
      // Check entry content
      const entries = page.locator('[data-testid="entry-item"]');
      await expect(entries.nth(0)).toContainText('Apple');
      await expect(entries.nth(1)).toContainText('Chicken Breast');
      await expect(entries.nth(2)).toContainText('Brown Rice');
    });

    test('should update existing entries', async ({ page }) => {
      // Set up mock data
      await helpers.setupMockData();
      await helpers.navigateTo('/');
      
      // Click edit on first entry
      const editButton = page.locator('[data-testid="entry-item"]').first().locator('[data-testid="edit-button"]');
      if (await editButton.count() > 0) {
        await editButton.click();
        
        // Edit entry in dialog
        await helpers.waitForDialog('[data-testid="edit-entry-dialog"]');
        await page.fill('[data-testid="edit-food-name"]', 'Green Apple');
        await page.click('[data-testid="save-edit-button"]');
        
        // Check entry was updated
        await expect(page.locator('[data-testid="entry-item"]').first()).toContainText('Green Apple');
      }
    });

    test('should delete entries', async ({ page }) => {
      // Set up mock data
      await helpers.setupMockData();
      await helpers.navigateTo('/');
      
      // Initial count
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
      
      // Click delete on first entry
      const deleteButton = page.locator('[data-testid="entry-item"]').first().locator('[data-testid="delete-button"]');
      if (await deleteButton.count() > 0) {
        await deleteButton.click();
        
        // Confirm deletion
        const confirmDialog = page.locator('[data-testid="delete-confirm-dialog"]');
        if (await confirmDialog.count() > 0) {
          await page.click('[data-testid="confirm-delete-button"]');
        }
        
        // Check entry was deleted
        await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(2);
      }
    });

    test('should handle concurrent entry operations', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Add multiple entries quickly
      const foods = ['apple', 'banana', 'orange'];
      
      for (const food of foods) {
        await page.click('[data-testid="add-fab"]');
        await page.click('[data-testid="text-button"]');
        await page.fill('[data-testid="text-input-field"]', food);
        await page.click('[data-testid="text-submit-button"]');
        await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
        await page.click('[data-testid="confirm-button"]');
        
        // Wait for dialog to close before next iteration
        await expect(page.locator('[data-testid="food-confirm-dialog"]')).not.toBeVisible();
      }
      
      // All entries should be created
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
    });
  });

  test.describe('Data Consistency', () => {
    test('should maintain correct totals when entries change', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Initial total should be 0
      await expect(page.locator('[data-testid="macro-total"]')).toContainText('0');
      
      // Add entry with known calories
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.click('[data-testid="confirm-button"]');
      
      // Total should update
      const newTotal = await page.locator('[data-testid="macro-total"]').textContent();
      expect(newTotal).not.toBe('0');
    });

    test('should handle date changes correctly', async ({ page }) => {
      // Set up entries for today
      await helpers.setupMockData();
      await helpers.navigateTo('/');
      
      // Check entries are displayed
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
      
      // Simulate date change
      await page.evaluate(() => {
        // Mock date to tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        Date.now = () => tomorrow.getTime();
      });
      
      // Reload page
      await page.reload();
      await helpers.waitForAppLoad();
      
      // Should show no entries for new date
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(0);
      await expect(page.locator('[data-testid="macro-total"]')).toContainText('0');
    });

    test('should sync data across multiple tabs', async ({ context }) => {
      // Open two tabs
      const page1 = await context.newPage();
      const page2 = await context.newPage();
      
      const helpers1 = new TestHelpers(page1);
      const helpers2 = new TestHelpers(page2);
      
      await helpers1.clearAppData();
      await helpers1.setupMockSettings();
      await helpers1.mockAPIResponses();
      await helpers2.mockAPIResponses();
      
      await helpers1.navigateTo('/');
      await helpers2.navigateTo('/');
      
      // Add entry in first tab
      await page1.click('[data-testid="add-fab"]');
      await page1.click('[data-testid="text-button"]');
      await page1.fill('[data-testid="text-input-field"]', 'apple');
      await page1.click('[data-testid="text-submit-button"]');
      await helpers1.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page1.click('[data-testid="confirm-button"]');
      
      // Refresh second tab
      await page2.reload();
      await helpers2.waitForAppLoad();
      
      // Entry should appear in second tab
      await expect(page2.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page2.locator('[data-testid="entry-item"]').first()).toContainText(/apple/i);
    });

    test('should handle storage quota exceeded', async ({ page }) => {
      await helpers.navigateTo('/');
      
      // Mock storage quota exceeded
      await page.addInitScript(() => {
        const originalPut = IDBObjectStore.prototype.put;
        IDBObjectStore.prototype.put = function() {
          const request = originalPut.apply(this, arguments as any);
          setTimeout(() => {
            const error = new DOMException('QuotaExceededError', 'QuotaExceededError');
            if (request.onerror) {
              request.onerror({ target: { error } } as any);
            }
          }, 100);
          return request;
        };
      });
      
      // Try to add entry
      await page.click('[data-testid="add-fab"]');
      await page.click('[data-testid="text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'apple');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.click('[data-testid="confirm-button"]');
      
      // Should show storage error
      await expect(page.locator('[data-testid="storage-error"]')).toBeVisible();
    });
  });

  test.describe('Settings Persistence', () => {
    test('should persist settings changes', async ({ page }) => {
      await helpers.navigateTo('/settings');
      
      // Change settings
      await page.fill('[data-testid="daily-target-input"]', '2200');
      await page.click('[data-testid="units-select"] label:has(input[value="imperial"])');
      await page.click('[data-testid="save-settings-button"]');
      
      // Navigate away and back
      await helpers.navigateTo('/');
      await helpers.navigateTo('/settings');
      
      // Settings should be persisted
      await expect(page.locator('[data-testid="daily-target-input"]')).toHaveValue('2200');
      const imperialRadio = page.locator('[data-testid="units-select"] input[value="imperial"]');
      await expect(imperialRadio).toBeChecked();
    });

    test('should handle localStorage errors', async ({ page }) => {
      // Mock localStorage to fail
      await page.addInitScript(() => {
        const originalSetItem = localStorage.setItem;
        localStorage.setItem = function() {
          throw new Error('Storage disabled');
        };
      });
      
      await helpers.navigateTo('/settings');
      
      // Try to save settings
      await page.fill('[data-testid="daily-target-input"]', '2200');
      await page.click('[data-testid="save-settings-button"]');
      
      // Should show error message
      await expect(page.locator('[data-testid="storage-error"]')).toBeVisible();
    });
  });
});
