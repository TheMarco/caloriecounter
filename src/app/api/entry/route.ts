// Entry management API route
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { createId } from '@paralleldrive/cuid2';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { dt, food, qty, unit, kcal, method, confidence } = body;

    // Validate required fields
    if (!dt || !food || !qty || !unit || !kcal || !method) {
      return NextResponse.json({
        success: false,
        error: 'Missing required fields',
      }, { status: 400 });
    }

    // For now, we'll use a default user ID since auth is not implemented
    // In production, this would come from the authenticated session
    const defaultUserId = 'default-user';

    // Create entry in database
    const entry = await prisma.entry.create({
      data: {
        id: createId(),
        dt: dt,
        ts: BigInt(Date.now()),
        food: food,
        qty: parseFloat(qty),
        unit: unit,
        kcal: parseInt(kcal),
        method: method,
        confidence: confidence ? parseFloat(confidence) : null,
        userId: defaultUserId,
      },
    });

    return NextResponse.json({
      success: true,
      id: entry.id,
    });

  } catch (error) {
    console.error('Entry creation error:', error);
    
    return NextResponse.json({
      success: false,
      error: 'Failed to save entry',
    }, { status: 500 });
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const date = searchParams.get('date');
    const limit = searchParams.get('limit');

    // For now, we'll use a default user ID since auth is not implemented
    const defaultUserId = 'default-user';

    const whereClause: { userId: string; dt?: string } = {
      userId: defaultUserId,
    };

    if (date) {
      whereClause.dt = date;
    }

    const entries = await prisma.entry.findMany({
      where: whereClause,
      orderBy: {
        createdAt: 'desc',
      },
      take: limit ? parseInt(limit) : undefined,
    });

    // Convert BigInt to number for JSON serialization
    const serializedEntries = entries.map(entry => ({
      ...entry,
      ts: Number(entry.ts),
    }));

    return NextResponse.json({
      success: true,
      data: serializedEntries,
    });

  } catch (error) {
    console.error('Entry fetch error:', error);
    
    return NextResponse.json({
      success: false,
      error: 'Failed to fetch entries',
    }, { status: 500 });
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    if (!id) {
      return NextResponse.json({
        success: false,
        error: 'Entry ID is required',
      }, { status: 400 });
    }

    // For now, we'll use a default user ID since auth is not implemented
    const defaultUserId = 'default-user';

    // Delete entry (with user ownership check)
    const deletedEntry = await prisma.entry.deleteMany({
      where: {
        id: id,
        userId: defaultUserId,
      },
    });

    if (deletedEntry.count === 0) {
      return NextResponse.json({
        success: false,
        error: 'Entry not found or access denied',
      }, { status: 404 });
    }

    return NextResponse.json({
      success: true,
    });

  } catch (error) {
    console.error('Entry deletion error:', error);
    
    return NextResponse.json({
      success: false,
      error: 'Failed to delete entry',
    }, { status: 500 });
  }
}
