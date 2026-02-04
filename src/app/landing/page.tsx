'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  MicrophoneIconComponent,
  CameraIconComponent,
  PencilIconComponent,
  BarcodeIconComponent,
  ChartIconComponent,
  SettingsIconComponent,
  CloseIconComponent
} from '@/components/icons';
import { LoginForm } from '@/components/LoginForm';

export default function LandingPage() {
  const [showLicense, setShowLicense] = useState(false);
  const [showLogin, setShowLogin] = useState(false);
  const [licenseContent, setLicenseContent] = useState<string>('');
  const [currentSlide, setCurrentSlide] = useState(0);
  const carouselRef = useRef<HTMLDivElement>(null);
  const router = useRouter();

  const handleLoginSuccess = () => {
    router.push('/');
  };

  const screenshots = [
    { src: '/screenshots/s1.png', alt: 'Main dashboard with calorie tracking' },
    { src: '/screenshots/s2.png', alt: 'Voice input for food logging' },
    { src: '/screenshots/s3.png', alt: 'Barcode scanning interface' },
    { src: '/screenshots/s4.png', alt: 'Photo-based food recognition' },
    { src: '/screenshots/s5.png', alt: 'Detailed nutrition tracking' },
    { src: '/screenshots/s6.png', alt: 'Settings and preferences' }
  ];

  const handleLicenseClick = async () => {
    try {
      const response = await fetch('/LICENSE');
      const content = await response.text();
      setLicenseContent(content);
      setShowLicense(true);
    } catch (error) {
      console.error('Failed to load license:', error);
      setLicenseContent('Failed to load license content.');
      setShowLicense(true);
    }
  };

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % screenshots.length);
  };

  const goToSlide = (index: number) => {
    setCurrentSlide(index);
  };

  // Auto-advance carousel
  useEffect(() => {
    const interval = setInterval(nextSlide, 4000);
    return () => clearInterval(interval);
  }, [nextSlide]);
  return (
    <div className="min-h-screen gradient-bg text-white overflow-hidden">
      {/* Main content */}
      <div className="relative z-10">
        {/* Header */}
        <header className="bg-black/20 backdrop-blur-xl border-b border-white/10 sticky top-0 z-20">
          <div className="max-w-md mx-auto px-6 py-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <img
                  src="/icons/icon-192.png"
                  alt="Calorie Counter"
                  className="w-10 h-10"
                />
                <div>
                  <h1 className="text-lg font-bold text-white">Calorie Counter</h1>
                  <p className="text-white/70 text-xs">AI-powered nutrition tracking</p>
                </div>
              </div>
              <button
                onClick={() => setShowLogin(true)}
                className="bg-blue-500/20 hover:bg-blue-500/30 backdrop-blur-sm border border-blue-400/30 hover:border-blue-400/50 px-4 py-2 rounded-xl font-semibold transition-all text-sm text-blue-300 hover:text-blue-200 cursor-pointer"
              >
                Launch App
              </button>
            </div>
          </div>
        </header>

        {/* Hero Section */}
        <section className="max-w-md mx-auto px-6 pb-12 pt-6 text-center">
          <div className="mb-8">
            <img
              src="/icons/icon-192.png"
              alt="Calorie Counter"
              className="w-24 h-24 mx-auto mb-6 mt-24"
            />

            <h2 className="text-4xl font-bold mb-4 text-white">
              The Future of
              <br />
              Nutrition Tracking
            </h2>

            <p className="text-white/70 text-lg mb-8 leading-relaxed">
              Experience lightning-fast calorie and macro tracking with cutting-edge AI.
              Voice input, photo recognition, barcode scanning, and beautiful analytics - all in one powerful PWA.
            </p>

            <div className="space-y-4">
              <button
                onClick={() => setShowLogin(true)}
                className="block w-full bg-blue-500/20 hover:bg-blue-500/30 backdrop-blur-sm border border-blue-400/30 hover:border-blue-400/50 py-4 px-6 rounded-2xl font-semibold transition-all text-blue-300 hover:text-blue-200 cursor-pointer"
              >
                🚀 Start Tracking Now
              </button>

              <p className="text-white/50 text-sm">
                No signup required • Works offline • 100% private
              </p>
            </div>
          </div>
        </section>

        {/* Input Methods Section */}
        <section className="max-w-md mx-auto px-6 py-8">
          <div className="text-center mb-8">
            <h3 className="text-2xl font-bold mb-2 text-white">Four Powerful Ways to Track</h3>
            <p className="text-white/70">Choose the method that works best for you</p>
          </div>

          <div className="space-y-4">
            {/* Voice Input */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center">
                  <MicrophoneIconComponent size="lg" className="text-green-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Voice Input</h4>
                  <p className="text-white/70 text-sm">Just say what you ate</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                &ldquo;I had a chicken caesar salad&rdquo; - our AI understands natural language
                and calculates nutrition instantly.
              </p>
            </div>

            {/* Photo Recognition */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center">
                  <CameraIconComponent size="lg" className="text-orange-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Photo Recognition</h4>
                  <p className="text-white/70 text-sm">Snap a photo, get nutrition</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Take a photo of your meal and let AI vision technology identify foods and estimate portions.
              </p>
            </div>

            {/* Barcode Scanning */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
                  <BarcodeIconComponent size="lg" className="text-blue-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Barcode Scanning</h4>
                  <p className="text-white/70 text-sm">Instant product recognition</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Scan any product barcode for instant nutrition data with accurate serving sizes.
              </p>
            </div>

            {/* Text Input */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-purple-500/20 rounded-xl flex items-center justify-center">
                  <PencilIconComponent size="lg" className="text-purple-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Text Input</h4>
                  <p className="text-white/70 text-sm">Type food descriptions</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Type what you ate and get instant nutrition estimates. Perfect for quick logging.
              </p>
            </div>
          </div>
        </section>

        {/* Core Features Section */}
        <section className="max-w-md mx-auto px-6 py-8">
          <div className="text-center mb-8">
            <h3 className="text-2xl font-bold mb-2 text-white">Complete Nutrition Tracking</h3>
            <p className="text-white/70">Everything you need to reach your health goals</p>
          </div>

          <div className="space-y-4">
            {/* Macro Tracking */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-emerald-500/20 rounded-xl flex items-center justify-center">
                  <ChartIconComponent size="lg" className="text-emerald-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Complete Macros</h4>
                  <p className="text-white/70 text-sm">Calories, fat, carbs & protein</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Track all macronutrients with beautiful tabbed interface and progress visualization.
              </p>
            </div>

            {/* Analytics & History */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
                  <ChartIconComponent size="lg" className="text-blue-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Beautiful Analytics</h4>
                  <p className="text-white/70 text-sm">Interactive charts & history</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Interactive charts, trend analysis, and detailed history with 7, 30, and 90-day views.
              </p>
            </div>

            {/* Settings & Customization */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-purple-500/20 rounded-xl flex items-center justify-center">
                  <SettingsIconComponent size="lg" className="text-purple-400" />
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Fully Customizable</h4>
                  <p className="text-white/70 text-sm">Personal goals & preferences</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Set personal goals, choose metric or imperial units, and reset to defaults anytime.
              </p>
            </div>

            {/* PWA Features */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center">
                  <span className="text-xl">⚡</span>
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Lightning Fast</h4>
                  <p className="text-white/70 text-sm">Works offline & installs like native</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                Progressive Web App that works offline and installs on any device.
              </p>
            </div>

            {/* Privacy & Security */}
            <div className="card-glass card-glass-hover rounded-2xl p-6 transition-theme">
              <div className="flex items-center space-x-4 mb-4">
                <div className="w-12 h-12 bg-teal-500/20 rounded-xl flex items-center justify-center">
                  <span className="text-xl">🔒</span>
                </div>
                <div>
                  <h4 className="text-lg font-bold text-white">Privacy First</h4>
                  <p className="text-white/70 text-sm">Your data stays on your device</p>
                </div>
              </div>
              <p className="text-white/60 text-sm">
                No accounts required, no data collection, complete privacy and control.
              </p>
            </div>
          </div>
        </section>

        {/* Beautiful Design Section */}
        <section className="max-w-md mx-auto px-6 py-8">
          <div className="card-glass rounded-2xl p-6 transition-theme text-center">
            <div className="mb-6">
              <span className="text-2xl mb-3 block">✨</span>
              <h3 className="text-lg font-bold text-white mb-2">Beautiful Design</h3>
              <p className="text-white/70 text-sm">
                Crafted with Apple-inspired design principles for an elegant, intuitive experience.
              </p>
            </div>

            {/* Screenshot Carousel */}
            <div className="relative mb-4">
              <div
                ref={carouselRef}
                className="overflow-hidden rounded-xl bg-black/20"
              >
                <div
                  className="flex transition-transform duration-500 ease-in-out"
                  style={{ transform: `translateX(-${currentSlide * 100}%)` }}
                >
                  {screenshots.map((screenshot, index) => (
                    <div key={index} className="w-full flex-shrink-0">
                      <img
                        src={screenshot.src}
                        alt={screenshot.alt}
                        className="w-full h-auto object-contain"
                      />
                    </div>
                  ))}
                </div>
              </div>

              {/* Dot Indicators - made much more visible */}
              <div className="flex justify-center space-x-4 mt-6 mb-2">
                {screenshots.map((_, index) => (
                  <button
                    key={index}
                    onClick={() => goToSlide(index)}
                    className={`w-4 h-4 rounded-full transition-all duration-200 border-2 ${
                      index === currentSlide
                        ? 'bg-blue-400 border-blue-400 scale-110 shadow-lg shadow-blue-400/50'
                        : 'bg-white border-white/80 hover:bg-blue-200 hover:border-blue-200'
                    }`}
                    aria-label={`Go to screenshot ${index + 1}`}
                  />
                ))}
              </div>
            </div>

            <div className="text-xs text-white/50">
              Swipe through to see the app in action
            </div>
          </div>
        </section>

        {/* App Store Availability */}
        <section className="max-w-md mx-auto px-6 py-8">
          <div className="card-glass rounded-2xl p-6 transition-theme text-center">
            <div className="mb-4">
              <span className="text-2xl mb-3 block">📱</span>
              <h3 className="text-lg font-bold text-white mb-2">Coming Soon to App Stores</h3>
              <p className="text-white/70 text-sm mb-4">
                This app will be available on Google Play Store and Apple App Store soon.
              </p>
            </div>

            <div className="bg-blue-500/10 border border-blue-400/20 rounded-xl p-4 mb-4">
              <p className="text-blue-300 text-sm font-medium mb-2">
                🎉 Early Access Available Now
              </p>
              <p className="text-white/70 text-xs">
                For now, this app is exclusively available to subscribers of{' '}
                <a
                  href="https://x.com/AIandDesign"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-400 hover:text-blue-300 transition-colors font-medium"
                >
                  @AIandDesign
                </a>
                {' '}on X (Twitter).
              </p>
            </div>

            <div className="text-xs text-white/50">
              Subscribe to get notified when the app launches publicly!
            </div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="max-w-md mx-auto px-6 py-12 mb-8 text-center">
          <div className="card-glass rounded-2xl p-8 transition-theme">
            <h3 className="text-2xl font-bold mb-4 text-white">
              Ready to Transform Your Nutrition?
            </h3>
            <p className="text-white/70 mb-8">
              Join thousands of users who have simplified their nutrition tracking.
            </p>

            <button
              onClick={() => setShowLogin(true)}
              className="block w-full bg-blue-500/20 hover:bg-blue-500/30 backdrop-blur-sm border border-blue-400/30 hover:border-blue-400/50 py-4 px-6 rounded-2xl font-semibold transition-all text-blue-300 hover:text-blue-200 mb-6 cursor-pointer"
            >
              🚀 Start Your Journey
            </button>

            <div className="flex justify-center items-center space-x-4 text-xs text-white/50">
              <div className="flex items-center space-x-2">
                <span className="text-green-400">✓</span>
                <span>No signup</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-green-400">✓</span>
                <span>Works offline</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className="text-green-400">✓</span>
                <span>100% private</span>
              </div>
            </div>
          </div>
        </section>

        {/* Footer */}
        <footer className="border-t border-white/10 py-8">
          <div className="max-w-md mx-auto px-6">
            <div className="text-center">
              <div className="flex items-center justify-center space-x-3 mb-4">
                <img
                  src="/icons/icon-192.png"
                  alt="Calorie Counter"
                  className="w-6 h-6"
                />
                <span className="text-lg font-bold text-white">Calorie Counter</span>
              </div>

              <div className="text-xs text-white/60 space-y-2">
                <div>
                  Copyright 2025 © Marco van Hylckama Vlieg
                </div>
                <div className="flex items-center justify-center space-x-4">
                  <a
                    href="https://github.com/TheMarco/caloriecounter"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-400 hover:text-blue-300 transition-colors"
                  >
                    Open Source
                  </a>
                  <span className="text-white/30">•</span>
                  <button
                    onClick={handleLicenseClick}
                    className="text-blue-400 hover:text-blue-300 transition-colors cursor-pointer"
                  >
                    License
                  </button>
                  <span className="text-white/30">•</span>
                  <a
                    href="https://x.com/AIandDesign"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-400 hover:text-blue-300 transition-colors"
                  >
                    Follow me on X
                  </a>
                </div>
              </div>
            </div>
          </div>
        </footer>

        {/* Login Modal */}
        {showLogin && (
          <LoginForm onSuccess={handleLoginSuccess} />
        )}

        {/* License Modal */}
        {showLicense && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
            <div className="card-glass rounded-2xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
              <div className="flex items-center justify-between p-6 border-b border-white/10">
                <h3 className="text-xl font-bold text-white">License</h3>
                <button
                  onClick={() => setShowLicense(false)}
                  className="p-2 hover:bg-white/10 rounded-xl transition-colors"
                >
                  <CloseIconComponent className="text-white/70" />
                </button>
              </div>
              <div className="p-6 overflow-y-auto max-h-[60vh]">
                <pre className="text-white/80 text-sm whitespace-pre-wrap font-mono leading-relaxed">
                  {licenseContent}
                </pre>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
