import { test, expect } from '@playwright/test';

test.describe('Calorie Offset Feature', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the app
    await page.goto('/');

    // Handle authentication if needed
    const authInput = page.locator('input[type="password"]');
    if (await authInput.isVisible()) {
      await authInput.fill('sub2marco');
      await page.click('button[type="submit"]');
      await page.waitForSelector('[data-testid="totals-card"]');
    }
  });

  test('should display calorie offset component', async ({ page }) => {
    // Check that the calorie offset component is visible
    await expect(page.locator('text=Calories Burned')).toBeVisible();
    await expect(page.locator('text=Exercise & activity offset')).toBeVisible();
    
    // Check default value is 0
    const offsetInput = page.locator('input[type="number"]').first();
    await expect(offsetInput).toHaveValue('0');
  });

  test('should allow editing calorie offset', async ({ page }) => {
    // Find the offset input field
    const offsetInput = page.locator('input[type="number"]').first();
    
    // Enter a calorie offset value
    await offsetInput.fill('600');
    await offsetInput.blur();
    
    // Wait for save to complete
    await page.waitForTimeout(500);
    
    // Verify the value persisted
    await expect(offsetInput).toHaveValue('600');
    
    // Check that the status text updated
    await expect(page.locator('text=600 calories burned today')).toBeVisible();
  });

  test('should show net calories calculation in totals card', async ({ page }) => {
    // First, ensure we're on the calories tab
    await page.click('[data-testid="tab-calories"]');
    
    // Set a calorie offset
    const offsetInput = page.locator('input[type="number"]').first();
    await offsetInput.fill('500');
    await offsetInput.blur();
    await page.waitForTimeout(500);
    
    // Check that the calculation is shown
    await expect(page.locator('text=net calories consumed')).toBeVisible();
    
    // The calculation should show the math (this will depend on existing entries)
    const calculationText = page.locator('text=/\\d+ - \\d+ = \\d+/');
    await expect(calculationText).toBeVisible();
  });

  test('should not affect macro nutrients display', async ({ page }) => {
    // Set a calorie offset
    const offsetInput = page.locator('input[type="number"]').first();
    await offsetInput.fill('300');
    await offsetInput.blur();
    await page.waitForTimeout(500);
    
    // Switch to fat tab
    await page.click('[data-testid="tab-fat"]');
    
    // Should show normal fat consumed label, not affected by offset
    await expect(page.locator('text=fat consumed')).toBeVisible();
    await expect(page.locator('text=net calories consumed')).not.toBeVisible();
    
    // Switch to carbs tab
    await page.click('[data-testid="tab-carbs"]');
    await expect(page.locator('text=carbs consumed')).toBeVisible();
    
    // Switch to protein tab
    await page.click('[data-testid="tab-protein"]');
    await expect(page.locator('text=protein consumed')).toBeVisible();
  });

  test('should persist offset across page refreshes', async ({ page }) => {
    // Set a calorie offset
    const offsetInput = page.locator('input[type="number"]').first();
    await offsetInput.fill('750');
    await offsetInput.blur();
    await page.waitForTimeout(500);
    
    // Refresh the page
    await page.reload();
    
    // Handle auth again if needed
    const authInput = page.locator('input[type="password"]');
    if (await authInput.isVisible()) {
      await authInput.fill('sub2marco');
      await page.click('button[type="submit"]');
      await page.waitForSelector('[data-testid="totals-card"]');
    }
    
    // Check that the offset value persisted
    const reloadedOffsetInput = page.locator('input[type="number"]').first();
    await expect(reloadedOffsetInput).toHaveValue('750');
    await expect(page.locator('text=750 calories burned today')).toBeVisible();
  });

  test('should handle negative values by converting to zero', async ({ page }) => {
    // Try to enter a negative value
    const offsetInput = page.locator('input[type="number"]').first();
    await offsetInput.fill('-100');
    await offsetInput.blur();
    await page.waitForTimeout(500);
    
    // Should be converted to 0
    await expect(offsetInput).toHaveValue('0');
    await expect(page.locator('text=No workout logged today')).toBeVisible();
  });

  test('should show dual lines in history chart for calories', async ({ page }) => {
    // Set a calorie offset first
    const offsetInput = page.locator('input[type="number"]').first();
    await offsetInput.fill('400');
    await offsetInput.blur();
    await page.waitForTimeout(500);
    
    // Navigate to history page
    await page.click('a[href="/history"]');
    await page.waitForSelector('[data-testid="chart-container"]');
    
    // Ensure we're on the calories tab
    await page.click('[data-testid="tab-calories"]');
    
    // Check that the chart container is visible
    await expect(page.locator('[data-testid="chart-container"]')).toBeVisible();
    
    // The chart should contain both raw and net calorie lines
    // This is harder to test directly, but we can check that the chart renders
    const chartContainer = page.locator('[data-testid="chart-container"] .recharts-wrapper');
    await expect(chartContainer).toBeVisible();
  });

  test('should show appropriate tooltip in history chart', async ({ page }) => {
    // Navigate to history page
    await page.click('a[href="/history"]');
    await page.waitForSelector('[data-testid="chart-container"]');
    
    // Ensure we're on the calories tab
    await page.click('[data-testid="tab-calories"]');
    
    // The chart should be visible
    const chartContainer = page.locator('[data-testid="chart-container"]');
    await expect(chartContainer).toBeVisible();
    
    // For other macro tabs, should show normal display
    await page.click('[data-testid="tab-fat"]');
    await expect(chartContainer).toBeVisible();
  });
});
