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
  "fiber": total_dietary_fiber_grams_for_this_serving,
  "sodium": total_sodium_milligrams_for_this_serving,
  "sugar": total_sugars_grams_for_this_serving,
  "notes": "any_additional_info",
  "components": [ { "name": "ingredient name", "grams": number, "kcal": number, "fat": number, "carbs": number, "protein": number } ]
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

MICRONUTRIENTS:
- Also estimate dietary fiber (grams), sodium (milligrams), and total sugars (grams) for the whole serving.
- Round fiber and sugar to whole grams, sodium to the nearest 10 mg. These are approximate.

COMPONENTS (ingredient breakdown):
- For a COMPOUND or ASSEMBLED dish (sandwich, burger, chili dog, taco, stir fry, pasta with sauce, salad with toppings), include a "components" array of the recognizable parts a person would name. Example: "chili cheese dog" → hot dog bun, beef frank, chili, shredded cheese.
- Use the dish's natural named parts, NOT a from-scratch recipe — never break a sauce into flour/water/spices, and never list base ingredients like oil/salt on their own.
- Each component carries its grams and its kcal/fat/carbs/protein for THAT amount.
- The components' kcal and macros MUST sum to the dish totals (kcal/fat/carbs/protein) above.
- For a SINGLE food or drink (apple, coffee, a slice of bread, scrambled eggs), return an EMPTY components array []. Do not decompose it.

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

    // gpt-5.4-nano is cheap and tested well on the hard cases (toast w/ spreads,
    // fettuccine alfredo with the pasta, mac & cheese as a serving, chili dog parts).
    // gpt-4o-mini is the reliability fallback if nano errors. (Confirm the exact nano
    // model id against your account; the loop just tries them in order.)
    const models = ['gpt-5.4-nano', 'gpt-4o-mini'];
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
          max_tokens: 900,
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

      const round1 = (v: unknown) => v != null ? Math.round(Number(v) * 10) / 10 : undefined;
      let components = Array.isArray(parsed.components)
        ? parsed.components
            .filter((c: { name?: string; grams?: number }) => c && c.name && Number(c.grams) > 0)
            .map((c: { name: string; grams: number; kcal?: number; fat?: number; carbs?: number; protein?: number }) => ({
              name: String(c.name),
              grams: Math.round(Number(c.grams)),
              kcal: c.kcal != null ? Math.round(Number(c.kcal)) : undefined,
              fat: round1(c.fat),
              carbs: round1(c.carbs),
              protein: round1(c.protein),
            }))
        : undefined;

      let kcal = parsed.kcal != null ? Math.round(Number(parsed.kcal)) : undefined;
      const fat = round1(parsed.fat);
      const carbs = round1(parsed.carbs);
      const protein = round1(parsed.protein);
      const fiber = parsed.fiber != null ? Math.round(Number(parsed.fiber)) : undefined;

      // Atwater floor: calories can't read below what the macros physically imply
      // (9·fat + 4·carbs + 4·protein, fiber at ~2 kcal/g). A small model sometimes
      // lowballs the total a few % under its own macros — raise it to the floor, and
      // scale the breakdown's kcal to match so the app's component sum stays consistent
      // with the (corrected) total. A self-consistent estimate is left alone.
      if (kcal != null && fat != null && carbs != null && protein != null) {
        const floor = Math.round(9 * fat + 4 * carbs + 4 * protein - 2 * (fiber ?? 0));
        if (floor > 0 && kcal < floor * 0.97) {
          const scale = floor / kcal;
          kcal = floor;
          if (components) {
            components = components.map((c: { kcal?: number }) => ({
              ...c, kcal: c.kcal != null ? Math.round(c.kcal * scale) : c.kcal,
            }));
          }
        }
      }

      return NextResponse.json<ParseFoodResponse>({
        success: true,
        data: {
          food: parsed.food,
          quantity: Number(parsed.quantity),
          unit: parsed.unit,
          kcal,
          fat,
          carbs,
          protein,
          fiber,
          sodium: parsed.sodium != null ? Math.round(Number(parsed.sodium) / 10) * 10 : undefined,
          sugar: parsed.sugar != null ? Math.round(Number(parsed.sugar)) : undefined,
          notes: parsed.notes,
          components: components && components.length ? components : undefined,
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
