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

  const stopListening = useCallback(() => {
    if (recognitionRef.current) {
      recognitionRef.current.stop();
      recognitionRef.current = null;
    }
    setIsListening(false);
  }, []);

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

  if (!isActive) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div className="card-glass rounded-3xl p-6 m-4 max-w-sm w-full shadow-2xl">
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
                <div className={`w-20 h-20 mx-auto rounded-full flex items-center justify-center transition-all duration-300 ${
                  isListening ? 'bg-red-500/30 border-2 border-red-400 animate-pulse shadow-lg shadow-red-500/25' : 'bg-white/10 border-2 border-white/20'
                }`}>
                  <MicrophoneIconComponent size="xl" className={isListening ? "text-red-300" : "text-white/70"} />
                </div>
              </div>

              {/* Status */}
              <p className="text-white/80 mb-6 text-lg font-medium">
                {isListening
                  ? 'Listening... Speak now!'
                  : 'Preparing microphone...'}
              </p>

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
              <div className="flex gap-3 justify-center">
                {!isListening && (
                  <button
                    onClick={startListening}
                    className="bg-green-500/20 hover:bg-green-500/30 border border-green-400/30 hover:border-green-400/50 text-green-300 hover:text-green-200 px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                  >
                    Start Listening
                  </button>
                )}
                {isListening && (
                  <button
                    onClick={stopListening}
                    className="bg-red-500/20 hover:bg-red-500/30 border border-red-400/30 hover:border-red-400/50 text-red-300 hover:text-red-200 px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
                  >
                    Stop
                  </button>
                )}
                <button
                  onClick={onClose}
                  className="bg-white/10 hover:bg-white/20 border border-white/20 hover:border-white/30 text-white/80 hover:text-white px-6 py-3 rounded-2xl font-medium transition-all duration-200 backdrop-blur-sm hover:scale-105 active:scale-95"
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
