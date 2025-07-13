'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { CloseIconComponent, CameraIconComponent } from '@/components/icons';

interface PhotoCaptureProps {
  onCapture: (imageData: string, details?: { plateSize: string; servingType: string; additionalDetails: string }) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
  isProcessing?: boolean;
  processingError?: string | null;
  onClearError?: () => void;
}

export function PhotoCapture({ onCapture, onError, onClose, isActive, isProcessing = false, processingError = null, onClearError }: PhotoCaptureProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [isMounted, setIsMounted] = useState(false);
  const [showDetailsScreen, setShowDetailsScreen] = useState(false);
  const [additionalDetails, setAdditionalDetails] = useState('');
  const [plateSize, setPlateSize] = useState('medium');
  const [servingType, setServingType] = useState('home');
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

      // Enhanced camera selection - use same logic as BarcodeScanner
      let selectedDeviceId: string | null = null;

      try {
        const devices = await navigator.mediaDevices.enumerateDevices();
        const videoDevices = devices.filter(device => device.kind === 'videoinput');

        console.log('📷 Available cameras:', videoDevices.map(d => d.label));

        // Look for back camera with better heuristics (same as BarcodeScanner)
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
          console.log('📷 Using back camera:', backCamera.label);
        }
      } catch {
        console.log('📷 Using default camera with environment facing mode');
      }

      // Request camera access with device selection (same approach as BarcodeScanner)
      const constraints: MediaStreamConstraints = {
        video: selectedDeviceId ? {
          deviceId: { exact: selectedDeviceId },
          width: { ideal: 1280, min: 640 },
          height: { ideal: 720, min: 480 }
        } : {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280, min: 640 },
          height: { ideal: 720, min: 480 }
        }
      };

      console.log('📷 Requesting camera with constraints:', constraints);

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      streamRef.current = stream;

      if (videoRef.current) {
        const video = videoRef.current;
        video.srcObject = stream;

        console.log('📷 Camera stream assigned to video element');

        // Immediately set streaming state - mobile Safari/PWA often doesn't fire events properly
        setIsStreaming(true);
        setHasPermission(true);
        console.log('📷 Streaming state set immediately');
        console.log('📷 Video element:', video);
        console.log('📷 Stream tracks:', stream.getTracks().map(t => ({ kind: t.kind, enabled: t.enabled, readyState: t.readyState })));

        // Try to play the video
        const playVideo = async () => {
          try {
            await video.play();
            console.log('📷 Video playing successfully');
          } catch (playError) {
            console.error('📷 Video play error:', playError);
            // Don't set error here, streaming state is already set
          }
        };

        // Add event listeners for additional feedback
        video.onloadedmetadata = () => {
          console.log('📷 Video metadata loaded, dimensions:', video.videoWidth, 'x', video.videoHeight);
          playVideo();
        };

        video.oncanplay = () => {
          console.log('📷 Video can play');
          playVideo();
        };

        video.onplaying = () => {
          console.log('📷 Video is playing');
        };

        video.onerror = (videoError) => {
          console.error('📷 Video element error:', videoError);
          setError('Video playback error');
        };

        // Immediate play attempt
        playVideo();
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

    // Resize to smaller dimensions for API efficiency
    const maxWidth = 800;
    const maxHeight = 600;

    let { videoWidth, videoHeight } = video;

    // Calculate scaled dimensions
    if (videoWidth > maxWidth || videoHeight > maxHeight) {
      const ratio = Math.min(maxWidth / videoWidth, maxHeight / videoHeight);
      videoWidth = Math.floor(videoWidth * ratio);
      videoHeight = Math.floor(videoHeight * ratio);
    }

    canvas.width = videoWidth;
    canvas.height = videoHeight;

    // Draw the current video frame to canvas (scaled)
    context.drawImage(video, 0, 0, videoWidth, videoHeight);

    // Convert to base64 image data with lower quality to reduce size
    const imageData = canvas.toDataURL('image/jpeg', 0.5);
    setCapturedImage(imageData);

    console.log('📸 Photo captured, size:', imageData.length);
    console.log('📸 Canvas dimensions:', canvas.width, 'x', canvas.height);
  }, [isStreaming]);

  const confirmCapture = useCallback(() => {
    if (capturedImage) {
      console.log('📸 Confirming photo capture, image size:', capturedImage.length);
      onCapture(capturedImage);
      stopStreaming();
    } else {
      console.error('📸 No captured image to confirm');
    }
  }, [capturedImage, onCapture, stopStreaming]);

  const retakePhoto = useCallback(() => {
    setCapturedImage(null);
    setShowDetailsScreen(false);
    setAdditionalDetails('');
    setPlateSize('medium');
    setServingType('home');
  }, []);

  const showDetails = useCallback(() => {
    setShowDetailsScreen(true);
  }, []);

  const hideDetails = useCallback(() => {
    setShowDetailsScreen(false);
    setAdditionalDetails('');
    setPlateSize('medium');
    setServingType('home');
  }, []);

  const confirmWithDetails = useCallback(() => {
    if (capturedImage) {
      const details = {
        plateSize,
        servingType,
        additionalDetails: additionalDetails.trim()
      };
      console.log('📸 Confirming photo with details:', details);
      onCapture(capturedImage, details);
      stopStreaming();
    }
  }, [capturedImage, plateSize, servingType, additionalDetails, onCapture, stopStreaming]);

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



  if ((!isActive && !isProcessing && !processingError) || !isMounted) {
    return null;
  }

  return (
    <div
      className="fixed inset-0 bg-black z-50 flex flex-col"
      style={{
        height: '100vh',
        width: '100vw',
        overflow: 'hidden',
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0
      }}
    >
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
      <div className="flex-1 relative flex items-center justify-center min-h-0">
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

        {isProcessing || processingError ? (
          <div className="flex flex-col items-center justify-center h-full bg-black/90">
            <div className="text-center text-white p-8">
              {processingError ? (
                <>
                  <div className="mb-6">
                    <div className="w-16 h-16 mx-auto bg-red-500/20 rounded-full flex items-center justify-center">
                      <div className="text-red-400 text-2xl">⚠️</div>
                    </div>
                  </div>
                  <h3 className="text-xl font-semibold mb-4 text-red-400">Unable to analyze photo</h3>
                  <p className="text-white/80 text-sm mb-6 max-w-sm">
                    We couldn&apos;t identify any food in this photo. Please try taking a clearer picture of your meal, or make sure the food is well-lit and clearly visible.
                  </p>
                  <button
                    onClick={() => {
                      setCapturedImage(null);
                      onClearError?.();
                    }}
                    className="px-6 py-3 bg-blue-600 text-white rounded-2xl hover:bg-blue-700 transition-colors"
                  >
                    Try Again
                  </button>
                </>
              ) : (
                <>
                  <div className="mb-6">
                    <div className="animate-spin rounded-full h-16 w-16 border-4 border-orange-400 border-t-transparent mx-auto"></div>
                  </div>
                  <h3 className="text-xl font-semibold mb-2">Analyzing your photo...</h3>
                  <p className="text-white/80 text-sm">
                    Our AI is identifying the food and calculating nutritional information
                  </p>
                  <div className="mt-4 text-xs text-white/60">
                    This usually takes a few seconds
                  </div>
                </>
              )}
            </div>
          </div>
        ) : capturedImage ? (
          <img
            src={capturedImage}
            alt="Captured food"
            className="max-w-full max-h-full object-contain"
          />
        ) : (
          <>
            <video
              ref={videoRef}
              className="w-full h-full object-cover"
              playsInline
              muted
              autoPlay
              style={{
                display: 'block', // Always show video element
                maxHeight: '100%',
                maxWidth: '100%',
                backgroundColor: '#000'
              }}
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
      <div className="p-6 bg-black/50 backdrop-blur-md flex-shrink-0">
        {capturedImage ? (
          showDetailsScreen ? (
            // Details Screen
            <div className="space-y-4">
              <div className="text-center mb-4">
                <h3 className="text-lg font-semibold text-white mb-2">
                  Add Details for Better Accuracy
                </h3>
                <div className="inline-flex items-center px-3 py-1 bg-blue-500/20 border border-blue-400/30 rounded-full">
                  <svg className="w-4 h-4 text-blue-400 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-xs text-blue-300 font-medium">
                    Any extra info you provide will make the estimate more accurate
                  </span>
                </div>
              </div>

              {/* Plate Size */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Plate/Bowl Size
                </label>
                <select
                  value={plateSize}
                  onChange={(e) => setPlateSize(e.target.value)}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 backdrop-blur-sm transition-all"
                >
                  <option value="small" className="bg-gray-800 text-white">Small plate/bowl</option>
                  <option value="medium" className="bg-gray-800 text-white">Medium plate/bowl</option>
                  <option value="large" className="bg-gray-800 text-white">Large plate/bowl</option>
                  <option value="extra-large" className="bg-gray-800 text-white">Extra large plate/bowl</option>
                </select>
              </div>

              {/* Serving Type */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Serving Type
                </label>
                <select
                  value={servingType}
                  onChange={(e) => setServingType(e.target.value)}
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 backdrop-blur-sm transition-all"
                >
                  <option value="home" className="bg-gray-800 text-white">Home cooking</option>
                  <option value="restaurant" className="bg-gray-800 text-white">Restaurant serving</option>
                  <option value="fast-food" className="bg-gray-800 text-white">Fast food</option>
                  <option value="snack" className="bg-gray-800 text-white">Snack portion</option>
                </select>
              </div>

              {/* Additional Details */}
              <div>
                <label className="block text-sm font-medium text-white/80 mb-2">
                  Additional Details (Optional)
                </label>
                <textarea
                  value={additionalDetails}
                  onChange={(e) => setAdditionalDetails(e.target.value)}
                  placeholder="e.g., 'half eaten', 'extra sauce', 'grilled chicken', 'thick crust pizza', 'fried not baked', 'with butter', 'shared between 2 people'..."
                  className="w-full px-4 py-3 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all resize-none"
                  rows={3}
                />
                <div className="mt-2 text-xs text-white/60">
                  💡 Helpful details: cooking method, thickness, sauces, portion eaten, sharing info
                </div>
              </div>

              {/* Details Screen Buttons */}
              <div className="flex space-x-3 pt-4">
                <button
                  onClick={hideDetails}
                  className="flex-1 px-6 py-3 bg-gray-600 text-white rounded-2xl hover:bg-gray-700 transition-colors"
                >
                  Back
                </button>
                <button
                  onClick={confirmWithDetails}
                  className="flex-1 px-6 py-3 bg-green-600 text-white rounded-2xl hover:bg-green-700 transition-colors"
                >
                  Analyze with Details
                </button>
              </div>
            </div>
          ) : (
            // Initial Photo Review
            <div className="flex justify-center space-x-3">
              <button
                onClick={retakePhoto}
                className="px-6 py-3 bg-gray-600 text-white rounded-2xl hover:bg-gray-700 transition-colors"
              >
                Retake
              </button>
              <button
                onClick={showDetails}
                className="px-6 py-3 bg-blue-600 text-white rounded-2xl hover:bg-blue-700 transition-colors"
              >
                Add Details
              </button>
              <button
                onClick={confirmCapture}
                className="px-6 py-3 bg-green-600 text-white rounded-2xl hover:bg-green-700 transition-colors"
              >
                Use Photo
              </button>
            </div>
          )
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
