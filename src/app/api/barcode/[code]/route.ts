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

    // Check for OpenAI API key
    if (!process.env.OPENAI_API_KEY) {
      console.warn('OPENAI_API_KEY not configured');

      // If we have a product name from OpenFoodFacts, return basic info
      if (productName !== 'Unknown Product') {
        return NextResponse.json<BarcodeResponse>({
          success: true,
          data: {
            food: productName,
            kcal: 0,
            fat: 0,
            carbs: 0,
            protein: 0,
            unit: 'g',
            serving_size: 100,
          },
        });
      }

      // No API key and no product name - return service unavailable
      return NextResponse.json<BarcodeResponse>({
        success: false,
        error: 'Nutrition lookup service unavailable. Please configure OPENAI_API_KEY.',
      }, { status: 503 });
    }

    // Use OpenAI to get accurate nutritional information
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    const prompt = `You are a nutrition expert. I scanned a barcode (${code}) for a product.

${productName !== 'Unknown Product' ? `The product appears to be: "${productName}"` : 'The product name could not be determined from the barcode database.'}

Your task: Identify this product and provide accurate nutritional information for a realistic serving size.

IMPORTANT: Use your knowledge of common products and their barcodes. If the provided product name seems incomplete or unclear, use the barcode number and your knowledge to identify the actual product.

Respond with ONLY a JSON object in this exact format:
{
  "food": "Complete product name (brand + product + flavor/variant)",
  "kcal": number (calories per serving),
  "fat": number (grams of fat per serving),
  "carbs": number (grams of carbohydrates per serving),
  "protein": number (grams of protein per serving),
  "unit": "ml" or "g",
  "serving_size": number (typical serving size)
}

SYSTEMATIC APPROACH:
1. Identify the product category and brand
2. Use known nutritional profiles for common branded products
3. Determine realistic serving size for that product type
4. Calculate accurate macronutrients based on typical formulations

SPECIFIC PRODUCT KNOWLEDGE:
- Premier Protein shakes (11oz/325ml): ~160 calories, 30g protein, 1g fat, 4g carbs
- Muscle Milk (14oz): ~230 calories, 25g protein, 9g fat, 12g carbs
- Ensure/Boost nutritional drinks: ~220-250 calories, 9-13g protein
- Protein bars: typically 180-300 calories, 15-30g protein
- Greek yogurt cups: ~100-150 calories, 15-20g protein
- Regular soda (12oz): ~140-150 calories, 0g protein, 35-40g carbs
- Diet soda: ~0-5 calories
- Energy drinks (8.4oz Red Bull): ~110 calories, 1g protein, 27g carbs

SERVING SIZE LOGIC:
- Protein shakes/drinks: Use full container size (typically 11-14oz)
- Regular beverages: Use actual container size if single-serve (bottle, can)
- Condiments/sauces: 1 tablespoon (15g)
- Spreads (peanut butter, jam): 2 tablespoons (30g)
- Protein bars: Whole bar (typically 40-60g)
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

    // Try multiple models in order of preference (GPT-5 mini first)
    const models = ['gpt-5-mini', 'gpt-4o-mini', 'gpt-4o', 'gpt-4-turbo', 'gpt-3.5-turbo'];
    let completion;
    let lastError;

    for (const model of models) {
      try {
        console.log(`🤖 Attempting to use model: ${model}`);
        completion = await openai.chat.completions.create({
          model,
          messages: [
            {
              role: "system",
              content: "You are a nutrition expert. Respond only with valid JSON for barcode product analysis."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.1,
          max_tokens: 200,
        });
        console.log(`✅ Successfully used model: ${model}`);
        break; // Success, exit loop
      } catch (error) {
        console.error(`❌ Model ${model} failed:`, error);
        lastError = error;
        // Continue to next model
      }
    }

    if (!completion) {
      console.error('All models failed, last error:', lastError);
      throw lastError || new Error('All models failed');
    }

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      throw new Error('No response from OpenAI');
    }

    console.log('OpenAI barcode response:', responseText);

    let nutritionData;
    try {
      // Clean the response text to remove markdown formatting (like text input flow)
      let cleanedResponse = responseText;
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.replace(/```json\s*/, '').replace(/\s*```$/, '');
      }
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.replace(/```\s*/, '').replace(/\s*```$/, '');
      }

      nutritionData = JSON.parse(cleanedResponse);
    } catch (parseError) {
      console.error('Failed to parse OpenAI barcode response:', parseError);
      console.error('Raw response:', responseText);
      throw new Error('Invalid response format from OpenAI');
    }

    console.log('Parsed nutrition data:', nutritionData);

    // Validate the response structure (more flexible like text input)
    if (!nutritionData.food || !nutritionData.unit || !nutritionData.serving_size) {
      console.error('Missing required fields in OpenAI response:', nutritionData);
      throw new Error('Incomplete nutritional data from OpenAI');
    }

    const finalResult = {
      food: nutritionData.food,
      kcal: nutritionData.kcal ? Math.round(Number(nutritionData.kcal)) : 0,
      fat: nutritionData.fat ? Math.round(Number(nutritionData.fat) * 10) / 10 : 0, // Round to 1 decimal place
      carbs: nutritionData.carbs ? Math.round(Number(nutritionData.carbs) * 10) / 10 : 0,
      protein: nutritionData.protein ? Math.round(Number(nutritionData.protein) * 10) / 10 : 0,
      unit: nutritionData.unit,
      serving_size: Math.round(Number(nutritionData.serving_size)),
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
