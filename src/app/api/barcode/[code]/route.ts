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
          console.log('📦 OpenFoodFacts product name:', productName);
        }
      }
    } catch {
      console.log('OpenFoodFacts lookup failed, using OpenAI with barcode only');
    }

    console.log('🔍 Barcode:', code, 'Product:', productName);

    // Use OpenAI to get accurate nutritional information
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    const prompt = `You are a nutrition expert. I scanned a barcode (${code}) for the product: "${productName}".

Analyze this product and provide nutritional information for a sensible serving size.

Respond with ONLY a JSON object in this exact format:
{
  "food": "Product name",
  "kcal": number (calories per serving),
  "unit": "ml" or "g",
  "serving_size": number (typical serving size)
}

SYSTEMATIC APPROACH:
1. Identify the product category (beverage, condiment, snack, etc.)
2. Determine a realistic single serving size for that category
3. Calculate calories based on typical calorie density for that product type

SERVING SIZE LOGIC:
- Beverages: Use the actual container size if it's a single-serve container (bottle, can), otherwise use a standard glass/cup serving
- Condiments/sauces: 1 tablespoon (15g)
- Spreads (peanut butter, jam): 2 tablespoons (30g)
- Snacks: Individual package or handful portion
- Prepared foods: Realistic meal portion

CALORIE DENSITY SANITY CHECK:
- Beverages: 30-60 kcal per 100ml (beer ~40, soda ~42, juice ~45)
- Oils/fats: 800-900 kcal per 100g
- Nuts: 500-600 kcal per 100g
- Bread: 250-300 kcal per 100g
- Fruits: 40-80 kcal per 100g
- Vegetables: 15-50 kcal per 100g

CRITICAL EXAMPLES:
- Dos Equis beer 355ml bottle = 142 calories (40 kcal per 100ml)
- Coca Cola 355ml can = 150 calories (42 kcal per 100ml)
- Wine 150ml glass = 120 calories (80 kcal per 100ml)
- Olive oil 15ml (1 tbsp) = 135 calories (900 kcal per 100ml)

NEVER give results like 533 calories for 355ml beer - that's physically impossible!`;

    console.log('🤖 Sending prompt to OpenAI:', prompt);

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

    console.log('OpenAI barcode response:', responseText);

    let nutritionData;
    try {
      nutritionData = JSON.parse(responseText);
    } catch {
      throw new Error('Invalid response format from OpenAI');
    }

    console.log('Parsed nutrition data:', nutritionData);

    // Validate the response structure
    if (!nutritionData.food || !nutritionData.kcal || !nutritionData.unit || !nutritionData.serving_size) {
      throw new Error('Incomplete nutritional data from OpenAI');
    }

    const finalResult = {
      food: nutritionData.food,
      kcal: Math.round(nutritionData.kcal),
      unit: nutritionData.unit,
      serving_size: Math.round(nutritionData.serving_size),
    };

    console.log('📊 Final barcode result:', finalResult);

    return NextResponse.json<BarcodeResponse>({
      success: true,
      data: finalResult,
    });

  } catch (error) {
    console.error('Barcode lookup error:', error);
    
    return NextResponse.json<BarcodeResponse>({
      success: false,
      error: 'Failed to lookup barcode',
    }, { status: 500 });
  }
}
