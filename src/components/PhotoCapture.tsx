'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { CloseIconComponent, CameraIconComponent } from '@/components/icons';

interface PhotoCaptureProps {
  onCapture: (imageData: string) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
}

export function PhotoCapture({ onCapture, onError, onClose, isActive }: PhotoCaptureProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [isMounted, setIsMounted] = useState(false);
  const streamRef = useRef<MediaStream | null>(null);

  // Ensure component only renders on client
  useEffect(() => {
    setIsMounted(true);
  }, []);

  const stopStreaming = useCallback(() => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    setIsStreaming(false);
  }, []);

  const startCamera = useCallback(async () => {
    try {
      setError(null);
      setCapturedImage(null);

      // Check if we're in browser environment
      if (typeof window === 'undefined' || typeof navigator === 'undefined') {
        throw new Error('Camera not available in server environment');
      }

      // Check if camera API is available
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera not supported in this browser');
      }

      console.log('📷 Starting camera for photo capture');

      // Get camera devices
      const devices = await navigator.mediaDevices.enumerateDevices();
      const videoDevices = devices.filter(device => device.kind === 'videoinput');
      
      // Prefer back camera for food photos
      let selectedDeviceId: string | undefined;
      const backCamera = videoDevices.find(device => 
        device.label.toLowerCase().includes('back') || 
        device.label.toLowerCase().includes('rear') ||
        device.label.toLowerCase().includes('environment')
      );
      
      if (backCamera) {
        selectedDeviceId = backCamera.deviceId;
        console.log('📷 Using back camera:', backCamera.label);
      } else if (videoDevices.length > 0) {
        selectedDeviceId = videoDevices[0].deviceId;
        console.log('📷 Using default camera:', videoDevices[0].label);
      }

      // Request camera access with high resolution for better food recognition
      const constraints: MediaStreamConstraints = {
        video: {
          deviceId: selectedDeviceId ? { exact: selectedDeviceId } : undefined,
          width: { ideal: 1920, min: 640 },
          height: { ideal: 1080, min: 480 },
          facingMode: selectedDeviceId ? undefined : { ideal: 'environment' }
        }
      };

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      streamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
        setIsStreaming(true);
        setHasPermission(true);
        console.log('📷 Camera stream started successfully');
      }

    } catch (err) {
      console.error('Camera access error:', err);
      setHasPermission(false);
      const errorMessage = err instanceof Error ? err.message : 'Camera access denied';
      setError(errorMessage);
      onError?.(errorMessage);
      setIsStreaming(false);
    }
  }, [onError]);

  const capturePhoto = useCallback(() => {
    if (!videoRef.current || !canvasRef.current || !isStreaming) {
      return;
    }

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const context = canvas.getContext('2d');

    if (!context) {
      setError('Failed to get canvas context');
      return;
    }

    // Set canvas dimensions to match video
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Draw the current video frame to canvas
    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    // Convert to base64 image data
    const imageData = canvas.toDataURL('image/jpeg', 0.8);
    setCapturedImage(imageData);
    
    console.log('📸 Photo captured, size:', imageData.length);
  }, [isStreaming]);

  const confirmCapture = useCallback(() => {
    if (capturedImage) {
      onCapture(capturedImage);
      stopStreaming();
    }
  }, [capturedImage, onCapture, stopStreaming]);

  const retakePhoto = useCallback(() => {
    setCapturedImage(null);
  }, []);

  useEffect(() => {
    if (!isActive) {
      stopStreaming();
      setCapturedImage(null);
      return;
    }

    startCamera();

    return () => {
      stopStreaming();
    };
  }, [isActive, startCamera, stopStreaming]);

  // Cleanup on component unmount
  useEffect(() => {
    return () => {
      stopStreaming();
    };
  }, [stopStreaming]);

  if (!isActive || !isMounted) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black z-50 flex flex-col">
      {/* Header */}
      <div className="flex justify-between items-center p-4 bg-black/50 backdrop-blur-md">
        <h2 className="text-white text-lg font-semibold">
          {capturedImage ? 'Review Photo' : 'Take Photo of Food'}
        </h2>
        <button
          onClick={onClose}
          className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
        >
          <CloseIconComponent size="md" className="text-white" />
        </button>
      </div>

      {/* Camera View or Captured Image */}
      <div className="flex-1 relative flex items-center justify-center">
        {error && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/80">
            <div className="text-center text-white p-6">
              <p className="text-red-400 mb-4">{error}</p>
              <button
                onClick={startCamera}
                className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
              >
                Try Again
              </button>
            </div>
          </div>
        )}

        {hasPermission === false && !error && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/80">
            <div className="text-center text-white p-6">
              <CameraIconComponent size="xl" className="text-white/50 mx-auto mb-4" />
              <p className="text-white/80 mb-4">Camera access is required to take photos</p>
              <button
                onClick={startCamera}
                className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
              >
                Allow Camera Access
              </button>
            </div>
          </div>
        )}

        {capturedImage ? (
          <img
            src={capturedImage}
            alt="Captured food"
            className="max-w-full max-h-full object-contain"
          />
        ) : (
          <>
            <video
              ref={videoRef}
              className="max-w-full max-h-full object-contain"
              playsInline
              muted
            />
            <canvas ref={canvasRef} className="hidden" />
          </>
        )}

        {/* Camera overlay guide */}
        {isStreaming && !capturedImage && (
          <div className="absolute inset-0 pointer-events-none">
            <div className="absolute inset-4 border-2 border-white/30 rounded-lg"></div>
            <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
              <div className="text-white/80 text-center bg-black/50 px-4 py-2 rounded-lg">
                <p className="text-sm">Position food within the frame</p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Controls */}
      <div className="p-6 bg-black/50 backdrop-blur-md">
        {capturedImage ? (
          <div className="flex justify-center space-x-4">
            <button
              onClick={retakePhoto}
              className="px-6 py-3 bg-gray-600 text-white rounded-2xl hover:bg-gray-700 transition-colors"
            >
              Retake
            </button>
            <button
              onClick={confirmCapture}
              className="px-6 py-3 bg-green-600 text-white rounded-2xl hover:bg-green-700 transition-colors"
            >
              Use Photo
            </button>
          </div>
        ) : (
          <div className="flex justify-center">
            <button
              onClick={capturePhoto}
              disabled={!isStreaming}
              className="w-16 h-16 bg-white rounded-full border-4 border-gray-300 hover:bg-gray-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
            >
              <div className="w-12 h-12 bg-white rounded-full border-2 border-gray-400"></div>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
