'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { MicrophoneIconComponent, CloseIconComponent } from '@/components/icons';

interface VoiceInputProps {
  onTranscript: (text: string) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
  isProcessing?: boolean;
}

export function VoiceInput({ onTranscript, onError, onClose, isActive, isProcessing = false }: VoiceInputProps) {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const startTimeRef = useRef<number | null>(null);

  const stopListening = useCallback(() => {
    // Clear any pending timeouts
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }

    // Stop speech recognition
    if (recognitionRef.current) {
      recognitionRef.current.stop();
      recognitionRef.current = null;
    }

    // Stop and release media stream
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(track => {
        track.stop();
        console.log('🎤 Stopped microphone track:', track.kind);
      });
      mediaStreamRef.current = null;
    }

    setIsListening(false);
    startTimeRef.current = null;
  }, []);

  const startListening = useCallback(async () => {
    try {
      setError(null);
      setTranscript('');
      startTimeRef.current = Date.now();

      // Request microphone permission and store the stream
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      setHasPermission(true);
      console.log('🎤 Microphone access granted');

      // Check if speech recognition is available
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechRecognition) {
        throw new Error('Speech recognition not supported in this browser');
      }

      // Initialize speech recognition
      const recognition = new SpeechRecognition();

      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.lang = 'en-US';

      // Set up timeout to detect if speech recognition gets stuck
      timeoutRef.current = setTimeout(() => {
        const elapsed = startTimeRef.current ? Date.now() - startTimeRef.current : 0;
        console.error('🎤 Speech recognition timeout after', elapsed, 'ms');

        const errorMessage = 'Voice recognition timed out. This may be due to browser limitations on your device. Please try text input instead.';
        setError(errorMessage);
        onError?.(errorMessage);
        stopListening();
      }, 8000); // 8 second timeout

      recognition.onstart = () => {
        // Clear timeout since recognition actually started
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }

        setIsListening(true);
        console.log('Voice recognition started');
      };

      recognition.onresult = (event) => {
        let finalTranscript = '';
        let interimTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += transcript;
          } else {
            interimTranscript += transcript;
          }
        }

        setTranscript(finalTranscript || interimTranscript);

        if (finalTranscript) {
          console.log('Final transcript:', finalTranscript);
          onTranscript(finalTranscript.trim());
          stopListening();
        }
      };

      recognition.onerror = (event) => {
        // Clear timeout on error
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }

        console.error('Speech recognition error:', event.error);
        let errorMessage = 'Speech recognition failed';

        switch (event.error) {
          case 'no-speech':
            errorMessage = 'No speech detected. Please try again.';
            break;
          case 'audio-capture':
            errorMessage = 'Microphone not accessible. Please check permissions.';
            break;
          case 'not-allowed':
            errorMessage = 'Microphone access denied. Please allow microphone access.';
            setHasPermission(false);
            break;
          case 'network':
            errorMessage = 'Network error. Please check your connection.';
            break;
          case 'service-not-allowed':
            errorMessage = 'Speech recognition service not available. Please try text input instead.';
            break;
          default:
            errorMessage = `Speech recognition error: ${event.error}. Try text input instead.`;
        }

        setError(errorMessage);
        onError?.(errorMessage);
        setIsListening(false);
      };

      recognition.onend = () => {
        // Clear timeout on end
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }

        setIsListening(false);
        console.log('Voice recognition ended');
      };

      recognitionRef.current = recognition;
      recognition.start();

    } catch (err) {
      console.error('Microphone access error:', err);

      // Clear any pending timeout
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }

      setHasPermission(false);

      // Provide more helpful error messages based on the platform
      const isAndroid = /Android/i.test(navigator.userAgent);
      const isPWA = window.matchMedia('(display-mode: standalone)').matches;

      let errorMessage = 'Microphone access denied. Please allow microphone access.';

      if (isAndroid && isPWA) {
        errorMessage = 'Voice input may not work reliably in PWA mode on Android. Try using the app in your browser instead, or use text input.';
      } else if (isAndroid) {
        errorMessage = 'Voice input has limited support on Android browsers. Please try text input instead.';
      }

      setError(errorMessage);
      onError?.(errorMessage);
    }
  }, [onTranscript, onError, stopListening]);

  useEffect(() => {
    if (!isActive) {
      stopListening();
      return;
    }

    // Check for Web Speech API support
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      setError('Speech recognition not supported in this browser');
      onError?.('Speech recognition not supported in this browser');
      return;
    }

    startListening();

    return () => {
      stopListening();
    };
  }, [isActive, startListening, stopListening, onError]);

  // Cleanup on component unmount
  useEffect(() => {
    return () => {
      stopListening();
    };
  }, [stopListening]);

  // Stop listening when page becomes hidden (minimized/switched tabs)
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.hidden && isListening) {
        console.log('🎤 Page hidden, stopping microphone');
        stopListening();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [isListening, stopListening]);

  if (!isActive) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div data-testid="voice-input-dialog" className="card-glass rounded-3xl p-6 m-4 max-w-sm w-full shadow-2xl">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-green-500/20 rounded-2xl border border-green-400/30">
              <svg className="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-white">Voice Input</h2>
          </div>
          <button
            data-testid="voice-cancel-button"
            onClick={onClose}
            className="text-white/60 hover:text-white p-2 rounded-xl hover:bg-white/10 transition-all"
          >
            <CloseIconComponent size="lg" className="text-white/60 hover:text-white" />
          </button>
        </div>

        {/* Content */}
        <div className="text-center">
          {hasPermission === false && (
            <div className="mb-6">
              <div className="bg-red-500/20 border border-red-400/30 p-4 rounded-2xl backdrop-blur-sm mb-4">
                <p className="text-red-300 mb-4">Microphone access is required for voice input.</p>
                <button
                  onClick={startListening}
                  className="bg-blue-500/20 hover:bg-blue-500/30 border border-blue-400/30 hover:border-blue-400/50 text-blue-300 hover:text-blue-200 px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                >
                  Grant Microphone Access
                </button>
              </div>
            </div>
          )}

          {error && (
            <div className="mb-6">
              <div className="bg-red-500/20 border border-red-400/30 p-4 rounded-2xl backdrop-blur-sm mb-4">
                <p className="text-red-300 mb-4">{error}</p>
                <div className="flex gap-3 justify-center">
                  <button
                    onClick={startListening}
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
          )}

          {!error && hasPermission !== false && (
            <>
              {/* Microphone Animation */}
              <div className="mb-6">
                {isProcessing ? (
                  <div className="w-20 h-20 mx-auto rounded-full flex items-center justify-center transition-all duration-300 bg-blue-500/30 border-2 border-blue-400">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-300"></div>
                  </div>
                ) : (
                  <div className={`w-20 h-20 mx-auto rounded-full flex items-center justify-center transition-all duration-300 ${
                    isListening ? 'bg-red-500/30 border-2 border-red-400 animate-pulse shadow-lg shadow-red-500/25' : 'bg-white/10 border-2 border-white/20'
                  }`}>
                    <MicrophoneIconComponent size="xl" className={isListening ? "text-red-300" : "text-white/70"} />
                  </div>
                )}
              </div>

              {/* Status */}
              <p className="text-white/80 mb-6 text-lg font-medium">
                {isProcessing
                  ? 'Processing your food...'
                  : isListening
                  ? 'Listening... Speak now!'
                  : 'Preparing microphone...'}
              </p>

              {/* Android PWA Warning */}
              {!isListening && !isProcessing && /Android/i.test(navigator.userAgent) && window.matchMedia('(display-mode: standalone)').matches && (
                <div className="bg-yellow-500/20 border border-yellow-400/30 p-3 rounded-2xl mb-4 backdrop-blur-sm">
                  <p className="text-xs text-yellow-300">
                    Voice input may not work reliably in PWA mode on Android. If it gets stuck, try text input instead.
                  </p>
                </div>
              )}

              {/* Transcript */}
              {transcript && (
                <div className="bg-blue-500/20 border border-blue-400/30 p-4 rounded-2xl mb-6 backdrop-blur-sm">
                  <p className="text-sm text-blue-300 font-medium">&quot;{transcript}&quot;</p>
                </div>
              )}

              {/* Instructions */}
              <p className="text-xs text-white/60 mb-6">
                Say something like: &quot;One grilled boneless chicken thigh&quot;
              </p>

              {/* Controls */}
              {!isProcessing && (
                <div className="flex justify-center">
                  <button
                    onClick={onClose}
                    className="bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                  >
                    Cancel
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
