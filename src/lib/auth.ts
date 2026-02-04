import { createHmac, timingSafeEqual } from 'crypto';

const AUTH_SECRET = process.env.NEXTAUTH_SECRET || process.env.AUTH_SECRET || 'default-dev-secret-change-me';
const TOKEN_EXPIRY_HOURS = 24;

/**
 * Creates a signed authentication token that cannot be forged
 * Format: timestamp.signature
 */
export function createAuthToken(): string {
  const timestamp = Date.now().toString();
  const signature = createHmac('sha256', AUTH_SECRET)
    .update(timestamp)
    .digest('hex');
  return `${timestamp}.${signature}`;
}

/**
 * Verifies an authentication token
 * Returns true if the token is valid and not expired
 */
export function verifyAuthToken(token: string): boolean {
  if (!token || typeof token !== 'string') {
    return false;
  }

  const parts = token.split('.');
  if (parts.length !== 2) {
    return false;
  }

  const [timestamp, providedSignature] = parts;

  // Check if timestamp is valid
  const tokenTime = parseInt(timestamp, 10);
  if (isNaN(tokenTime)) {
    return false;
  }

  // Check expiration
  const expiryMs = TOKEN_EXPIRY_HOURS * 60 * 60 * 1000;
  if (Date.now() - tokenTime > expiryMs) {
    return false;
  }

  // Verify signature using timing-safe comparison
  const expectedSignature = createHmac('sha256', AUTH_SECRET)
    .update(timestamp)
    .digest('hex');

  try {
    const providedBuffer = Buffer.from(providedSignature, 'hex');
    const expectedBuffer = Buffer.from(expectedSignature, 'hex');

    if (providedBuffer.length !== expectedBuffer.length) {
      return false;
    }

    return timingSafeEqual(providedBuffer, expectedBuffer);
  } catch {
    return false;
  }
}

/**
 * Verifies the password against the environment variable
 */
export function verifyPassword(password: string): boolean {
  const correctPassword = process.env.AUTH_PASSWORD;

  if (!correctPassword) {
    console.warn('AUTH_PASSWORD not set in environment variables');
    return false;
  }

  // Use timing-safe comparison to prevent timing attacks
  try {
    const providedBuffer = Buffer.from(password);
    const expectedBuffer = Buffer.from(correctPassword);

    if (providedBuffer.length !== expectedBuffer.length) {
      return false;
    }

    return timingSafeEqual(providedBuffer, expectedBuffer);
  } catch {
    return false;
  }
}
