'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { BrowserMultiFormatReader } from '@zxing/library';
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
      console.log('🎥 Starting barcode scanning...');
      setError(null);
      setIsScanning(true);

      // Check for camera permission
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.error('❌ Camera not supported');
        throw new Error('Camera not supported in this browser');
      }

      console.log('✅ Camera API available');

      // Initialize optimized barcode reader
      if (!readerRef.current) {
        readerRef.current = new BrowserMultiFormatReader();

        // Configure for better performance
        const hints = new Map();
        // Focus on common barcode formats for food products
        hints.set(2, [8, 13, 14]); // CODE_128, EAN_13, EAN_8
        hints.set(3, true); // TRY_HARDER for better accuracy
        hints.set(4, true); // PURE_BARCODE

        readerRef.current.hints = hints;
      }

      const reader = readerRef.current;

      // Start scanning with optimized approach
      if (videoRef.current) {
        try {
          // Enhanced camera selection - prefer back camera with higher resolution
          let selectedDeviceId: string | null = null;
          let constraints = {
            video: {
              facingMode: 'environment', // Prefer back camera
              width: { ideal: 1280, min: 640 },
              height: { ideal: 720, min: 480 },
              focusMode: 'continuous',
              zoom: true
            }
          };

          try {
            const devices = await navigator.mediaDevices.enumerateDevices();
            const videoDevices = devices.filter(device => device.kind === 'videoinput');

            // Look for back camera with better heuristics
            const backCamera = videoDevices.find(device => {
              const label = device.label.toLowerCase();
              return label.includes('back') ||
                     label.includes('rear') ||
                     label.includes('environment') ||
                     label.includes('camera 0') || // Often the main camera
                     (!label.includes('front') && !label.includes('user'));
            });

            if (backCamera) {
              selectedDeviceId = backCamera.deviceId;
              constraints.video = {
                ...constraints.video,
                deviceId: { exact: backCamera.deviceId }
              };
            }
          } catch {
            console.log('Using default camera with environment facing mode');
          }

          // Start decoding with enhanced settings
          await reader.decodeFromVideoDevice(
            selectedDeviceId,
            videoRef.current,
            (result) => {
              if (result) {
                const code = result.getText();
                console.log('🎯 Barcode detected:', code);
                onDetect(code);
                stopScanning();
              }
            }
          );

          setHasPermission(true);
        } catch (scanError) {
          console.error('Failed to start scanning:', scanError);
          setHasPermission(false);
          setError('Failed to start camera');
          onError?.('Failed to start camera');
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

        {/* Enhanced Scanning Overlay */}
        {isScanning && hasPermission && !error && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="relative w-80 h-48">
              {/* Corner brackets with glow effect */}
              <div className="absolute top-0 left-0 w-12 h-12 border-t-4 border-l-4 border-green-400 rounded-tl-lg shadow-lg shadow-green-400/50"></div>
              <div className="absolute top-0 right-0 w-12 h-12 border-t-4 border-r-4 border-green-400 rounded-tr-lg shadow-lg shadow-green-400/50"></div>
              <div className="absolute bottom-0 left-0 w-12 h-12 border-b-4 border-l-4 border-green-400 rounded-bl-lg shadow-lg shadow-green-400/50"></div>
              <div className="absolute bottom-0 right-0 w-12 h-12 border-b-4 border-r-4 border-green-400 rounded-br-lg shadow-lg shadow-green-400/50"></div>

              {/* Animated scanning line */}
              <div className="absolute top-1/2 left-4 right-4 h-1 bg-gradient-to-r from-transparent via-green-400 to-transparent animate-pulse shadow-lg shadow-green-400/50"></div>

              {/* Center focus dot */}
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-2 h-2 bg-green-400 rounded-full animate-ping"></div>
            </div>

            {/* Instruction text */}
            <div className="absolute bottom-20 left-1/2 transform -translate-x-1/2 bg-black/70 backdrop-blur-md px-4 py-2 rounded-full">
              <p className="text-green-400 text-sm font-medium">Align barcode within frame</p>
            </div>
          </div>
        )}
      </div>

      {/* Instructions */}
      <div className="bg-black/20 backdrop-blur-xl border-t border-white/10 text-white p-6 text-center">
        <p className="text-white/80 font-medium">
          {isScanning ? 'Scanning for barcode...' : 'Starting camera...'}
        </p>
        <p className="text-white/60 text-sm mt-1">
          {isScanning ? 'Hold steady • Good lighting • Fill the frame' : 'Please wait while camera loads'}
        </p>
      </div>
    </div>
  );
}
