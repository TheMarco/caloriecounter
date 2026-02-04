import { NextRequest, NextResponse } from 'next/server';
import { verifyAuthToken } from '@/lib/auth';

export async function GET(request: NextRequest) {
  const authCookie = request.cookies.get('calorie-auth');
  const isAuthenticated = authCookie?.value ? verifyAuthToken(authCookie.value) : false;

  return NextResponse.json({
    authenticated: isAuthenticated,
  });
}
