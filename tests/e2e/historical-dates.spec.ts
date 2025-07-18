import { test, expect } from '@playwright/test';
import { TestHelpers } from './utils/test-helpers';
import { setupMediaMocks } from './setup/media-mocks';

test.describe('Historical Date Functionality', () => {
  let helpers: TestHelpers;

  test.beforeEach(async ({ page }) => {
    helpers = new TestHelpers(page);
    await setupMediaMocks(page);
    await helpers.clearAppData();
    await helpers.setupMockSettings();
    await helpers.mockAPIResponses();
    await helpers.navigateTo('/');
    await helpers.closeAllDialogs();
  });

  test.describe('Calendar Navigation', () => {
    test('should navigate to history page and show calendar', async ({ page }) => {
      // Navigate to history page
      await page.click('[data-testid="nav-history"]');
      
      // Should show history page with calendar
      await expect(page.locator('h1')).toContainText('History');
      await expect(page.locator('[data-testid="calendar"]')).toBeVisible();
      
      // Should show current month and year
      const currentDate = new Date();
      const monthYear = currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      await expect(page.locator('[data-testid="calendar-header"]')).toContainText(monthYear);
    });

    test('should show clickable dates in calendar', async ({ page }) => {
      await page.click('[data-testid="nav-history"]');
      
      // Should show calendar days
      await expect(page.locator('[data-testid="calendar-day"]')).toHaveCount.greaterThan(20);
      
      // Past dates should be clickable
      const pastDates = page.locator('[data-testid="calendar-day"]:not([data-disabled="true"])');
      await expect(pastDates.first()).toBeVisible();
    });

    test('should disable future dates', async ({ page }) => {
      await page.click('[data-testid="nav-history"]');
      
      // Future dates should be disabled
      const futureDates = page.locator('[data-testid="calendar-day"][data-disabled="true"]');
      const futureCount = await futureDates.count();
      expect(futureCount).toBeGreaterThan(0);
    });

    test('should highlight today\'s date', async ({ page }) => {
      await page.click('[data-testid="nav-history"]');
      
      // Today should be highlighted
      const today = new Date().getDate();
      const todayElement = page.locator(`[data-testid="calendar-day"][data-today="true"]`);
      await expect(todayElement).toBeVisible();
      await expect(todayElement).toContainText(today.toString());
    });
  });

  test.describe('Historical Date Selection', () => {
    test('should navigate to historical date when clicked', async ({ page }) => {
      await page.click('[data-testid="nav-history"]');
      
      // Click on a past date (e.g., 15th of current month)
      const targetDate = page.locator('[data-testid="calendar-day"]:not([data-disabled="true"])').first();
      await targetDate.click();
      
      // Should navigate to historical view
      await expect(page.url()).toMatch(/\?date=\d{4}-\d{2}-\d{2}/);
      
      // Should show historical date in header
      await expect(page.locator('h1')).not.toContainText('Today');
      await expect(page.locator('h1')).toContainText(/\w+day, \w+ \d+/); // e.g., "Monday, July 15"
    });

    test('should show correct date in historical view header', async ({ page }) => {
      // Navigate to a specific historical date
      const testDate = '2025-07-15'; // July 15, 2025 (Tuesday)
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Should show correct formatted date
      await expect(page.locator('h1')).toContainText('Tuesday, July 15, 2025');
      
      // Should show "Edit entries for this day" subtitle
      await expect(page.locator('text=Edit entries for this day')).toBeVisible();
    });

    test('should show correct date in entry list title', async ({ page }) => {
      // Navigate to a specific historical date
      const testDate = '2025-07-14'; // July 14, 2025 (Monday)
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Entry list should show correct date (this tests the timezone fix)
      await expect(page.locator('[data-testid="entry-list"] h3')).toContainText('Monday, July 14, 2025');
      
      // Should NOT show the previous day due to timezone issues
      await expect(page.locator('[data-testid="entry-list"] h3')).not.toContainText('Sunday, July 13');
    });

    test('should show "food logged this day" subtitle for historical dates', async ({ page }) => {
      const testDate = '2025-07-16';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Should show historical subtitle
      await expect(page.locator('text=food logged this day')).toBeVisible();
      
      // Should NOT show today's subtitle
      await expect(page.locator('text=Your daily meal log')).not.toBeVisible();
    });
  });

  test.describe('Historical Date Entry Management', () => {
    test('should allow adding entries to historical dates', async ({ page }) => {
      const testDate = '2025-07-15';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Should show add food dropdown for historical dates
      await expect(page.locator('[data-testid="add-food-dropdown"]')).toBeVisible();
      
      // Add an entry using text input
      await page.click('[data-testid="dropdown-text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'historical apple');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Entry should be added to historical date
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]')).toContainText('Apple');
    });

    test('should store entries with correct historical date', async ({ page }) => {
      const testDate = '2025-07-14';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Add entry to historical date
      await page.click('[data-testid="dropdown-text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'historical banana');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Navigate to today
      await helpers.navigateTo('/');
      
      // Entry should NOT appear on today's list
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(0);
      
      // Navigate back to historical date
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Entry should still be there
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(1);
      await expect(page.locator('[data-testid="entry-item"]')).toContainText('Banana');
    });

    test('should allow editing historical entries', async ({ page }) => {
      const testDate = '2025-07-13';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Add an entry first
      await page.click('[data-testid="dropdown-text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'orange');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Edit the entry
      await page.click('[data-testid="edit-button"]');
      await helpers.waitForDialog('[data-testid="edit-food-dialog"]');
      
      // Change quantity
      await page.fill('[data-testid="edit-quantity-input"]', '2');
      await page.click('[data-testid="save-edit-button"]');
      
      // Entry should be updated
      await expect(page.locator('[data-testid="entry-item"]')).toContainText('2 piece');
    });

    test('should allow deleting historical entries', async ({ page }) => {
      const testDate = '2025-07-12';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Add an entry first
      await page.click('[data-testid="dropdown-text-button"]');
      await page.fill('[data-testid="text-input-field"]', 'grape');
      await page.click('[data-testid="text-submit-button"]');
      await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
      await page.locator('[data-testid="confirm-button"]').click({ force: true });
      
      // Delete the entry
      await page.click('[data-testid="delete-button"]');
      await helpers.waitForDialog('[data-testid="delete-confirm-dialog"]');
      await page.click('[data-testid="confirm-delete-button"]');
      
      // Entry should be removed
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(0);
    });
  });

  test.describe('Historical Date Totals', () => {
    test('should show correct totals for historical dates', async ({ page }) => {
      const testDate = '2025-07-11';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Add multiple entries
      const foods = ['apple', 'banana', 'orange'];
      for (const food of foods) {
        await page.click('[data-testid="dropdown-text-button"]');
        await page.fill('[data-testid="text-input-field"]', food);
        await page.click('[data-testid="text-submit-button"]');
        await helpers.waitForDialog('[data-testid="food-confirm-dialog"]');
        await page.locator('[data-testid="confirm-button"]').click({ force: true });
        await expect(page.locator('[data-testid="food-confirm-dialog"]')).not.toBeVisible();
      }
      
      // Should show totals for all entries
      await expect(page.locator('[data-testid="entry-item"]')).toHaveCount(3);
      
      // Totals card should show combined values
      const totalsCard = page.locator('[data-testid="totals-card"]');
      await expect(totalsCard).toContainText(/\d+/); // Should show some calorie total
    });

    test('should show historical date in totals card', async ({ page }) => {
      const testDate = '2025-07-10';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Totals card should show the historical date
      const totalsCard = page.locator('[data-testid="totals-card"]');
      await expect(totalsCard).toContainText('Wednesday, July 10'); // Formatted date
      
      // Should NOT show "Today"
      await expect(totalsCard).not.toContainText('Today');
    });
  });

  test.describe('Navigation Between Dates', () => {
    test('should navigate back to history from historical date', async ({ page }) => {
      const testDate = '2025-07-09';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Should show back button
      await expect(page.locator('[data-testid="back-to-history-button"]')).toBeVisible();
      
      // Click back button
      await page.click('[data-testid="back-to-history-button"]');
      
      // Should return to history page
      await expect(page.url()).toContain('/history');
      await expect(page.locator('h1')).toContainText('History');
    });

    test('should redirect today\'s date to home page', async ({ page }) => {
      await page.click('[data-testid="nav-history"]');
      
      // Click on today's date
      const todayElement = page.locator(`[data-testid="calendar-day"][data-today="true"]`);
      await todayElement.click();
      
      // Should redirect to home page (not historical view)
      await expect(page.url()).not.toContain('?date=');
      await expect(page.locator('h1')).toContainText('Today');
    });

    test('should maintain historical date in URL', async ({ page }) => {
      const testDate = '2025-07-08';
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // URL should contain the date parameter
      await expect(page.url()).toContain(`?date=${testDate}`);
      
      // Refresh page
      await page.reload();
      
      // Should still be on historical date
      await expect(page.url()).toContain(`?date=${testDate}`);
      await expect(page.locator('h1')).toContainText('Monday, July 8, 2025');
    });
  });

  test.describe('Timezone Handling', () => {
    test('should handle date boundaries correctly across timezones', async ({ page }) => {
      // Test dates around midnight to ensure timezone handling is correct
      const testDates = [
        { date: '2025-07-01', expected: 'Tuesday, July 1, 2025' },
        { date: '2025-07-15', expected: 'Tuesday, July 15, 2025' },
        { date: '2025-07-31', expected: 'Thursday, July 31, 2025' }
      ];
      
      for (const { date, expected } of testDates) {
        await helpers.navigateTo(`/?date=${date}`);
        
        // Should show correct date (not offset by timezone)
        await expect(page.locator('h1')).toContainText(expected);
        await expect(page.locator('[data-testid="entry-list"] h3')).toContainText(expected);
        
        // Should NOT show the previous day
        const previousDay = new Date(date);
        previousDay.setDate(previousDay.getDate() - 1);
        const previousDayFormatted = previousDay.toLocaleDateString('en-US', {
          weekday: 'long',
          month: 'long',
          day: 'numeric',
          year: 'numeric'
        });
        await expect(page.locator('h1')).not.toContainText(previousDayFormatted);
      }
    });

    test('should handle month boundaries correctly', async ({ page }) => {
      // Test first and last days of month
      const testDate = '2025-08-01'; // First day of August
      await helpers.navigateTo(`/?date=${testDate}`);
      
      // Should show August 1st, not July 31st
      await expect(page.locator('h1')).toContainText('Friday, August 1, 2025');
      await expect(page.locator('h1')).not.toContainText('July 31');
    });
  });
});
