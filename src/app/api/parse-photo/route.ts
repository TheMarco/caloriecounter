import { NextRequest, NextResponse } from 'next/server';
import OpenAI from 'openai';
import type { ParseFoodResponse } from '@/types';

// Fallback parsing without OpenAI (basic response)
function fallbackParsing(): NextResponse<ParseFoodResponse> {
  return NextResponse.json<ParseFoodResponse>({
    success: false,
    error: 'Photo analysis requires OpenAI API. Please configure your API key.',
  }, { status: 503 });
}

export async function POST(request: NextRequest) {
  try {
    const { imageData, units = 'metric' } = await request.json();

    if (!imageData || typeof imageData !== 'string') {
      return NextResponse.json<ParseFoodResponse>({
        success: false,
        error: 'Invalid image data',
      }, { status: 400 });
    }

    if (!process.env.OPENAI_API_KEY) {
      return fallbackParsing();
    }

    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    const unitsInstruction = units === 'metric'
      ? 'Use metric units when possible (grams, ml, liters). For liquids like shots, use ml (e.g., 44ml for a shot of tequila).'
      : 'Use imperial units when appropriate (oz, lb, cups, tbsp, tsp). For liquids like shots, use oz (e.g., 1.5oz for a shot of tequila).';

    const prompt = `You are a nutrition expert analyzing a photo of food. Look at this image and provide accurate nutritional information.

IMPORTANT: The user prefers ${units} units. ${unitsInstruction}

CRITICAL ANALYSIS RULES:
- ONLY analyze if you can clearly see food in the image
- If the image doesn't contain food, or if you're unsure what the food is, respond with an error
- If the image is too blurry, dark, or unclear to make a confident assessment, respond with an error
- Be conservative - it's better to refuse than to guess incorrectly

If you can clearly identify food in the image, respond with this exact JSON structure:
{
  "food": "standardized food name",
  "quantity": number,
  "unit": "g|ml|cup|tbsp|tsp|piece|slice|oz|lb|bowl|plate|serving",
  "kcal": total_calories_for_this_serving,
  "fat": total_fat_grams_for_this_serving,
  "carbs": total_carbs_grams_for_this_serving,
  "protein": total_protein_grams_for_this_serving,
  "notes": "brief_description_of_what_you_see"
}

If you cannot confidently identify food or estimate portions, respond with:
{
  "error": "Cannot clearly identify food in this image" 
}

PORTION SIZE ESTIMATION RULES:
- Estimate realistic portion sizes based on visual cues (plate size, utensils, etc.)
- For plated meals: estimate total weight including all visible components
- For individual items: use appropriate units (pieces for discrete items, grams for portions)
- Be generous with calorie estimates for restaurant/prepared foods
- Consider ALL visible ingredients and components

REALISTIC PORTION EXAMPLES:
  * Plate of pasta with sauce → quantity: 350, unit: "g", kcal: 600-800
  * Bowl of rice with toppings → quantity: 300, unit: "g", kcal: 400-600  
  * Single apple → quantity: 1, unit: "piece", kcal: 80-100
  * Slice of pizza → quantity: 1, unit: "slice", kcal: 250-400
  * Sandwich → quantity: 1, unit: "piece", kcal: 300-600
  * Bowl of soup → quantity: 1, unit: "bowl", kcal: 150-300

Remember: Only proceed if you can clearly see and identify food. When in doubt, return an error.`;

    console.log('🔍 Analyzing photo with OpenAI Vision API');

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are a nutrition expert. Analyze food photos carefully and respond only with valid JSON. If you cannot clearly identify food, return an error.',
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
      max_tokens: 200,
      temperature: 0.1,
    });

    const responseText = completion.choices[0]?.message?.content?.trim();
    
    if (!responseText) {
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
