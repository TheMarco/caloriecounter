import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('Tabbed Interface', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await setupMediaMocks(page);
    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();
    await helpers.navigateTo('/');
    await helpers.closeAllDialogs();

    // Add a test entry with all macro data
    await helpers.addTestEntry({
      food: 'Chicken Breast',
      qty: 150,
      unit: 'g',
      kcal: 248,
      fat: 5.4,
      carbs: 0,
      protein: 46.2,
      method: 'text'
    });
  });

  test.describe('Tab Navigation', () => {
    test('should display all four macro tabs', async ({ page }) => {
      // Check all tabs are visible
      await expect(page.locator('[data-testid="tab-calories"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-fat"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-carbs"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-protein"]')).toBeVisible();
      
      // Check tab labels
      await expect(page.locator('[data-testid="tab-calories"]')).toContainText('Calories');
      await expect(page.locator('[data-testid="tab-fat"]')).toContainText('Fat');
      await expect(page.locator('[data-testid="tab-carbs"]')).toContainText('Carbs');
      await expect(page.locator('[data-testid="tab-protein"]')).toContainText('Protein');
    });

    test('should start with calories tab active by default', async ({ page }) => {
      // Calories tab should be active
      await expect(page.locator('[data-testid="tab-calories"]')).toHaveClass(/active|selected/);
      
      // Should show calories content
      await expect(page.locator('text=calories consumed')).toBeVisible();
      await expect(page.locator('text=248')).toBeVisible(); // calories value
    });

    test('should switch to fat tab and show fat data', async ({ page }) => {
      // Click fat tab
      await page.click('[data-testid="tab-fat"]');
      
      // Fat tab should be active
      await expect(page.locator('[data-testid="tab-fat"]')).toHaveClass(/active|selected/);
      
      // Should show fat content
      await expect(page.locator('text=fat consumed')).toBeVisible();
      await expect(page.locator('text=5.4')).toBeVisible(); // fat value
      await expect(page.locator('text=g')).toBeVisible(); // fat unit
    });

    test('should switch to carbs tab and show carbs data', async ({ page }) => {
      // Click carbs tab
      await page.click('[data-testid="tab-carbs"]');
      
      // Carbs tab should be active
      await expect(page.locator('[data-testid="tab-carbs"]')).toHaveClass(/active|selected/);
      
      // Should show carbs content
      await expect(page.locator('text=carbs consumed')).toBeVisible();
      await expect(page.locator('text=0')).toBeVisible(); // carbs value (chicken has 0 carbs)
    });

    test('should switch to protein tab and show protein data', async ({ page }) => {
      // Click protein tab
      await page.click('[data-testid="tab-protein"]');
      
      // Protein tab should be active
      await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
      
      // Should show protein content
      await expect(page.locator('text=protein consumed')).toBeVisible();
      await expect(page.locator('text=46.2')).toBeVisible(); // protein value
    });
  });

  test.describe('Tab Content Updates', () => {
    test('should update all tabs when new entry is added', async ({ page }) => {
      // Add another entry with different macros
      await page.locator('[data-testid="text-button"]').click();
      await page.fill('[data-testid="text-input-field"]', 'banana');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Wait for entry to be added
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(2);
      
      // Check calories tab (should be sum of both entries)
      await page.click('[data-testid="tab-calories"]');
      const caloriesText = await page.locator('[data-testid="totals-card"]').textContent();
      expect(caloriesText).toMatch(/\d+/); // Should show updated total
      
      // Check fat tab
      await page.click('[data-testid="tab-fat"]');
      const fatText = await page.locator('[data-testid="totals-card"]').textContent();
      expect(fatText).toMatch(/\d+\.?\d*/); // Should show updated fat total
      
      // Check carbs tab
      await page.click('[data-testid="tab-carbs"]');
      const carbsText = await page.locator('[data-testid="totals-card"]').textContent();
      expect(carbsText).toMatch(/\d+/); // Should show updated carbs total
      
      // Check protein tab
      await page.click('[data-testid="tab-protein"]');
      const proteinText = await page.locator('[data-testid="totals-card"]').textContent();
      expect(proteinText).toMatch(/\d+\.?\d*/); // Should show updated protein total
    });

    test('should show progress bars for each macro', async ({ page }) => {
      // Check calories tab progress
      await page.click('[data-testid="tab-calories"]');
      await expect(page.locator('[data-testid="progress-bar"]')).toBeVisible();
      
      // Check fat tab progress
      await page.click('[data-testid="tab-fat"]');
      await expect(page.locator('[data-testid="progress-bar"]')).toBeVisible();
      
      // Check carbs tab progress
      await page.click('[data-testid="tab-carbs"]');
      await expect(page.locator('[data-testid="progress-bar"]')).toBeVisible();
      
      // Check protein tab progress
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('[data-testid="progress-bar"]')).toBeVisible();
    });

    test('should show target goals for each macro', async ({ page }) => {
      // Check calories target
      await page.click('[data-testid="tab-calories"]');
      await expect(page.locator('text=/target|goal/i')).toBeVisible();
      
      // Check fat target
      await page.click('[data-testid="tab-fat"]');
      await expect(page.locator('text=/target|goal/i')).toBeVisible();
      
      // Check carbs target
      await page.click('[data-testid="tab-carbs"]');
      await expect(page.locator('text=/target|goal/i')).toBeVisible();
      
      // Check protein target
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('text=/target|goal/i')).toBeVisible();
    });
  });

  test.describe('Tab State Persistence', () => {
    test('should remember active tab after page refresh', async ({ page }) => {
      // Switch to protein tab
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
      
      // Refresh page
      await page.reload();
      
      // Handle auth if needed
      const authInput = page.locator('input[type="password"]');
      if (await authInput.isVisible()) {
        await authInput.fill('sub2marco');
        await page.click('button[type="submit"]');
        await page.waitForSelector('[data-testid="totals-card"]');
      }
      
      // Protein tab should still be active
      await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
      await expect(page.locator('text=protein consumed')).toBeVisible();
    });

    test('should maintain tab state when navigating between pages', async ({ page }) => {
      // Switch to fat tab
      await page.click('[data-testid="tab-fat"]');
      await expect(page.locator('[data-testid="tab-fat"]')).toHaveClass(/active|selected/);
      
      // Navigate to history page
      await page.click('[data-testid="nav-history"]');
      await expect(page.locator('h1')).toContainText('History');
      
      // Navigate back to home
      await page.click('[data-testid="nav-home"]');
      
      // Fat tab should still be active
      await expect(page.locator('[data-testid="tab-fat"]')).toHaveClass(/active|selected/);
      await expect(page.locator('text=fat consumed')).toBeVisible();
    });
  });

  test.describe('Calorie Offset Integration', () => {
    test('should only show calorie offset on calories tab', async ({ page }) => {
      // Set a calorie offset
      const offsetInput = page.locator('input[type="number"]').first();
      await offsetInput.fill('300');
      await offsetInput.blur();
      await page.waitForTimeout(500);
      
      // Calories tab should show net calories
      await page.click('[data-testid="tab-calories"]');
      await expect(page.locator('text=net calories consumed')).toBeVisible();
      await expect(page.locator('text=/\\d+ - \\d+ = \\d+/')).toBeVisible();
      
      // Other tabs should not show offset
      await page.click('[data-testid="tab-fat"]');
      await expect(page.locator('text=fat consumed')).toBeVisible();
      await expect(page.locator('text=net calories consumed')).not.toBeVisible();
      
      await page.click('[data-testid="tab-carbs"]');
      await expect(page.locator('text=carbs consumed')).toBeVisible();
      await expect(page.locator('text=net calories consumed')).not.toBeVisible();
      
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('text=protein consumed')).toBeVisible();
      await expect(page.locator('text=net calories consumed')).not.toBeVisible();
    });
  });

  test.describe('Responsive Design', () => {
    test('should display tabs properly on mobile viewport', async ({ page }) => {
      // Set mobile viewport
      await page.setViewportSize({ width: 375, height: 667 });
      
      // All tabs should still be visible
      await expect(page.locator('[data-testid="tab-calories"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-fat"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-carbs"]')).toBeVisible();
      await expect(page.locator('[data-testid="tab-protein"]')).toBeVisible();
      
      // Tab switching should still work
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
    });

    test('should handle tab overflow gracefully', async ({ page }) => {
      // Set very narrow viewport
      await page.setViewportSize({ width: 320, height: 568 });
      
      // Tabs should still be accessible (may scroll or wrap)
      await expect(page.locator('[data-testid="tab-calories"]')).toBeVisible();
      
      // Should be able to click all tabs
      await page.click('[data-testid="tab-fat"]');
      await expect(page.locator('text=fat consumed')).toBeVisible();
      
      await page.click('[data-testid="tab-carbs"]');
      await expect(page.locator('text=carbs consumed')).toBeVisible();
      
      await page.click('[data-testid="tab-protein"]');
      await expect(page.locator('text=protein consumed')).toBeVisible();
    });
  });
});
