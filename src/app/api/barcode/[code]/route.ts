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

      // Get reasonable serving size
      const productName = (product.product_name || product.product_name_en || '').toLowerCase();
      const categories = (product.categories || '').toLowerCase();

      // Extract package size info
      const packageQuantity = product.quantity || '';
      const servingSizeRaw = product.serving_size || product.serving_quantity;

      let servingSize = 100; // Default fallback
      let unit = 'g';

      // Smart serving size detection based on product type
      if (categories.includes('beverages') || categories.includes('drinks') ||
          productName.includes('drink') || productName.includes('soda') ||
          productName.includes('juice') || productName.includes('water') ||
          productName.includes('cola') || productName.includes('coke')) {

        // For beverages, try to detect can/bottle size
        unit = 'ml';

        if (packageQuantity.includes('330') || packageQuantity.includes('33cl')) {
          servingSize = 330; // Standard can
        } else if (packageQuantity.includes('250') || packageQuantity.includes('25cl')) {
          servingSize = 250; // Small can/bottle
        } else if (packageQuantity.includes('500') || packageQuantity.includes('50cl')) {
          servingSize = 500; // Standard bottle
        } else if (packageQuantity.includes('1.5') || packageQuantity.includes('1,5')) {
          servingSize = 250; // Serving from large bottle
        } else if (packageQuantity.includes('2l') || packageQuantity.includes('2L')) {
          servingSize = 250; // Serving from large bottle
        } else {
          // Try to parse serving size, default to 250ml for beverages
          if (servingSizeRaw) {
            const parsed = typeof servingSizeRaw === 'string' ?
              parseFloat(servingSizeRaw.replace(/[^\d.]/g, '')) : servingSizeRaw;
            servingSize = parsed && parsed > 0 && parsed <= 1000 ? parsed : 250;
          } else {
            servingSize = 250; // Default beverage serving
          }
        }

      } else {
        // For food items, use serving size if reasonable, otherwise default
        unit = 'g';

        if (servingSizeRaw) {
          const parsed = typeof servingSizeRaw === 'string' ?
            parseFloat(servingSizeRaw.replace(/[^\d.]/g, '')) : servingSizeRaw;

          // Use serving size if it's reasonable (between 10g and 500g)
          if (parsed && parsed >= 10 && parsed <= 500) {
            servingSize = parsed;
          } else if (parsed && parsed > 500) {
            // If serving size is too large, use a reasonable portion
            servingSize = Math.min(parsed / 4, 150); // Quarter of package or 150g max
          } else {
            servingSize = 100; // Default food serving
          }
        }
      }

      return NextResponse.json<BarcodeResponse>({
        success: true,
        data: {
          food: product.product_name || product.product_name_en || 'Unknown Product',
          kcal: Math.round(energyKcal),
          unit,
          serving_size: Math.round(servingSize),
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
