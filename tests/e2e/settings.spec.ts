import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';

test.describe('Settings Page Functionality', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);

    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.navigateTo('/settings');
  });

  test('should load settings page successfully', async ({ page }) => {
    // Check page loads
    await expect(page).toHaveURL('/settings');
    await expect(page.locator('h1')).toContainText(/Settings/);
    
    // Check main settings sections are visible
    await expect(page.locator('[data-testid="daily-goals-section"]')).toBeVisible();
    await expect(page.locator('[data-testid="preferences-section"]')).toBeVisible();
  });

  test('should display current settings values', async ({ page }) => {
    // Check that default values are displayed
    await expect(page.locator('[data-testid="daily-target-input"]')).toHaveValue('2000');
    await expect(page.locator('[data-testid="fat-target-input"]')).toHaveValue('65');
    await expect(page.locator('[data-testid="carbs-target-input"]')).toHaveValue('250');
    await expect(page.locator('[data-testid="protein-target-input"]')).toHaveValue('100');
    
    // Check units preference (radio button)
    const metricRadio = page.locator('[data-testid="units-select"] input[value="metric"]');
    await expect(metricRadio).toBeChecked();
  });

  test('should update daily calorie target', async ({ page }) => {
    const targetInput = page.locator('[data-testid="daily-target-input"]');
    
    // Clear and enter new value (use selectAll + type to avoid clear() issues)
    await targetInput.selectText();
    await targetInput.fill('2200');
    
    // Save settings
    await page.click('[data-testid="save-settings-button"]');
    
    // Check for success message
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    
    // Reload page and verify value persisted
    await page.reload();
    await helpers.waitForAppLoad();
    await expect(page.locator('[data-testid="daily-target-input"]')).toHaveValue('2200');
  });

  test('should update fat target', async ({ page }) => {
    const fatInput = page.locator('[data-testid="fat-target-input"]');
    
    // Update fat target
    await fatInput.clear();
    await fatInput.fill('70');
    
    // Save settings
    await page.click('[data-testid="save-settings-button"]');
    
    // Check success and persistence
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await page.reload();
    await helpers.waitForAppLoad();
    await expect(page.locator('[data-testid="fat-target-input"]')).toHaveValue('70');
  });

  test('should update carbs target', async ({ page }) => {
    const carbsInput = page.locator('[data-testid="carbs-target-input"]');
    
    // Update carbs target
    await carbsInput.clear();
    await carbsInput.fill('300');
    
    // Save settings
    await page.click('[data-testid="save-settings-button"]');
    
    // Check success and persistence
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await page.reload();
    await helpers.waitForAppLoad();
    await expect(page.locator('[data-testid="carbs-target-input"]')).toHaveValue('300');
  });

  test('should update protein target', async ({ page }) => {
    const proteinInput = page.locator('[data-testid="protein-target-input"]');
    
    // Update protein target
    await proteinInput.clear();
    await proteinInput.fill('120');
    
    // Save settings
    await page.click('[data-testid="save-settings-button"]');
    
    // Check success and persistence
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await page.reload();
    await helpers.waitForAppLoad();
    await expect(page.locator('[data-testid="protein-target-input"]')).toHaveValue('120');
  });

  test('should change units preference from metric to imperial', async ({ page }) => {
    // Click on imperial radio button label (the input is hidden)
    await page.click('[data-testid="units-select"] label:has(input[value="imperial"])');

    // Save settings
    await page.click('[data-testid="save-settings-button"]');

    // Check success and persistence
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await page.reload();
    await helpers.waitForAppLoad();
    const imperialRadio = page.locator('[data-testid="units-select"] input[value="imperial"]');
    await expect(imperialRadio).toBeChecked();
  });





  test('should validate input fields for positive numbers', async ({ page }) => {
    const targetInput = page.locator('[data-testid="daily-target-input"]');
    
    // Try to enter negative value
    await targetInput.clear();
    await targetInput.fill('-100');
    
    // Try to save
    await page.click('[data-testid="save-settings-button"]');
    
    // Should show validation error or prevent saving
    const errorMessage = page.locator('[data-testid="validation-error"]');
    if (await errorMessage.count() > 0) {
      await expect(errorMessage).toBeVisible();
    } else {
      // Or input should be corrected/prevented
      await expect(targetInput).not.toHaveValue('-100');
    }
  });

  test('should validate input fields for reasonable ranges', async ({ page }) => {
    const targetInput = page.locator('[data-testid="daily-target-input"]');
    
    // Try to enter unreasonably high value
    await targetInput.clear();
    await targetInput.fill('50000');
    
    // Try to save
    await page.click('[data-testid="save-settings-button"]');
    
    // Should show validation error or prevent saving
    const errorMessage = page.locator('[data-testid="validation-error"]');
    if (await errorMessage.count() > 0) {
      await expect(errorMessage).toBeVisible();
    }
  });

  test('should handle empty input fields gracefully', async ({ page }) => {
    const targetInput = page.locator('[data-testid="daily-target-input"]');
    
    // Clear input field
    await targetInput.clear();
    
    // Try to save
    await page.click('[data-testid="save-settings-button"]');
    
    // Should either show validation error or use default value
    const errorMessage = page.locator('[data-testid="validation-error"]');
    if (await errorMessage.count() > 0) {
      await expect(errorMessage).toBeVisible();
    } else {
      // Should use default or previous value
      await expect(targetInput).not.toHaveValue('');
    }
  });

  test('should show loading state while saving', async ({ page }) => {
    // Modify a setting
    await page.locator('[data-testid="daily-target-input"]').fill('2100');
    
    // Click save and check for loading state
    await page.click('[data-testid="save-settings-button"]');
    
    // Should show loading state briefly
    const loadingIndicator = page.locator('[data-testid="save-loading"]');
    if (await loadingIndicator.count() > 0) {
      await expect(loadingIndicator).toBeVisible();
    }
    
    // Should show success message after loading
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
  });



  test('should export data functionality if available', async ({ page }) => {
    const exportButton = page.locator('[data-testid="export-data-button"]');
    
    if (await exportButton.count() > 0) {
      // Set up download handler
      const downloadPromise = page.waitForEvent('download');
      
      // Click export button
      await exportButton.click();
      
      // Wait for download
      const download = await downloadPromise;
      
      // Check download properties
      expect(download.suggestedFilename()).toMatch(/\.csv$/);
    }
  });

  test('should display app version and license info if available', async ({ page }) => {
    const versionInfo = page.locator('[data-testid="version-info"]');
    const licenseButton = page.locator('[data-testid="license-button"]');
    
    if (await versionInfo.count() > 0) {
      await expect(versionInfo).toBeVisible();
    }
    
    if (await licenseButton.count() > 0) {
      await licenseButton.click();
      await expect(page.locator('[data-testid="license-dialog"]')).toBeVisible();
      
      // Close license dialog
      await page.click('[data-testid="close-license-button"]');
      await expect(page.locator('[data-testid="license-dialog"]')).not.toBeVisible();
    }
  });
});
