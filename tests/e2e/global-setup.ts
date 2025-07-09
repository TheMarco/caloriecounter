import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  console.log('🚀 Starting global setup for Playwright tests...');
  
  // Launch browser for setup
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  try {
    // Set auth cookie to bypass landing page
    console.log('🔐 Setting authentication cookie...');
    await page.context().addCookies([{
      name: 'calorie-auth',
      value: 'authenticated',
      domain: 'localhost',
      path: '/'
    }]);

    // Wait for the dev server to be ready
    console.log('⏳ Waiting for dev server to be ready...');
    await page.goto(config.webServer?.url || 'http://localhost:3000', {
      waitUntil: 'networkidle',
      timeout: 60000
    });
    
    // Clear any existing data to ensure clean test state
    console.log('🧹 Clearing existing data...');
    await page.evaluate(() => {
      // Clear localStorage
      localStorage.clear();

      // Clear IndexedDB
      if ('indexedDB' in window) {
        return new Promise<void>((resolve) => {
          const deleteReq = indexedDB.deleteDatabase('caloriecounter');
          deleteReq.onsuccess = () => resolve();
          deleteReq.onerror = () => resolve(); // Continue even if deletion fails
          deleteReq.onblocked = () => resolve(); // Continue even if blocked
        });
      }
    });

    // Set up global media API mocks
    console.log('🎤 Setting up media API mocks...');
    await page.addInitScript(() => {
      // Mock MediaRecorder
      (window as any).MediaRecorder = class MockMediaRecorder {
        constructor() {}
        start() {}
        stop() {}
        addEventListener() {}
        removeEventListener() {}
        dispatchEvent() { return true; }
        state = 'inactive';
        stream = null;
        mimeType = 'audio/webm';
        audioBitsPerSecond = 0;
        videoBitsPerSecond = 0;
        ondataavailable = null;
        onerror = null;
        onpause = null;
        onresume = null;
        onstart = null;
        onstop = null;
        pause() {}
        resume() {}
        requestData() {}
        static isTypeSupported() { return true; }
      };

      // Mock getUserMedia
      if (navigator.mediaDevices) {
        navigator.mediaDevices.getUserMedia = () => Promise.resolve({
          getTracks: () => [],
          getAudioTracks: () => [],
          getVideoTracks: () => [],
          addTrack: () => {},
          removeTrack: () => {},
          clone: () => ({}),
          addEventListener: () => {},
          removeEventListener: () => {},
          dispatchEvent: () => true,
          active: true,
          id: 'mock-stream',
          onaddtrack: null,
          onremovetrack: null,
        } as any);
      }

      // Mock permissions API
      if (navigator.permissions) {
        navigator.permissions.query = () => Promise.resolve({
          state: 'granted',
          addEventListener: () => {},
          removeEventListener: () => {},
          dispatchEvent: () => true,
          onchange: null,
        } as any);
      }
    });
    
    console.log('✅ Global setup completed successfully');
    
  } catch (error) {
    console.error('❌ Global setup failed:', error);
    throw error;
  } finally {
    await browser.close();
  }
}

export default globalSetup;
