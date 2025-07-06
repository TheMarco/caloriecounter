// Statistics API route
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import type { StatsResponse, DateRange } from '@/types';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const range = searchParams.get('range') as DateRange || '7d';

    // For now, we'll use a default user ID since auth is not implemented
    const defaultUserId = 'default-user';

    // Calculate date range
    const endDate = new Date();
    const startDate = new Date();
    
    switch (range) {
      case '7d':
        startDate.setDate(endDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(endDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(endDate.getDate() - 90);
        break;
      default:
        startDate.setDate(endDate.getDate() - 7);
    }

    const startDateStr = startDate.toISOString().slice(0, 10);
    const endDateStr = endDate.toISOString().slice(0, 10);

    // Get entries in date range
    const entries = await prisma.entry.findMany({
      where: {
        userId: defaultUserId,
        dt: {
          gte: startDateStr,
          lte: endDateStr,
        },
      },
      select: {
        dt: true,
        kcal: true,
      },
    });

    // Group by date and sum calories
    const dailyTotals = new Map<string, number>();
    
    // Initialize all dates in range with 0
    for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().slice(0, 10);
      dailyTotals.set(dateStr, 0);
    }

    // Sum calories by date
    entries.forEach(entry => {
      const current = dailyTotals.get(entry.dt) || 0;
      dailyTotals.set(entry.dt, current + entry.kcal);
    });

    // Convert to array format
    const daily = Array.from(dailyTotals.entries())
      .map(([date, total_kcal]) => ({ date, total_kcal }))
      .sort((a, b) => a.date.localeCompare(b.date));

    // Calculate averages
    const totalCalories = daily.reduce((sum, day) => sum + day.total_kcal, 0);
    const daysWithData = daily.filter(day => day.total_kcal > 0).length;
    
    const weeklyAvg = daysWithData > 0 ? Math.round(totalCalories / Math.min(7, daily.length)) : 0;
    const monthlyAvg = daysWithData > 0 ? Math.round(totalCalories / Math.min(30, daily.length)) : 0;

    return NextResponse.json<StatsResponse>({
      success: true,
      data: {
        daily,
        weekly_avg: weeklyAvg,
        monthly_avg: monthlyAvg,
      },
    });

  } catch (error) {
    console.error('Stats fetch error:', error);
    
    return NextResponse.json<StatsResponse>({
      success: false,
      error: 'Failed to fetch statistics',
    }, { status: 500 });
  }
}
