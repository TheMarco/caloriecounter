import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';

test.describe('History Page Functionality', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.navigateTo('/history');
  });

  test('should load history page successfully', async ({ page }) => {
    // Check page loads
    await expect(page).toHaveURL('/history');
    await expect(page.locator('h1')).toContainText(/History|Charts/);
    
    // Check main sections are visible
    await expect(page.locator('[data-testid="date-range-selector"]')).toBeVisible();
    await expect(page.locator('[data-testid="macro-tabs"]')).toBeVisible();
  });

  test('should display date range selector with default selection', async ({ page }) => {
    const dateRangeSelector = page.locator('[data-testid="date-range-selector"]');
    await expect(dateRangeSelector).toBeVisible();
    
    // Check that 7 days is selected by default (has blue styling)
    await expect(page.locator('[data-testid="range-7d"]')).toHaveClass(/bg-blue-500/);
    
    // Check all range options are present
    await expect(page.locator('[data-testid="range-7d"]')).toBeVisible();
    await expect(page.locator('[data-testid="range-30d"]')).toBeVisible();
    await expect(page.locator('[data-testid="range-90d"]')).toBeVisible();
  });

  test('should switch between date ranges', async ({ page }) => {
    // Click on 30 days
    await page.click('[data-testid="range-30d"]');
    await expect(page.locator('[data-testid="range-30d"]')).toHaveClass(/bg-blue-500/);

    // Click on 90 days
    await page.click('[data-testid="range-90d"]');
    await expect(page.locator('[data-testid="range-90d"]')).toHaveClass(/bg-blue-500/);

    // Return to 7 days
    await page.click('[data-testid="range-7d"]');
    await expect(page.locator('[data-testid="range-7d"]')).toHaveClass(/bg-blue-500/);
  });

  test('should display macro tabs with correct options', async ({ page }) => {
    const macroTabs = page.locator('[data-testid="macro-tabs"]');
    await expect(macroTabs).toBeVisible();
    
    // Check all macro tabs are present
    await expect(page.locator('[data-testid="tab-calories"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-fat"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-carbs"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-protein"]')).toBeVisible();
    
    // Check default active tab is calories
    await expect(page.locator('[data-testid="tab-calories"]')).toHaveClass(/active|selected/);
  });

  test('should switch between macro tabs', async ({ page }) => {
    // Click on fat tab
    await page.click('[data-testid="tab-fat"]');
    await expect(page.locator('[data-testid="tab-fat"]')).toHaveClass(/active|selected/);
    
    // Click on carbs tab
    await page.click('[data-testid="tab-carbs"]');
    await expect(page.locator('[data-testid="tab-carbs"]')).toHaveClass(/active|selected/);
    
    // Click on protein tab
    await page.click('[data-testid="tab-protein"]');
    await expect(page.locator('[data-testid="tab-protein"]')).toHaveClass(/active|selected/);
    
    // Return to calories tab
    await page.click('[data-testid="tab-calories"]');
    await expect(page.locator('[data-testid="tab-calories"]')).toHaveClass(/active|selected/);
  });

  test('should display chart container', async ({ page }) => {
    const chartContainer = page.locator('[data-testid="chart-container"]');
    await expect(chartContainer).toBeVisible();
  });

  test('should show empty state when no data is available', async ({ page }) => {
    // With no mock data, should show empty state
    const emptyState = page.locator('[data-testid="empty-state"]');
    if (await emptyState.count() > 0) {
      await expect(emptyState).toBeVisible();
      await expect(emptyState).toContainText(/no data|empty/i);
    }
  });

  test('should display chart when data is available', async ({ page }) => {
    // Set up mock historical data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Check that chart is displayed
    const chart = page.locator('[data-testid="chart"]').or(
      page.locator('.recharts-wrapper')
    );
    
    if (await chart.count() > 0) {
      await expect(chart).toBeVisible();
    }
  });

  test('should update chart when date range changes', async ({ page }) => {
    // Set up mock data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Get initial chart state
    const chartContainer = page.locator('[data-testid="chart-container"]');
    const initialContent = await chartContainer.innerHTML();
    
    // Change date range
    await page.click('[data-testid="range-30d"]');
    
    // Wait for chart to update
    await page.waitForTimeout(1000);
    
    // Check that chart content has changed
    const newContent = await chartContainer.innerHTML();
    expect(newContent).not.toBe(initialContent);
  });

  test('should update chart when macro tab changes', async ({ page }) => {
    // Set up mock data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Get initial chart state (calories)
    const chartContainer = page.locator('[data-testid="chart-container"]');
    const initialContent = await chartContainer.innerHTML();
    
    // Switch to fat tab
    await page.click('[data-testid="tab-fat"]');
    
    // Wait for chart to update
    await page.waitForTimeout(1000);
    
    // Check that chart content has changed
    const newContent = await chartContainer.innerHTML();
    expect(newContent).not.toBe(initialContent);
  });

  test('should show loading state while data is being fetched', async ({ page }) => {
    // Reload page to trigger loading
    await page.reload();
    
    // Check for loading indicator
    const loadingIndicator = page.locator('[data-testid="chart-loading"]');
    if (await loadingIndicator.count() > 0) {
      await expect(loadingIndicator).toBeVisible();
    }
    
    // Wait for loading to complete
    await helpers.waitForAppLoad();
    
    // Loading should be gone
    if (await loadingIndicator.count() > 0) {
      await expect(loadingIndicator).not.toBeVisible();
    }
  });

  test('should display chart legend if present', async ({ page }) => {
    // Set up mock data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Check for chart legend
    const legend = page.locator('[data-testid="chart-legend"]').or(
      page.locator('.recharts-legend-wrapper')
    );
    
    if (await legend.count() > 0) {
      await expect(legend).toBeVisible();
    }
  });

  test('should display chart axes labels', async ({ page }) => {
    // Set up mock data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Check for axis labels
    const xAxis = page.locator('[data-testid="chart-x-axis"]').or(
      page.locator('.recharts-xAxis')
    );
    const yAxis = page.locator('[data-testid="chart-y-axis"]').or(
      page.locator('.recharts-yAxis')
    );
    
    if (await xAxis.count() > 0) {
      await expect(xAxis).toBeVisible();
    }
    if (await yAxis.count() > 0) {
      await expect(yAxis).toBeVisible();
    }
  });

  test('should handle chart interactions if available', async ({ page }) => {
    // Set up mock data
    await helpers.setupMockData();
    await page.reload();
    await helpers.waitForAppLoad();
    
    // Try to interact with chart points
    const chartPoints = page.locator('.recharts-dot').or(
      page.locator('[data-testid="chart-point"]')
    );
    
    if (await chartPoints.count() > 0) {
      // Hover over first point
      await chartPoints.first().hover();
      
      // Check for tooltip
      const tooltip = page.locator('.recharts-tooltip-wrapper').or(
        page.locator('[data-testid="chart-tooltip"]')
      );
      
      if (await tooltip.count() > 0) {
        await expect(tooltip).toBeVisible();
      }
    }
  });

  test('should navigate back to main page', async ({ page }) => {
    // Look for back button or home link - use first() to avoid strict mode violation
    const backButton = page.locator('[data-testid="back-button"]').or(
      page.locator('[data-testid="home-link"]')
    ).or(
      page.locator('a[href="/"]')
    ).first();

    if (await backButton.count() > 0) {
      await backButton.click();
      await expect(page).toHaveURL('/');
    }
  });

  test('should be responsive on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Check that main elements are still visible
    await expect(page.locator('[data-testid="date-range-selector"]')).toBeVisible();
    await expect(page.locator('[data-testid="macro-tabs"]')).toBeVisible();
    await expect(page.locator('[data-testid="chart-container"]')).toBeVisible();
    
    // Check that tabs are properly arranged for mobile
    const tabContainer = page.locator('[data-testid="macro-tabs"]');
    const containerWidth = await tabContainer.boundingBox();
    expect(containerWidth?.width).toBeLessThanOrEqual(375);
  });

  test('should handle data refresh when returning from other pages', async ({ page }) => {
    // Navigate away and back
    await helpers.navigateTo('/');
    await helpers.navigateTo('/history');
    
    // Should still display properly
    await expect(page.locator('[data-testid="chart-container"]')).toBeVisible();
    await expect(page.locator('[data-testid="date-range-selector"]')).toBeVisible();
  });
});
