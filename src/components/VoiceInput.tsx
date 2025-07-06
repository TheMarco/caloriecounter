'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { MicrophoneIconComponent, CloseIconComponent } from '@/components/icons';

interface VoiceInputProps {
  onTranscript: (text: string) => void;
  onError?: (error: string) => void;
  onClose: () => void;
  isActive: boolean;
}

export function VoiceInput({ onTranscript, onError, onClose, isActive }: VoiceInputProps) {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);

  const startListening = useCallback(async () => {
    try {
      setError(null);
      setTranscript('');

      // Request microphone permission
      await navigator.mediaDevices.getUserMedia({ audio: true });
      setHasPermission(true);

      // Initialize speech recognition
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();

      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.lang = 'en-US';

      recognition.onstart = () => {
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
          default:
            errorMessage = `Speech recognition error: ${event.error}`;
        }
        
        setError(errorMessage);
        onError?.(errorMessage);
        setIsListening(false);
      };

      recognition.onend = () => {
        setIsListening(false);
        console.log('Voice recognition ended');
      };

      recognitionRef.current = recognition;
      recognition.start();

    } catch (err) {
      console.error('Microphone access error:', err);
      setHasPermission(false);
      const errorMessage = 'Microphone access denied. Please allow microphone access.';
      setError(errorMessage);
      onError?.(errorMessage);
    }
  }, [onTranscript, onError]);

  const stopListening = useCallback(() => {
    if (recognitionRef.current) {
      recognitionRef.current.stop();
      recognitionRef.current = null;
    }
    setIsListening(false);
  }, []);

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

  if (!isActive) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
      <div className="bg-white rounded-lg p-6 m-4 max-w-sm w-full">
        {/* Header */}
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">Voice Input</h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 p-1"
          >
            <CloseIconComponent size="lg" className="text-gray-500 hover:text-gray-700" />
          </button>
        </div>

        {/* Content */}
        <div className="text-center">
          {hasPermission === false && (
            <div className="mb-4">
              <p className="text-red-600 mb-4">Microphone access is required for voice input.</p>
              <button
                onClick={startListening}
                className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded"
              >
                Grant Microphone Access
              </button>
            </div>
          )}

          {error && (
            <div className="mb-4">
              <p className="text-red-600 mb-4">{error}</p>
              <button
                onClick={startListening}
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
          )}

          {!error && hasPermission !== false && (
            <>
              {/* Microphone Animation */}
              <div className="mb-4">
                <div className={`w-16 h-16 mx-auto rounded-full flex items-center justify-center ${
                  isListening ? 'bg-red-500 animate-pulse' : 'bg-gray-300'
                }`}>
                  <MicrophoneIconComponent size="xl" className="text-white" />
                </div>
              </div>

              {/* Status */}
              <p className="text-gray-600 mb-4">
                {isListening 
                  ? 'Listening... Speak now!' 
                  : 'Preparing microphone...'}
              </p>

              {/* Transcript */}
              {transcript && (
                <div className="bg-gray-100 border-2 border-gray-300 p-3 rounded mb-4">
                  <p className="text-sm text-gray-900 font-medium">&quot;{transcript}&quot;</p>
                </div>
              )}

              {/* Instructions */}
              <p className="text-xs text-gray-500 mb-4">
                Say something like: &quot;One grilled boneless chicken thigh&quot;
              </p>

              {/* Controls */}
              <div className="flex gap-2 justify-center">
                {!isListening && (
                  <button
                    onClick={startListening}
                    className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded"
                  >
                    Start Listening
                  </button>
                )}
                {isListening && (
                  <button
                    onClick={stopListening}
                    className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded"
                  >
                    Stop
                  </button>
                )}
                <button
                  onClick={onClose}
                  className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-2 rounded"
                >
                  Cancel
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
