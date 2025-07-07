// Barcode lookup API route
import { NextRequest, NextResponse } from 'next/server';
import type { BarcodeResponse } from '@/types';
import OpenAI from 'openai';

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

    // First try to get product name from OpenFoodFacts
    let productName = 'Unknown Product';

    try {
      const openFoodFactsUrl = `https://world.openfoodfacts.org/api/v0/product/${code}.json`;
      const response = await fetch(openFoodFactsUrl, {
        headers: {
          'User-Agent': 'CalorieCounter/1.0 (https://caloriecounter.app)',
        },
      });

      if (response.ok) {
        const data = await response.json();
        if (data.status === 1 && data.product) {
          productName = data.product.product_name ||
                      data.product.product_name_en ||
                      data.product.brands ||
                      'Unknown Product';
        }
      }
    } catch {
      console.log('OpenFoodFacts lookup failed, using OpenAI with barcode only');
    }

    // Use OpenAI to get accurate nutritional information
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    const prompt = `You are a nutrition expert. I scanned a barcode (${code}) for the product: "${productName}".

Please provide accurate nutritional information for this product with a typical serving size.

Respond with ONLY a JSON object in this exact format:
{
  "food": "Product name",
  "kcal": number (calories per serving),
  "unit": "g" or "ml",
  "serving_size": number (typical serving size)
}

For serving sizes, use realistic portions:
- Condiments (mayo, ketchup): 1 tablespoon (15g)
- Beverages: standard can/bottle size (330ml can, 250ml glass)
- Snacks: single serving portion
- Main foods: typical meal portion

Make sure the calories match the serving size (not per 100g).`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.1,
      max_tokens: 200,
    });

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      throw new Error('No response from OpenAI');
    }

    let nutritionData;
    try {
      nutritionData = JSON.parse(responseText);
    } catch {
      throw new Error('Invalid response format from OpenAI');
    }

    // Validate the response structure
    if (!nutritionData.food || !nutritionData.kcal || !nutritionData.unit || !nutritionData.serving_size) {
      throw new Error('Incomplete nutritional data from OpenAI');
    }

    return NextResponse.json<BarcodeResponse>({
      success: true,
      data: {
        food: nutritionData.food,
        kcal: Math.round(nutritionData.kcal),
        unit: nutritionData.unit,
        serving_size: Math.round(nutritionData.serving_size),
      },
    });

  } catch (error) {
    console.error('Barcode lookup error:', error);
    
    return NextResponse.json<BarcodeResponse>({
      success: false,
      error: 'Failed to lookup barcode',
    }, { status: 500 });
  }
}
