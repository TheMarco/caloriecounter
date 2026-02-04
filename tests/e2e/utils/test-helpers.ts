import { Page, expect } from '@playwright/test';
import { mockFoodEntries, mockSettings } from '../fixtures/test-data';

/**
 * Helper functions for Playwright tests
 */

export class TestHelpers {
  constructor(private page: Page) {}

  /**
   * Wait for the app to be fully loaded
   */
  async waitForAppLoad() {
    // Wait for any page content to be visible
    try {
      await this.page.waitForSelector('[data-testid="main-content"]', {
        state: 'visible',
        timeout: 5000
      });
    } catch {
      try {
        // If main-content not found, try settings-content
        await this.page.waitForSelector('[data-testid="settings-content"]', {
          state: 'visible',
          timeout: 5000
        });
      } catch {
        // If neither found, wait for any main element (for history page)
        await this.page.waitForSelector('main', {
          state: 'visible',
          timeout: 5000
        });
      }
    }
    
    // Wait for loading states to complete
    await this.page.waitForFunction(() => {
      const loadingElements = document.querySelectorAll('[data-testid*="loading"]');
      return loadingElements.length === 0 || 
             Array.from(loadingElements).every(el => el.getAttribute('aria-hidden') === 'true');
    }, { timeout: 10000 });
  }

  /**
   * Clear all app data (localStorage and IndexedDB)
   */
  async clearAppData() {
    try {
      await this.page.evaluate(() => {
        try {
          // Clear localStorage
          if (typeof localStorage !== 'undefined') {
            localStorage.clear();
          }

          // Clear IndexedDB
          if ('indexedDB' in window) {
            return new Promise<void>((resolve) => {
              const deleteReq = indexedDB.deleteDatabase('caloriecounter');
              deleteReq.onsuccess = () => resolve();
              deleteReq.onerror = () => resolve();
              deleteReq.onblocked = () => resolve();
            });
          }
        } catch (error) {
          // Ignore security errors - they happen when localStorage is not available
          console.log('Storage clear failed:', error);
        }
      });
    } catch (error) {
      // Ignore security errors - they happen when localStorage is not available
      console.log('Storage clear failed:', error);
    }
  }

  /**
   * Set up mock data by directly adding entries through the UI
   */
  async setupMockData() {
    // First clear any existing data
    await this.clearAppData();

    // Add mock entries by simulating the text input flow
    for (const entry of mockFoodEntries) {
      // Close any open dialogs first
      await this.closeAllDialogs();

      // Click the text input button
      await this.page.locator('[data-testid="text-button"]').click();

      // Wait for the text input dialog
      await this.page.waitForSelector('[data-testid="text-input-dialog"]');

      // Type the food description
      const foodDescription = `${entry.food} ${entry.qty}${entry.unit}`;
      await this.page.fill('[data-testid="text-input-field"]', foodDescription);

      // Submit the text input
      await this.page.click('[data-testid="text-submit-button"]');

      // Wait for the confirmation dialog
      await this.page.waitForSelector('[data-testid="food-confirm-dialog"]');

      // Confirm the entry
      await this.page.locator('[data-testid="confirm-button"]').click({ force: true });

      // Wait for the dialog to close
      await this.page.waitForSelector('[data-testid="food-confirm-dialog"]', { state: 'hidden' });

      // Small delay between entries
      await this.page.waitForTimeout(500);
    }

    // Wait for the app to update
    await this.waitForAppLoad();
  }

  /**
   * Set up mock settings in localStorage
   */
  async setupMockSettings() {
    // Skip localStorage setup for now to avoid security errors
    // The app will use default settings
    return;
  }

  /**
   * Mock API responses
   */
  async mockAPIResponses() {
    // Mock barcode API
    await this.page.route('**/api/barcode/**', async (route) => {
      const url = route.request().url();
      const barcodeMatch = url.match(/\/api\/barcode\/(.+)$/);
      
      if (barcodeMatch) {
        const barcode = barcodeMatch[1];
        
        // Return different responses based on barcode
        if (barcode === '049000028911') {
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
              success: true,
              data: {
                food: 'Coca-Cola Classic',
                kcal: 140,
                fat: 0,
                carbs: 39,
                protein: 0,
                unit: 'ml',
                serving_size: 355
              }
            })
          });
        } else if (barcode.length < 8 || barcode.length > 14) {
          await route.fulfill({
            status: 400,
            contentType: 'application/json',
            body: JSON.stringify({
              success: false,
              error: 'Invalid barcode format'
            })
          });
        } else {
          await route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({
              success: true,
              data: {
                food: 'Test Product',
                kcal: 100,
                fat: 1,
                carbs: 20,
                protein: 3,
                unit: 'g',
                serving_size: 100
              }
            })
          });
        }
      }
    });

    // Mock parse-food API
    await this.page.route('**/api/parse-food', async (route) => {
      const requestBody = route.request().postDataJSON();
      const text = requestBody?.text || '';

      // Parse the text to extract food name and quantity
      let food = text;
      let qty = 1;
      let unit = 'piece';
      let kcal = 100;
      let fat = 1;
      let carbs = 20;
      let protein = 3;

      // Simple parsing for common patterns (case-insensitive)
      const lowerText = text.toLowerCase();
      if (lowerText.includes('apple')) {
        food = 'Apple';
        qty = 1;
        unit = 'piece';
        kcal = 95;
        fat = 0.3;
        carbs = 25;
        protein = 0.5;
      } else if (lowerText.includes('chicken')) {
        food = 'Chicken Breast';
        qty = 150;
        unit = 'g';
        kcal = 248;
        fat = 5.4;
        carbs = 0;
        protein = 46.2;
      } else if (lowerText.includes('rice')) {
        food = 'Brown Rice';
        qty = 100;
        unit = 'g';
        kcal = 111;
        fat = 0.9;
        carbs = 23;
        protein = 2.6;
      }

      const response = {
        success: true,
        data: {
          food: food,
          quantity: qty,  // Fixed: API returns 'quantity', not 'qty'
          unit: unit,
          kcal: kcal,
          fat: fat,
          carbs: carbs,
          protein: protein,
          notes: 'Mocked response'
        }
      };

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(response)
      });
    });

    // Mock barcode lookup API
    await this.page.route('**/api/barcode/**', async (route) => {
      const url = route.request().url();
      const barcode = url.split('/').pop();

      // Simple barcode mocking based on known test barcodes
      let food = 'Unknown Product';
      let kcal = 100;
      let fat = 1;
      let carbs = 20;
      let protein = 3;
      let unit = 'piece';
      let serving_size = 1;

      if (barcode?.includes('888849000123')) {
        // Premier Protein Shake
        food = 'Premier Protein Shake Vanilla';
        kcal = 160;
        fat = 3;
        carbs = 4;
        protein = 30;
        unit = 'bottle';
        serving_size = 1;
      } else if (barcode?.includes('049000028058')) {
        // Coca-Cola
        food = 'Coca-Cola';
        kcal = 140;
        fat = 0;
        carbs = 39;
        protein = 0;
        unit = 'can';
        serving_size = 1;
      } else if (barcode?.includes('123')) {
        // Invalid barcode
        await route.fulfill({
          status: 400,
          contentType: 'application/json',
          body: JSON.stringify({
            success: false,
            error: 'Invalid barcode format'
          })
        });
        return;
      }

      const barcodeResponse = {
        success: true,
        data: {
          food: food,
          kcal: kcal,
          fat: fat,
          carbs: carbs,
          protein: protein,
          unit: unit,
          serving_size: serving_size
        }
      };

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(barcodeResponse)
      });
    });
  }

  /**
   * Authenticate via the login API to get a valid signed cookie
   */
  async setAuthCookie() {
    // First navigate to a page so we can make API calls
    await this.page.goto('/landing');

    // Call the login API to get a signed auth cookie
    const response = await this.page.request.post('/api/auth', {
      data: { password: process.env.AUTH_PASSWORD || 'sub2marco' },
    });

    if (!response.ok()) {
      throw new Error(`Authentication failed: ${response.status()}`);
    }

    // The cookie is set by the response, but we need to extract it for the context
    const cookies = await this.page.context().cookies();
    const authCookie = cookies.find(c => c.name === 'calorie-auth');

    if (!authCookie) {
      // If cookie wasn't set automatically, we need to handle it manually
      const setCookieHeader = response.headers()['set-cookie'];
      if (setCookieHeader) {
        // Parse and set the cookie manually
        const match = setCookieHeader.match(/calorie-auth=([^;]+)/);
        if (match) {
          await this.page.context().addCookies([{
            name: 'calorie-auth',
            value: match[1],
            domain: 'localhost',
            path: '/',
          }]);
        }
      }
    }
  }

  /**
   * Navigate to a specific page
   */
  async navigateTo(path: string) {
    // Set auth cookie first to bypass landing page
    await this.setAuthCookie();
    await this.page.goto(path);
    await this.waitForAppLoad();
  }

  /**
   * Check if element is visible
   */
  async isVisible(selector: string): Promise<boolean> {
    try {
      await this.page.waitForSelector(selector, { state: 'visible', timeout: 5000 });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Wait for and click element
   */
  async clickElement(selector: string) {
    await this.page.waitForSelector(selector, { state: 'visible' });
    await this.page.click(selector);
  }

  /**
   * Fill input field
   */
  async fillInput(selector: string, value: string) {
    await this.page.waitForSelector(selector, { state: 'visible' });
    await this.page.fill(selector, value);
  }

  /**
   * Get text content of element
   */
  async getTextContent(selector: string): Promise<string> {
    await this.page.waitForSelector(selector, { state: 'visible' });
    return await this.page.textContent(selector) || '';
  }

  /**
   * Wait for dialog to appear and interact with it
   */
  async waitForDialog(selector: string) {
    await this.page.waitForSelector(selector, { state: 'visible', timeout: 10000 });
  }

  /**
   * Close all open dialogs to prevent interference between tests
   */
  async closeAllDialogs() {
    // Close voice input dialog
    const voiceDialog = this.page.locator('[data-testid="voice-input-dialog"]');
    if (await voiceDialog.count() > 0) {
      await this.page.locator('[data-testid="voice-cancel-button"]').click();
      await this.page.waitForTimeout(300);
    }

    // Close text input dialog
    const textDialog = this.page.locator('[data-testid="text-input-dialog"]');
    if (await textDialog.count() > 0) {
      await this.page.locator('[data-testid="text-close-button"]').click();
      await this.page.waitForTimeout(300);
    }

    // Close barcode scanner
    const barcodeScanner = this.page.locator('[data-testid="barcode-scanner"]');
    if (await barcodeScanner.count() > 0) {
      await this.page.locator('[data-testid="scanner-close-button"]').click();
      await this.page.waitForTimeout(300);
    }

    // Close food confirm dialog
    const confirmDialog = this.page.locator('[data-testid="food-confirm-dialog"]');
    if (await confirmDialog.count() > 0) {
      await this.page.locator('[data-testid="cancel-button"]').click();
      await this.page.waitForTimeout(300);
    }
  }

  /**
   * Add a test entry directly to the database for testing
   */
  async addTestEntry(entry: {
    food: string;
    qty: number;
    unit: string;
    kcal: number;
    fat?: number;
    carbs?: number;
    protein?: number;
    method: 'text' | 'voice' | 'barcode' | 'photo';
  }) {
    // Add entry using the text input flow to ensure it's properly stored
    await this.closeAllDialogs();

    // Click the text input button
    await this.page.locator('[data-testid="text-button"]').click();

    // Fill in the food name
    await this.page.fill('[data-testid="text-input-field"]', entry.food);
    await this.page.click('[data-testid="text-submit-button"]');

    // Wait for confirmation dialog
    await this.waitForDialog('[data-testid="food-confirm-dialog"]');

    // Edit the entry details if needed
    if (entry.qty !== 1) {
      await this.page.fill('[data-testid="quantity-input"]', entry.qty.toString());
    }

    // Confirm the entry
    await this.page.locator('[data-testid="confirm-button"]').click({ force: true });

    // Wait for dialog to close and entry to be added
    await this.page.waitForTimeout(500);
  }

  /**
   * Check console for errors
   */
  async checkConsoleErrors(): Promise<string[]> {
    const errors: string[] = [];
    
    this.page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    return errors;
  }

  /**
   * Take screenshot for debugging
   */
  async takeScreenshot(name: string) {
    await this.page.screenshot({ 
      path: `test-results/screenshots/${name}.png`,
      fullPage: true 
    });
  }
}
