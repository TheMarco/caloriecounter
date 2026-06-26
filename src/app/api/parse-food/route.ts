// Food parsing API route using OpenAI
import { NextRequest, NextResponse } from 'next/server';
import OpenAI from 'openai';
import type { ParseFoodResponse } from '@/types';
import { guardProxy } from '@/lib/proxyGuard';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(request: NextRequest) {
  try {
    const guard = await guardProxy(request);
    if (!guard.ok) {
      return NextResponse.json<ParseFoodResponse>({ success: false, error: guard.error }, { status: guard.status });
    }

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

    const prompt = `Estimate nutrition for this food description:

"${text}"

User unit preference: ${units}.

Task:
Parse the food description into a realistic single serving. Estimate total nutrition for the described serving, not per 100g. Use typical serving sizes unless the user specified a quantity or weight.

Unit rules:
- ${units === 'metric' ? 'Prefer grams for solid foods and ml for liquids when practical.' : 'Prefer oz and lb for solid foods, and cups / fl oz for liquids, when practical.'}
- For countable foods, use piece, slice, bowl, plate, serving, tbsp, tsp, or cup when more natural.
- For alcohol shots, use ${units === 'metric' ? '44ml' : '1.5oz'} unless specified otherwise.

Return this JSON structure exactly:
{
  "food": "standardized food name",
  "quantity": number,
  "unit": "g|ml|cup|tbsp|tsp|piece|slice|oz|lb|bowl|plate|serving",
  "estimated_total_grams": number,
  "kcal": number,
  "fat": number,
  "carbs": number,
  "protein": number,
  "fiber": number,
  "sodium": number,
  "sugar": number,
  "confidence": "low|medium|high",
  "assumptions": ["assumption 1", "assumption 2"],
  "notes": "brief note about uncertainty or portion basis",
  "components": [
    { "name": "ingredient name", "grams": number, "kcal": number, "fat": number, "carbs": number, "protein": number, "fiber": number, "sodium": number, "sugar": number }
  ]
}

Portion rules:
- Never use unrealistic tiny portions like 1g unless the user explicitly says so.
- If quantity is unspecified, estimate one normal serving.
- For pasta dishes, a plate/bowl is usually 300-400g total.
- For rice dishes, a plate/bowl is usually 250-400g total including toppings.
- For salads, a bowl/plate is usually 150-300g depending on toppings and dressing.
- For sandwiches, burgers, hot dogs, and wraps, use piece and estimate realistic total weight.
- For pizza, use slice unless the user specifies a whole pizza.
- For soup, use bowl, usually 250-350ml.
- For meat portions, use 100-200g depending on context.
- For restaurant/prepared foods, use the higher end of typical serving sizes.
- For simple home foods, use ordinary default portions.

Compound food rules:
- For assembled foods such as burgers, sandwiches, hot dogs, tacos, burritos, stir fry, pasta with sauce, and salads with toppings, include recognizable components.
- Use natural named parts, not a from-scratch recipe.
- Do not break sauces into flour, water, spices, oil, salt, etc.
- Do not list tiny incidental ingredients unless they materially affect nutrition.
- For single foods or drinks such as apple, coffee, milk, plain bread, eggs, or chicken breast, return components as [].
- For compound foods, calculate top-level kcal, fat, carbs, protein, fiber, sodium, and sugar by summing components after rounding.

Rounding rules:
- kcal: nearest 5 calories
- fat/carbs/protein: nearest 1g
- fiber/sugar: nearest 1g
- sodium: nearest 10mg
- grams/ml: nearest 5g or 5ml when estimated

Examples:
- "plate of fettuccine alfredo" -> 350g, about 800 kcal
- "bowl of chicken fried rice" -> 300g, about 520 kcal
- "chili dog with cheese" -> 1 piece, about 500-600 kcal
- "Big Mac" -> 1 piece, 563 kcal
- "slice of pepperoni pizza" -> 1 slice, about 300 kcal
- "bowl of tomato soup" -> 1 bowl, about 250ml, about 180 kcal
- "2 eggs" -> 2 pieces, about 140 kcal
- "100g chicken breast" -> 100g, about 165 kcal
- "tablespoon of mayo" -> 1 tbsp, about 90 kcal
- "shot of tequila" -> 44ml, about 97 kcal`;

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
              content: 'You are a nutrition estimation engine. Return only valid JSON matching the requested schema. Do not include markdown, explanations, or extra text.',
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
