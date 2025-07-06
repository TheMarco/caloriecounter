'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { BrowserMultiFormatReader, NotFoundException } from '@zxing/library';

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

      // Request camera permission
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          facingMode: 'environment' // Use back camera if available
        } 
      });
      
      setHasPermission(true);

      // Stop the stream immediately as ZXing will handle it
      stream.getTracks().forEach(track => track.stop());

      // Initialize the barcode reader
      if (!readerRef.current) {
        readerRef.current = new BrowserMultiFormatReader();
      }

      const reader = readerRef.current;

      // Start scanning
      if (videoRef.current) {
        try {
          await reader.decodeFromVideoDevice(
            null, // Use default video device
            videoRef.current,
            (result, error) => {
              if (result) {
                const code = result.getText();
                console.log('Barcode detected:', code);
                onDetect(code);
                stopScanning();
              }
              
              if (error && !(error instanceof NotFoundException)) {
                console.error('Scanning error:', error);
              }
            }
          );
        } catch (scanError) {
          console.error('Failed to start scanning:', scanError);
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
    <div className="fixed inset-0 bg-black z-50 flex flex-col">
      {/* Header */}
      <div className="bg-black text-white p-4 flex justify-between items-center">
        <h2 className="text-lg font-semibold">Scan Barcode</h2>
        <button
          onClick={onClose}
          className="text-white hover:text-gray-300 text-xl font-bold"
        >
          ✕
        </button>
      </div>

      {/* Camera View */}
      <div className="flex-1 relative">
        {hasPermission === false && (
          <div className="absolute inset-0 flex items-center justify-center bg-black text-white text-center p-4">
            <div>
              <p className="mb-4">Camera access is required to scan barcodes.</p>
              <button
                onClick={startScanning}
                className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded"
              >
                Grant Camera Access
              </button>
            </div>
          </div>
        )}

        {error && (
          <div className="absolute inset-0 flex items-center justify-center bg-black text-white text-center p-4">
            <div>
              <p className="mb-4 text-red-400">{error}</p>
              <button
                onClick={startScanning}
                className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded mr-2"
              >
                Try Again
              </button>
              <button
                onClick={onClose}
                className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        <video
          ref={videoRef}
          className="w-full h-full object-cover"
          playsInline
          muted
        />

        {/* Scanning overlay */}
        {isScanning && (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="border-2 border-white w-64 h-32 relative">
              <div className="absolute inset-0 border-2 border-red-500 animate-pulse"></div>
            </div>
          </div>
        )}
      </div>

      {/* Instructions */}
      <div className="bg-black text-white p-4 text-center">
        <p className="text-sm">
          {isScanning 
            ? 'Point your camera at a barcode to scan' 
            : 'Preparing camera...'}
        </p>
      </div>
    </div>
  );
}
