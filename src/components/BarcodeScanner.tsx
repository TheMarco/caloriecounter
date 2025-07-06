'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { BrowserMultiFormatReader, NotFoundException, DecodeHintType, BarcodeFormat } from '@zxing/library';
import { CloseIconComponent } from '@/components/icons';

interface BarcodeScannerProps {
  onDetect: (code: string) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
}

export function BarcodeScanner({ onDetect, onError, onClose, isActive }: BarcodeScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const readerRef = useRef<BrowserMultiFormatReader | null>(null);

  const stopScanning = useCallback(() => {
    if (readerRef.current) {
      readerRef.current.reset();
    }
    setIsScanning(false);
  }, []);

  const startScanning = useCallback(async () => {
    try {
      setError(null);
      setIsScanning(true);

      // Check for camera permission
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera not supported in this browser');
      }

      // Initialize the barcode reader with optimized hints
      if (!readerRef.current) {
        const hints = new Map();

        // Enable TRY_HARDER for better accuracy
        hints.set(DecodeHintType.TRY_HARDER, true);

        // Specify common barcode formats for food products
        hints.set(DecodeHintType.POSSIBLE_FORMATS, [
          BarcodeFormat.EAN_13,
          BarcodeFormat.EAN_8,
          BarcodeFormat.UPC_A,
          BarcodeFormat.UPC_E,
          BarcodeFormat.CODE_128,
          BarcodeFormat.CODE_39,
        ]);

        // Reduce time between scans for more responsive scanning
        readerRef.current = new BrowserMultiFormatReader(hints, 100);
      }

      const reader = readerRef.current;

      // Start scanning - try to use back camera if available
      if (videoRef.current) {
        try {
          // Try to get back camera first (better for barcode scanning)
          let selectedDeviceId = null;
          try {
            const devices = await navigator.mediaDevices.enumerateDevices();
            const videoDevices = devices.filter(device => device.kind === 'videoinput');

            // Look for back camera
            const backCamera = videoDevices.find(device =>
              device.label.toLowerCase().includes('back') ||
              device.label.toLowerCase().includes('rear') ||
              device.label.toLowerCase().includes('environment')
            );

            if (backCamera) {
              selectedDeviceId = backCamera.deviceId;
              console.log('📷 Using back camera:', backCamera.label);
            } else if (videoDevices.length > 0) {
              // Use the last camera (often the back camera on mobile)
              selectedDeviceId = videoDevices[videoDevices.length - 1].deviceId;
              console.log('📷 Using camera:', videoDevices[videoDevices.length - 1].label);
            }
          } catch (deviceError) {
            console.log('📷 Could not enumerate devices, using default camera:', deviceError);
          }

          await reader.decodeFromVideoDevice(
            selectedDeviceId,
            videoRef.current,
            (result, error) => {
              if (result) {
                const code = result.getText();
                console.log('📷 BarcodeScanner: Barcode detected:', code);
                console.log('📤 BarcodeScanner: Calling onDetect callback');
                onDetect(code);
                console.log('🛑 BarcodeScanner: Stopping scanning');
                stopScanning();
              }

              if (error && !(error instanceof NotFoundException)) {
                console.error('❌ BarcodeScanner: Scanning error:', error);
              }
            }
          );

          // If we get here, camera access was successful
          setHasPermission(true);
        } catch (scanError) {
          console.error('Failed to start scanning:', scanError);
          setHasPermission(false);
          setError('Failed to start camera scanning');
          onError?.('Failed to start camera scanning');
        }
      }

    } catch (err) {
      console.error('Camera access error:', err);
      setHasPermission(false);

      const errorMessage = err instanceof Error ? err.message : 'Camera access denied';
      setError(errorMessage);
      onError?.(errorMessage);
      setIsScanning(false);
    }
  }, [onDetect, onError, stopScanning]);

  useEffect(() => {
    if (!isActive) {
      stopScanning();
      return;
    }

    startScanning();

    return () => {
      stopScanning();
    };
  }, [isActive, startScanning, stopScanning]);

  if (!isActive) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex flex-col">
      {/* Header */}
      <div className="bg-black/20 backdrop-blur-xl border-b border-white/10 text-white p-6 flex justify-between items-center">
        <div className="flex items-center space-x-4">
          <div className="p-3 bg-blue-500/20 rounded-2xl border border-blue-400/30">
            <svg className="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h2M4 4h5.4" />
            </svg>
          </div>
          <div>
            <h2 className="text-xl font-semibold text-white">Scan Barcode</h2>
            <p className="text-white/60 text-sm">Point camera at product barcode</p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="text-white/60 hover:text-white p-2 rounded-xl hover:bg-white/10 transition-all"
        >
          <CloseIconComponent size="lg" className="text-white/60 hover:text-white" />
        </button>
      </div>

      {/* Camera View */}
      <div className="flex-1 relative">
        {hasPermission === false && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/80 backdrop-blur-md text-white text-center p-6">
            <div className="card-glass rounded-3xl p-8 max-w-md">
              <div className="mb-6">
                <div className="p-4 bg-red-500/20 rounded-2xl border border-red-400/30 mx-auto w-fit mb-4">
                  <svg className="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                </div>
                <p className="mb-6 text-white/80">Camera access is required to scan barcodes.</p>
                <button
                  onClick={startScanning}
                  className="bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200 px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                >
                  Grant Camera Access
                </button>
              </div>
            </div>
          </div>
        )}

        {error && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/80 backdrop-blur-md text-white text-center p-6">
            <div className="card-glass rounded-3xl p-8 max-w-md">
              <div className="mb-6">
                <div className="p-4 bg-red-500/20 rounded-2xl border border-red-400/30 mx-auto w-fit mb-4">
                  <svg className="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <p className="mb-6 text-red-300">{error}</p>
                <div className="flex gap-3">
                  <button
                    onClick={startScanning}
                    className="bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200 px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                  >
                    Try Again
                  </button>
                  <button
                    onClick={onClose}
                    className="bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        <video
          ref={videoRef}
          className="w-full h-full object-cover"
          playsInline
          muted
        />

        {/* Scanning Overlay */}
        {isScanning && hasPermission && !error && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            {/* Scanning Frame */}
            <div className="relative">
              {/* Main scanning area */}
              <div className="w-64 h-40 border-2 border-white/50 rounded-lg relative">
                {/* Corner indicators */}
                <div className="absolute top-0 left-0 w-6 h-6 border-t-4 border-l-4 border-green-400 rounded-tl-lg"></div>
                <div className="absolute top-0 right-0 w-6 h-6 border-t-4 border-r-4 border-green-400 rounded-tr-lg"></div>
                <div className="absolute bottom-0 left-0 w-6 h-6 border-b-4 border-l-4 border-green-400 rounded-bl-lg"></div>
                <div className="absolute bottom-0 right-0 w-6 h-6 border-b-4 border-r-4 border-green-400 rounded-br-lg"></div>

                {/* Scanning line animation */}
                <div className="absolute inset-0 overflow-hidden rounded-lg">
                  <div className="w-full h-0.5 bg-gradient-to-r from-transparent via-green-400 to-transparent animate-pulse"></div>
                </div>
              </div>

              {/* Instructions */}
              <div className="mt-4 text-center">
                <p className="text-white text-sm font-medium">Position barcode within the frame</p>
                <p className="text-white/70 text-xs mt-1">Hold steady for best results</p>
              </div>
            </div>
          </div>
        )}

        {/* Scanning overlay */}
        {isScanning && (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="relative">
              {/* Scanning frame */}
              <div className="border-4 border-white/80 w-72 h-40 relative rounded-2xl">
                <div className="absolute inset-0 border-4 border-blue-400 animate-pulse rounded-2xl"></div>

                {/* Corner indicators */}
                <div className="absolute top-0 left-0 w-8 h-8 border-l-4 border-t-4 border-blue-400 rounded-tl-2xl"></div>
                <div className="absolute top-0 right-0 w-8 h-8 border-r-4 border-t-4 border-blue-400 rounded-tr-2xl"></div>
                <div className="absolute bottom-0 left-0 w-8 h-8 border-l-4 border-b-4 border-blue-400 rounded-bl-2xl"></div>
                <div className="absolute bottom-0 right-0 w-8 h-8 border-r-4 border-b-4 border-blue-400 rounded-br-2xl"></div>
              </div>

              {/* Scanning line */}
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="w-64 h-1 bg-blue-400 animate-pulse shadow-lg shadow-blue-400/50"></div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Instructions */}
      <div className="bg-black/20 backdrop-blur-xl border-t border-white/10 text-white p-6 text-center">
        <p className="text-white/80 font-medium">
          {isScanning
            ? 'Position the barcode within the frame'
            : 'Preparing camera...'}
        </p>
        <p className="text-white/60 text-sm mt-2">
          Make sure the barcode is clearly visible and well-lit
        </p>
      </div>
    </div>
  );
}
