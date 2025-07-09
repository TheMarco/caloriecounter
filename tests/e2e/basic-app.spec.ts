import { test, expect } from '@playwright/test';

test.describe('Basic App Tests', () => {
  test('should load the main page', async ({ page }) => {
    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await page.goto('/');

    // Wait for the app to load
    await page.waitForLoadState('networkidle');

    // Check that the page loads without errors
    await expect(page).toHaveTitle(/Calorie Counter/);

    // Wait for loading to complete - look for the header first
    await expect(page.locator('header')).toBeVisible();

    // Then check for main content (might be hidden during loading)
    await expect(page.locator('main')).toBeVisible({ timeout: 15000 });
    await expect(page.locator('body')).toBeVisible();
  });

  test('should have no console errors on load', async ({ page }) => {
    const errors: string[] = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Filter out known acceptable errors
    const significantErrors = errors.filter(error => 
      !error.includes('favicon') && 
      !error.includes('manifest') &&
      !error.includes('service-worker')
    );
    
    expect(significantErrors).toHaveLength(0);
  });

  test('should be responsive', async ({ page }) => {
    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Wait for header to be visible first
    await expect(page.locator('header')).toBeVisible();

    // Test mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await expect(page.locator('main')).toBeVisible({ timeout: 15000 });

    // Test desktop viewport
    await page.setViewportSize({ width: 1200, height: 800 });
    await expect(page.locator('main')).toBeVisible({ timeout: 15000 });
  });

  test('should handle navigation', async ({ page }) => {
    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await page.goto('/');

    // Try to navigate to settings if link exists
    const settingsLink = page.locator('a[href="/settings"]');
    if (await settingsLink.count() > 0) {
      await settingsLink.click();
      await expect(page).toHaveURL('/settings');
    }

    // Try to navigate to history if link exists
    await page.goto('/');
    const historyLink = page.locator('a[href="/history"]');
    if (await historyLink.count() > 0) {
      await historyLink.click();
      await expect(page).toHaveURL('/history');
    }
  });

  test('should have proper meta tags', async ({ page }) => {
    // Set auth cookie to bypass landing page
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    await page.goto('/');

    // Check for PWA meta tags
    const viewport = page.locator('meta[name="viewport"]');
    await expect(viewport).toHaveAttribute('content', /width=device-width/);

    // Check for theme color
    const themeColor = page.locator('meta[name="theme-color"]');
    if (await themeColor.count() > 0) {
      await expect(themeColor).toHaveAttribute('content');
    }
  });
});
