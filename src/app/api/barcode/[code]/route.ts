// Barcode lookup API route
import { NextRequest, NextResponse } from 'next/server';
import type { BarcodeResponse } from '@/types';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ code: string }> }
) {
  try {
    const { code } = await params;

    // Validate barcode format (basic validation)
    if (!code || code.length < 8 || code.length > 14) {
      return NextResponse.json<BarcodeResponse>({
        success: false,
        error: 'Invalid barcode format',
      }, { status: 400 });
    }

    // Try OpenFoodFacts API first
    const openFoodFactsUrl = `https://world.openfoodfacts.org/api/v0/product/${code}.json`;
    
    const response = await fetch(openFoodFactsUrl, {
      headers: {
        'User-Agent': 'CalorieCounter/1.0 (https://caloriecounter.app)',
      },
    });

    if (!response.ok) {
      throw new Error('OpenFoodFacts API error');
    }

    const data = await response.json();

    if (data.status === 1 && data.product) {
      const product = data.product;
      
      // Extract nutritional information
      const nutriments = product.nutriments || {};
      const energyKcal = nutriments['energy-kcal_100g'] || 
                        nutriments['energy-kcal'] || 
                        (nutriments['energy_100g'] ? Math.round(nutriments['energy_100g'] / 4.184) : null);

      if (!energyKcal) {
        return NextResponse.json<BarcodeResponse>({
          success: false,
          error: 'No calorie information available for this product',
        }, { status: 404 });
      }

      // Get serving size
      const servingSize = product.serving_size || 
                         product.serving_quantity || 
                         100; // Default to 100g

      return NextResponse.json<BarcodeResponse>({
        success: true,
        data: {
          food: product.product_name || product.product_name_en || 'Unknown Product',
          kcal: Math.round(energyKcal),
          unit: 'g',
          serving_size: typeof servingSize === 'string' ? 
            parseFloat(servingSize.replace(/[^\d.]/g, '')) || 100 : 
            servingSize,
        },
      });
    }

    // If OpenFoodFacts doesn't have the product, return not found
    return NextResponse.json<BarcodeResponse>({
      success: false,
      error: 'Product not found in database',
    }, { status: 404 });

  } catch (error) {
    console.error('Barcode lookup error:', error);
    
    return NextResponse.json<BarcodeResponse>({
      success: false,
      error: 'Failed to lookup barcode',
    }, { status: 500 });
  }
}
