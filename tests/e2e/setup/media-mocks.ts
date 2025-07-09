import { Page } from '@playwright/test';

/**
 * Set up media API mocks for a page to avoid permission dialogs
 */
export async function setupMediaMocks(page: Page) {
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

    // Mock camera/video APIs
    if (navigator.mediaDevices) {
      navigator.mediaDevices.enumerateDevices = () => Promise.resolve([
        {
          deviceId: 'mock-camera',
          groupId: 'mock-group',
          kind: 'videoinput' as MediaDeviceKind,
          label: 'Mock Camera',
          toJSON: () => ({})
        }
      ]);
    }
  });
}
