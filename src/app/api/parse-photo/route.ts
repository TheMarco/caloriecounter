import { NextRequest, NextResponse } from 'next/server';
import OpenAI from 'openai';
import type { ParseFoodResponse } from '@/types';
import { guardProxy } from '@/lib/proxyGuard';
import { recordSpend } from '@/lib/openaiCost';

// Fallback parsing without OpenAI (basic response)
function fallbackParsing(): NextResponse<ParseFoodResponse> {
  return NextResponse.json<ParseFoodResponse>({
    success: false,
    error: 'Photo analysis requires OpenAI API. Please configure your API key.',
  }, { status: 503 });
}

export async function POST(request: NextRequest) {
  try {
    const guard = await guardProxy(request);
    if (!guard.ok) {
      return NextResponse.json<ParseFoodResponse>({ success: false, error: guard.error }, { status: guard.status });
    }

    console.log('📡 Parse photo API called');
    const { imageData, units = 'metric', details } = await request.json();

    console.log('📡 Image data length:', imageData?.length);
    console.log('📡 Units:', units);

    if (!imageData || typeof imageData !== 'string') {
      console.error('📡 Invalid image data');
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Invalid image data',
      }, { status: 400 });
    }

    // The app uploads a 1024×1024 JPEG (~200-800 KB base64). Anything over 5 MB is
    // a misbehaving client / raw photo — reject it rather than pay for it.
    if (imageData.length > 5 * 1024 * 1024) {
      console.error('📡 Image too large:', imageData.length);
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Image too large. Please try a smaller image.',
      }, { status: 400 });
    }

    if (!process.env.OPENAI_API_KEY) {
      console.error('📡 No OpenAI API key found');
      return fallbackParsing();
    }

    console.log('📡 OpenAI API key found, length:', process.env.OPENAI_API_KEY.length);

    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    // Build additional context from user details
    let additionalContext = '';
    if (details) {
      additionalContext = '\n\nADDITIONAL USER CONTEXT:\n';
      if (details.plateSize) {
        const sizeMap = {
          'small': 'small plate/bowl (about 6-8 inches)',
          'medium': 'medium plate/bowl (about 9-10 inches)',
          'large': 'large plate/bowl (about 11-12 inches)',
          'extra-large': 'extra large plate/bowl (about 13+ inches)'
        };
        additionalContext += `- Plate/bowl size: ${sizeMap[details.plateSize as keyof typeof sizeMap] || details.plateSize}\n`;
      }
      if (details.servingType) {
        const typeMap = {
          'home': 'home cooking (typically smaller, more controlled portions)',
          'restaurant': 'restaurant serving (typically larger portions)',
          'fast-food': 'fast food serving (standardized portions)',
          'snack': 'snack portion (smaller than meal portion)'
        };
        additionalContext += `- Serving context: ${typeMap[details.servingType as keyof typeof typeMap] || details.servingType}\n`;
      }
      if (details.additionalDetails && details.additionalDetails.trim()) {
        additionalContext += `- Additional details: ${details.additionalDetails.trim()}\n`;
      }
      additionalContext += '\nUse this context to improve your portion size and nutritional estimates.';
    }

    const prompt = `Analyze the attached food photo and estimate nutrition for the visible food.

User unit preference: ${units}.${additionalContext}

Important:
- This is a photo-based estimate, not a precise measurement.
- Estimate the visible edible portion only.
- If food is visible but uncertain, return the best estimate with low confidence.
- Return an error only if no food is visible, the image is unreadable, or the visible item cannot reasonably be identified as food.
- Do not claim certainty about hidden ingredients, exact weight, brand, recipe, oil amount, or sauce amount.

Unit rules:
- ${units === 'metric' ? 'Prefer grams for solid foods and ml for liquids when practical.' : 'Prefer oz and lb for solid foods, and cups / fl oz for liquids, when practical.'}
- For plated meals with multiple visible items, use "plate" or "serving".
- For countable foods such as burgers, sandwiches, pizza slices, apples, tacos, pastries, or eggs, use piece or slice when natural.
- For packages, bottles, jars, and containers, estimate a typical serving size, not the entire container, unless the visible food is clearly the full amount being eaten.

If food is visible, return this JSON structure exactly:
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
  "notes": "brief description of visible food and main uncertainty",
  "components": [
    { "name": "visible food item", "grams": number, "kcal": number, "fat": number, "carbs": number, "protein": number, "fiber": number, "sodium": number, "sugar": number, "confidence": "low|medium|high" }
  ]
}

If no food is visible, return:
{
  "error": "No food visible in this image"
}

If the image is too blurry, dark, obstructed, or unreadable to identify food, return:
{
  "error": "Image is not clear enough to identify food"
}

Identification rules:
- Identify visible food items and likely food category.
- For uncertain items, use generic names rather than inventing specifics.
- Example: use "grilled meat" instead of "grilled chicken" if the meat type is unclear.
- Example: use "creamy sauce" instead of "alfredo sauce" if the sauce type is unclear.
- Do not infer invisible ingredients unless they are typical and necessary for the food category.
- Do not identify a branded packaged food unless the brand/product name is readable.

Portion estimation rules:
- Use realistic serving sizes.
- Never use unrealistic tiny portions like 1g unless the visible food truly appears that small.
- Use visible scale cues such as plates, bowls, utensils, cups, hands, or packaging when available.
- If no scale cue exists, assume a normal serving for the visible food type.
- Estimate visible portion size, not what might be outside the frame.
- For restaurant/prepared foods, use the higher end of typical serving sizes.
- For simple home foods, use ordinary default portions.
- If a plate contains multiple components, estimate the total nutrition for the whole visible plate/serving.

Cooking and calorie rules:
- Use visual cues such as grill marks, breading, oil sheen, melted cheese, creamy sauces, dressing, or fried texture.
- Choose a nutrition estimate appropriate to the apparent cooking method.
- Do not apply an extra calorie multiplier if the selected food estimate already reflects that cooking method.
- Account for visible sauces, dressings, cheese, oils, butter, breading, and toppings when they materially affect nutrition.

Component rules:
- Use components when the visible meal has multiple distinct recognizable food items, such as chicken + rice + broccoli, burger + fries, eggs + toast, or salad + dressing.
- Components should be visible plate items, not raw recipe ingredients.
- Do not decompose sauces into oil, salt, flour, spices, or water.
- For a single food item, return components as [].
- For multi-component plates, top-level kcal, fat, carbs, protein, fiber, sodium, and sugar must equal the sum of components after rounding.

Rounding rules:
- kcal: nearest 5 calories
- fat/carbs/protein: nearest 1g
- fiber/sugar: nearest 1g
- sodium: nearest 10mg
- estimated grams/ml: nearest 5g or 5ml

Realistic portion examples:
- Plate of chicken, rice, and vegetables -> 1 plate, 500-700 kcal
- Plate of pasta with sauce -> 1 plate, 600-900 kcal
- Bowl of rice with toppings -> 1 bowl, 400-700 kcal
- Mixed salad with dressing -> 1 plate/bowl, 250-600 kcal depending on toppings
- Single apple -> 1 piece, 80-100 kcal
- Slice of pizza -> 1 slice, 250-400 kcal
- Sandwich -> 1 piece, 300-700 kcal
- Burger with fries -> 1 plate/serving, 700-1200 kcal
- Bowl of soup -> 1 bowl, 150-350 kcal
- Salad dressing -> 2 tbsp, 100-150 kcal
- Condiments/sauces -> 1-2 tbsp, 20-150 kcal`;

    console.log('🔍 Analyzing photo with OpenAI Vision API');
    console.log('🔍 Image data format:', imageData.substring(0, 50));

    // Validate image data format
    if (!imageData.startsWith('data:image/')) {
      console.error('🔍 Invalid image format - not a data URL');
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Invalid image format. Expected data URL.',
      }, { status: 400 });
    }

    let completion;
    // gpt-5.4-nano (vision) primary; gpt-4o-mini as the reliability fallback.
    // Images are sent at detail:'high' (below) over a 1024×1024 square from the app.
    const models = ['gpt-5.4-nano', 'gpt-4o-mini'];
    let lastError: unknown;

    for (const model of models) {
      try {
        console.log(`🤖 Attempting to use model: ${model}`);
        completion = await openai.chat.completions.create({
          model,
          messages: [
            {
              role: 'system',
              content: 'You are a nutrition estimation engine. Analyze food photos and return only valid JSON matching the requested schema. Do not include markdown, prose, or extra text.',
            },
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: prompt,
                },
                {
                  type: 'image_url',
                  image_url: {
                    url: imageData,
                    detail: 'high'
                  },
                },
              ],
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
      const openaiError = lastError;
      console.error('🤖 OpenAI API error:', openaiError);

      let errorMessage = 'Unknown OpenAI error';
      let statusCode = 500;

      if (openaiError && typeof openaiError === 'object') {
        const error = openaiError as Record<string, unknown>;
        if (error.response && typeof error.response === 'object') {
          const response = error.response as Record<string, unknown>;
          if (response.data && typeof response.data === 'object') {
            const data = response.data as Record<string, unknown>;
            if (data.error && typeof data.error === 'object') {
              const errorObj = data.error as Record<string, unknown>;
              if (typeof errorObj.message === 'string') {
                errorMessage = errorObj.message;
              }
            }
          }
          if (typeof response.status === 'number') {
            statusCode = response.status;
          }
        } else if (error.message && typeof error.message === 'string') {
          errorMessage = error.message;
        }
      }

      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: `OpenAI API error: ${errorMessage}`,
      }, { status: statusCode });
    }

    // Charge the call's real cost to the device's monthly budget.
    await recordSpend(guard.keyId, completion);

    const responseText = completion.choices[0]?.message?.content?.trim();

    if (!responseText) {
      console.error('🤖 No response from OpenAI');
      throw new Error('No response from OpenAI');
    }

    console.log('🤖 OpenAI Vision response:', responseText);

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

      // Check if OpenAI returned an error
      if (parsed.error) {
        return NextResponse.json<ParseFoodResponse>({
          success: false,
          error: parsed.error,
        }, { status: 400 });
      }

      // Validate the parsed response
      if (!parsed.food || !parsed.quantity || !parsed.unit) {
        throw new Error('Invalid response format from AI');
      }

      console.log('✅ Successfully parsed food from photo:', parsed.food);

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

      // Atwater floor (same as the text route): kcal can't read below its macros;
      // scale the breakdown to match the corrected total.
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
      console.error('Raw response:', responseText);
      
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Failed to analyze the photo. Please try again with a clearer image.',
      }, { status: 500 });
    }

  } catch (error) {
    console.error('Photo parsing error:', error);
    
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    
    return NextResponse.json<ParseFoodResponse>({
      success: false,
      error: `Failed to analyze photo: ${errorMessage}`,
    }, { status: 500 });
  }
}
