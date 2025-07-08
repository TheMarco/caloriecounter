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
  "unit": "g|ml|cup|tbsp|tsp|piece|slice|oz|lb",
  "kcal": total_calories_for_this_serving,
  "fat": total_fat_grams_for_this_serving,
  "carbs": total_carbs_grams_for_this_serving,
  "protein": total_protein_grams_for_this_serving,
  "notes": "any_additional_info"
}

IMPORTANT RULES:
- For compound foods (like "chili dog with cheese"), calculate the TOTAL calories for the complete item
- Use realistic portion sizes (e.g., "chili dog" = 1 piece ≈ 200g, "apple" = 1 medium ≈ 150g)
- The "kcal" field should be the TOTAL calories for the quantity specified, NOT per 100g
- For complex dishes, consider ALL ingredients (bun, hot dog, chili, cheese, etc.)
- Be generous with calorie estimates for restaurant/prepared foods
- Use appropriate units based on user preference: ${units === 'metric' ? 'prefer grams for solids, ml for liquids' : 'use oz, lb, cups, tbsp, tsp as appropriate'}
- Examples:
  * "chili dog with cheese" → quantity: 1, unit: "piece", kcal: 550 (total for whole item)
  * "Big Mac" → quantity: 1, unit: "piece", kcal: 563 (total for whole burger)
  * "slice of pepperoni pizza" → quantity: 1, unit: "slice", kcal: 298 (total for slice)
  * "2 eggs" → quantity: 2, unit: "piece", kcal: 140 (total for both eggs)
  * "100g chicken breast" → quantity: 100, unit: "g", kcal: 165 (total for 100g)
  * "tablespoon of mayo" → quantity: 1, unit: "tbsp", kcal: 90 (total for 1 tbsp)
  * "shot of tequila" → ${units === 'metric' ? 'quantity: 44, unit: "ml", kcal: 97' : 'quantity: 1.5, unit: "oz", kcal: 97'} (standard shot size)`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
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

  // Default parsing - assume it's a single item
  const commonPortions: Record<string, { quantity: number; unit: string; kcal?: number }> = {
    'apple': { quantity: 150, unit: 'g', kcal: 52 },
    'banana': { quantity: 120, unit: 'g', kcal: 89 },
    'orange': { quantity: 130, unit: 'g', kcal: 47 },
    'egg': { quantity: 50, unit: 'g', kcal: 155 },
    'bread': { quantity: 30, unit: 'g', kcal: 265 },
    'rice': { quantity: 100, unit: 'g', kcal: 130 },
    'chicken': { quantity: 100, unit: 'g', kcal: 165 },
  };

  for (const [food, portion] of Object.entries(commonPortions)) {
    if (cleanText.includes(food)) {
      return NextResponse.json<ParseFoodResponse>({
        success: true,
        data: {
          food: food,
          quantity: portion.quantity,
          unit: portion.unit,
          kcal: portion.kcal,
          notes: 'Estimated portion size',
        },
      });
    }
  }

  // Last resort - return the text as-is with default values
  return NextResponse.json<ParseFoodResponse>({
    success: true,
    data: {
      food: cleanText,
      quantity: 100,
      unit: 'g',
      notes: 'Please adjust quantity and calories manually',
    },
  });
}
