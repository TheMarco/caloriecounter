// Food parsing API route using OpenAI
import { NextRequest, NextResponse } from 'next/server';
import OpenAI from 'openai';
import type { ParseFoodResponse } from '@/types';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(request: NextRequest) {
  try {
    const { text, units = 'metric' } = await request.json();

    if (!text || typeof text !== 'string' || text.trim().length < 2) {
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Invalid food description',
      }, { status: 400 });
    }

    if (!process.env.OPENAI_API_KEY) {
      // Fallback parsing without OpenAI
      return fallbackParsing(text, units);
    }

    const unitsInstruction = units === 'metric'
      ? 'Use metric units when possible (grams, ml, liters). For liquids like shots, use ml (e.g., 44ml for a shot of tequila).'
      : 'Use imperial units when appropriate (oz, lb, cups, tbsp, tsp). For liquids like shots, use oz (e.g., 1.5oz for a shot of tequila).';

    const prompt = `You are a nutrition expert. Parse this food description and provide accurate nutritional information:

"${text}"

IMPORTANT: The user prefers ${units} units. ${unitsInstruction}

Respond with this exact JSON structure:
{
  "food": "standardized food name",
  "quantity": number,
  "unit": "g|ml|cup|tbsp|tsp|piece|slice|oz|lb|bowl|plate|serving",
  "kcal": total_calories_for_this_serving,
  "fat": total_fat_grams_for_this_serving,
  "carbs": total_carbs_grams_for_this_serving,
  "protein": total_protein_grams_for_this_serving,
  "notes": "any_additional_info"
}

CRITICAL PORTION SIZE RULES:
- NEVER use unrealistic tiny portions (like 1g for a plate of food)
- For pasta dishes: "plate/bowl of pasta" = 300-400g cooked pasta + sauce
- For rice dishes: "plate/bowl of rice" = 200-300g cooked rice + toppings
- For salads: "bowl/plate of salad" = 150-250g depending on ingredients
- For sandwiches/burgers: use "piece" unit, estimate total weight 150-300g
- For pizza: use "slice" unit, typical slice = 100-150g
- For soups: use "bowl" unit, typical serving = 250-300ml
- For meat portions: restaurant serving = 150-200g, home serving = 100-150g

IMPORTANT RULES:
- For compound foods (like "chili dog with cheese"), calculate the TOTAL calories for the complete item
- Use realistic portion sizes based on how food is typically served
- The "kcal" field should be the TOTAL calories for the quantity specified, NOT per 100g
- For complex dishes, consider ALL ingredients and typical serving sizes
- Be generous with calorie estimates for restaurant/prepared foods
- Use appropriate units based on user preference: ${units === 'metric' ? 'prefer grams for solids, ml for liquids' : 'use oz, lb, cups, tbsp, tsp as appropriate'}

REALISTIC PORTION EXAMPLES:
  * "plate of fettuccine alfredo" → quantity: 350, unit: "g", kcal: 800 (typical restaurant portion)
  * "bowl of chicken fried rice" → quantity: 300, unit: "g", kcal: 520 (typical serving)
  * "chili dog with cheese" → quantity: 1, unit: "piece", kcal: 550 (total for whole item)
  * "Big Mac" → quantity: 1, unit: "piece", kcal: 563 (total for whole burger)
  * "slice of pepperoni pizza" → quantity: 1, unit: "slice", kcal: 298 (total for slice)
  * "bowl of tomato soup" → quantity: 1, unit: "bowl", kcal: 180 (typical 250ml serving)
  * "2 eggs" → quantity: 2, unit: "piece", kcal: 140 (total for both eggs)
  * "100g chicken breast" → quantity: 100, unit: "g", kcal: 165 (total for 100g)
  * "tablespoon of mayo" → quantity: 1, unit: "tbsp", kcal: 90 (total for 1 tbsp)
  * "shot of tequila" → ${units === 'metric' ? 'quantity: 44, unit: "ml", kcal: 97' : 'quantity: 1.5, unit: "oz", kcal: 97'} (standard shot size)`;

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
              role: 'system',
              content: 'You are a nutrition expert. Respond only with valid JSON.',
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
          max_tokens: 150,
          temperature: 0.1,
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

    try {
      // Clean the response text to remove markdown formatting
      let cleanedResponse = responseText;
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.replace(/```json\s*/, '').replace(/\s*```$/, '');
      }
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.replace(/```\s*/, '').replace(/\s*```$/, '');
      }

      const parsed = JSON.parse(cleanedResponse);

      // Validate the parsed response
      if (!parsed.food || !parsed.quantity || !parsed.unit) {
        throw new Error('Invalid response format');
      }

      return NextResponse.json<ParseFoodResponse>({
        success: true,
        data: {
          food: parsed.food,
          quantity: Number(parsed.quantity),
          unit: parsed.unit,
          kcal: parsed.kcal ? Number(parsed.kcal) : undefined,
          fat: parsed.fat ? Math.round(Number(parsed.fat) * 10) / 10 : undefined,
          carbs: parsed.carbs ? Math.round(Number(parsed.carbs) * 10) / 10 : undefined,
          protein: parsed.protein ? Math.round(Number(parsed.protein) * 10) / 10 : undefined,
          notes: parsed.notes,
        },
      });

    } catch (parseError) {
      console.error('Failed to parse OpenAI response:', parseError);
      return fallbackParsing(text);
    }

  } catch (error) {
    console.error('Food parsing error:', error);
    
    return NextResponse.json<ParseFoodResponse>({
      success: false,
      error: 'Failed to parse food description',
    }, { status: 500 });
  }
}

// Fallback parsing without AI
// eslint-disable-next-line @typescript-eslint/no-unused-vars
function fallbackParsing(text: string, units: 'metric' | 'imperial' = 'metric'): NextResponse<ParseFoodResponse> {
  const cleanText = text.toLowerCase().trim();
  
  // Simple pattern matching for common foods
  const patterns = [
    { regex: /(\d+)\s*(g|gram|grams)\s+(.+)/, unit: 'g' },
    { regex: /(\d+)\s*(ml|milliliter|milliliters)\s+(.+)/, unit: 'ml' },
    { regex: /(\d+)\s*(cup|cups)\s+(.+)/, unit: 'cup' },
    { regex: /(\d+)\s*(tbsp|tablespoon|tablespoons)\s+(.+)/, unit: 'tbsp' },
    { regex: /(\d+)\s*(tsp|teaspoon|teaspoons)\s+(.+)/, unit: 'tsp' },
    { regex: /(\d+)\s*(piece|pieces)\s+(.+)/, unit: 'piece' },
    { regex: /(\d+)\s*(slice|slices)\s+(.+)/, unit: 'slice' },
  ];

  for (const pattern of patterns) {
    const match = cleanText.match(pattern.regex);
    if (match) {
      return NextResponse.json<ParseFoodResponse>({
        success: true,
        data: {
          food: match[3].trim(),
          quantity: parseInt(match[1]),
          unit: pattern.unit,
          notes: 'Parsed without AI assistance',
        },
      });
    }
  }

  // Default parsing - assume it's a single item with realistic portions
  const commonPortions: Record<string, { quantity: number; unit: string; kcal?: number }> = {
    // Fruits
    'apple': { quantity: 150, unit: 'g', kcal: 78 },
    'banana': { quantity: 120, unit: 'g', kcal: 107 },
    'orange': { quantity: 130, unit: 'g', kcal: 61 },

    // Basic foods
    'egg': { quantity: 50, unit: 'g', kcal: 70 },
    'bread': { quantity: 30, unit: 'g', kcal: 80 },
    'slice of bread': { quantity: 30, unit: 'g', kcal: 80 },

    // Pasta dishes (realistic restaurant portions)
    'pasta': { quantity: 300, unit: 'g', kcal: 450 },
    'spaghetti': { quantity: 300, unit: 'g', kcal: 450 },
    'fettuccine': { quantity: 300, unit: 'g', kcal: 450 },
    'fettuccine alfredo': { quantity: 350, unit: 'g', kcal: 800 },
    'plate of pasta': { quantity: 350, unit: 'g', kcal: 500 },
    'bowl of pasta': { quantity: 300, unit: 'g', kcal: 450 },

    // Rice dishes
    'rice': { quantity: 200, unit: 'g', kcal: 260 },
    'fried rice': { quantity: 250, unit: 'g', kcal: 400 },
    'plate of rice': { quantity: 200, unit: 'g', kcal: 260 },
    'bowl of rice': { quantity: 200, unit: 'g', kcal: 260 },

    // Meat portions
    'chicken': { quantity: 150, unit: 'g', kcal: 248 },
    'chicken breast': { quantity: 150, unit: 'g', kcal: 248 },
    'beef': { quantity: 150, unit: 'g', kcal: 375 },
    'pork': { quantity: 150, unit: 'g', kcal: 390 },

    // Common dishes
    'sandwich': { quantity: 1, unit: 'piece', kcal: 350 },
    'burger': { quantity: 1, unit: 'piece', kcal: 540 },
    'pizza slice': { quantity: 1, unit: 'slice', kcal: 285 },
    'slice of pizza': { quantity: 1, unit: 'slice', kcal: 285 },
  };

  // Try to find the best match (prioritize longer/more specific matches)
  const sortedFoods = Object.entries(commonPortions).sort((a, b) => b[0].length - a[0].length);

  for (const [food, portion] of sortedFoods) {
    if (cleanText.includes(food)) {
      return NextResponse.json<ParseFoodResponse>({
        success: true,
        data: {
          food: food,
          quantity: portion.quantity,
          unit: portion.unit,
          kcal: portion.kcal,
          notes: 'Estimated portion size - please verify',
        },
      });
    }
  }

  // Last resort - return the text as-is with more realistic default values
  // Try to guess if it's a dish/plate/bowl vs individual item
  const isDish = cleanText.includes('plate') || cleanText.includes('bowl') || cleanText.includes('dish') ||
                 cleanText.includes('serving') || cleanText.includes('portion');

  return NextResponse.json<ParseFoodResponse>({
    success: true,
    data: {
      food: cleanText,
      quantity: isDish ? 250 : 100, // Larger portion for dishes
      unit: 'g',
      kcal: isDish ? 400 : 150, // Estimate calories based on portion size
      notes: 'Estimated portion - please verify and adjust as needed',
    },
  });
}
