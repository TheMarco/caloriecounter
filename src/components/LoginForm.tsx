'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

interface LoginFormProps {
  onSuccess?: () => void;
}

export function LoginForm({ onSuccess }: LoginFormProps) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      const response = await fetch('/api/auth', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ password }),
      });

      if (response.ok) {
        // Cookie is set by the server (httpOnly)
        // Call success callback if provided
        if (onSuccess) {
          onSuccess();
        } else {
          // Redirect to main app
          router.push('/');
        }
      } else {
        const data = await response.json();
        setError(data.error || 'Incorrect password');
        setPassword('');
      }
    } catch {
      setError('Authentication failed. Please try again.');
      setPassword('');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4">
      <div className="card-glass rounded-3xl p-8 m-4 max-w-sm w-full shadow-2xl">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="p-4 bg-blue-500/20 rounded-2xl border border-blue-400/30 inline-block mb-4">
            <svg className="w-8 h-8 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Access Required</h2>
          <p className="text-white/70">Enter password to continue</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-white/80 mb-3">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              className="w-full px-4 py-4 border border-white/20 rounded-2xl focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400 text-white bg-white/10 placeholder-white/50 backdrop-blur-sm transition-all text-base"
              disabled={isLoading}
              autoFocus
            />
            {error && (
              <p className="text-red-400 text-sm mt-2">{error}</p>
            )}
          </div>

          <button
            type="submit"
            disabled={isLoading || !password.trim()}
            className="w-full bg-blue-500/20 hover:bg-blue-500/30 disabled:bg-gray-500/20 backdrop-blur-sm border border-blue-400/30 hover:border-blue-400/50 disabled:border-gray-400/20 py-4 px-6 rounded-2xl font-semibold transition-all text-blue-300 hover:text-blue-200 disabled:text-gray-400"
          >
            {isLoading ? 'Checking...' : 'Enter App'}
          </button>
        </form>

        {/* Footer */}
        <div className="text-center mt-6">
          <p className="text-white/40 text-xs">
            Calorie Counter PWA
          </p>
        </div>
      </div>
    </div>
  );
}
