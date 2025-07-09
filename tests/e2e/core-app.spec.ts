import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('Core App Functionality', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);

    // Set up media mocks to avoid permission dialogs
    await setupMediaMocks(page);

    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await helpers.mockAPIResponses();
    await helpers.navigateTo('/');
    await helpers.setupMockSettings();
  });

  test('should load the main page successfully', async ({ page }) => {
    // Check that the page loads without errors
    await expect(page).toHaveTitle(/Calorie Counter/);
    
    // Check for main UI elements
    await expect(page.locator('main')).toBeVisible();
    await expect(page.locator('[data-testid="totals-card"]')).toBeVisible();
    await expect(page.locator('[data-testid="add-fab"]')).toBeVisible();
  });

  test('should display the tabbed totals card with correct tabs', async ({ page }) => {
    const totalsCard = page.locator('[data-testid="totals-card"]');
    await expect(totalsCard).toBeVisible();

    // Check all macro tabs are present
    await expect(page.locator('[data-testid="tab-calories"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-fat"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-carbs"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-protein"]')).toBeVisible();

    // Check default active tab is calories
    await expect(page.locator('[data-testid="tab-calories"]')).toHaveClass(/active|selected/);
  });

  test('should switch between macro tabs correctly', async ({ page }) => {
    // Click on fat tab
    await page.click('[data-testid="tab-fat"]');
    await expect(page.locator('[data-testid="tab-fat"]')).toHaveClass(/active|selected/);
    await expect(page.locator('[data-testid="macro-display"]')).toContainText('fat consumed');

    // Click on carbs tab
    await page.click('[data-testid="tab-carbs"]');
    await expect(page.locator('[data-testid="tab-carbs"]')).toHaveClass(/active|selected/);
    await expect(page.locator('[data-testid="macro-display"]')).toContainText('carbs consumed');

    // Click on protein tab
    await page.click('[data-testid="tab-protein"]');
    await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
    await expect(page.locator('[data-testid="macro-display"]')).toContainText('protein consumed');

    // Return to calories tab
    await page.click('[data-testid="tab-calories"]');
    await expect(page.locator('[data-testid="tab-calories"]')).toHaveClass(/active|selected/);
    await expect(page.locator('[data-testid="macro-display"]')).toContainText('calories consumed');
  });

  test('should display the Add FAB with all input options', async ({ page }) => {
    const addFab = page.locator('[data-testid="add-fab"]');
    await expect(addFab).toBeVisible();

    // Click to expand FAB options
    await addFab.click();

    // Check all input method buttons are visible
    await expect(page.locator('[data-testid="scan-button"]')).toBeVisible();
    await expect(page.locator('[data-testid="voice-button"]')).toBeVisible();
    await expect(page.locator('[data-testid="text-button"]')).toBeVisible();
  });

  test('should display empty entry list initially', async ({ page }) => {
    const entryList = page.locator('[data-testid="entry-list"]');
    await expect(entryList).toBeVisible();

    // Should show empty state or no entries
    const entries = page.locator('[data-testid="entry-item"]');
    await expect(entries).toHaveCount(0);
  });

  test('should display entries when data is present', async ({ page }) => {
    // Set up mock data using UI interaction

    // Set up mock data (includes page reload)
    await helpers.setupMockData();

    // Check that entries are displayed
    const entries = page.locator('[data-testid="entry-item"]');
    await expect(entries).toHaveCount(3, { timeout: 15000 });

    // Check entry content (entries are displayed in reverse creation order)
    await expect(entries.first()).toContainText('Brown Rice');
    await expect(entries.nth(1)).toContainText('Chicken Breast');
    await expect(entries.nth(2)).toContainText('Apple');
  });



  test('should navigate to history page', async ({ page }) => {
    // Look for history navigation link/button
    const historyLink = page.locator('[data-testid="history-link"]').or(
      page.locator('a[href="/history"]')
    );
    
    if (await historyLink.count() > 0) {
      await historyLink.click();
      await expect(page).toHaveURL('/history');
      await expect(page.locator('h1')).toContainText(/History|Charts/);
    }
  });

  test('should navigate to settings page', async ({ page }) => {
    // Look for settings navigation link/button
    const settingsLink = page.locator('[data-testid="settings-link"]').or(
      page.locator('a[href="/settings"]')
    );
    
    if (await settingsLink.count() > 0) {
      await settingsLink.click();
      await expect(page).toHaveURL('/settings');
      await expect(page.locator('h1')).toContainText(/Settings/);
    }
  });

  test('should handle app loading states gracefully', async ({ page }) => {
    // Reload page and check loading states
    await page.reload();
    
    // Should not show error states
    await expect(page.locator('[data-testid="error-message"]')).not.toBeVisible();
    
    // Should eventually show main content
    await helpers.waitForAppLoad();
    await expect(page.locator('[data-testid="totals-card"]')).toBeVisible();
  });





  test('should display PWA install banner when appropriate', async ({ page }) => {
    // Check if PWA install banner appears
    const installBanner = page.locator('[data-testid="pwa-install-banner"]');
    
    // Banner might not always be visible depending on browser/conditions
    // Just check it doesn't cause errors if present
    if (await installBanner.count() > 0) {
      await expect(installBanner).toBeVisible();
      
      // Test dismiss functionality if present
      const dismissButton = installBanner.locator('[data-testid="dismiss-banner"]');
      if (await dismissButton.count() > 0) {
        await dismissButton.click();
        await expect(installBanner).not.toBeVisible();
      }
    }
  });
});
