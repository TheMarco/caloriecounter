import '@testing-library/jest-dom'
import { TextEncoder, TextDecoder } from 'util'

// Mock TextEncoder/TextDecoder for Node.js environment
global.TextEncoder = TextEncoder
global.TextDecoder = TextDecoder

// Mock structuredClone for Node.js environment
global.structuredClone = (obj) => JSON.parse(JSON.stringify(obj))

// Mock React 19 compatibility
Object.defineProperty(global, 'IS_REACT_ACT_ENVIRONMENT', {
  writable: true,
  value: true,
})

// Mock React DOM for compatibility
Object.defineProperty(window, 'React', {
  value: require('react'),
  writable: true,
})

// Mock process.env for React
process.env.NODE_ENV = 'test'

// Mock IndexedDB
const FDBFactory = require('fake-indexeddb/lib/FDBFactory')
const FDBKeyRange = require('fake-indexeddb/lib/FDBKeyRange')

global.indexedDB = new FDBFactory()
global.IDBKeyRange = FDBKeyRange

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
}
global.localStorage = localStorageMock

// Mock sessionStorage
const sessionStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
}
global.sessionStorage = sessionStorageMock

// Mock navigator
Object.defineProperty(window, 'navigator', {
  value: {
    onLine: true,
    mediaDevices: {
      getUserMedia: jest.fn(),
    },
  },
  writable: true,
})

// Mock matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(), // deprecated
    removeListener: jest.fn(), // deprecated
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
})
