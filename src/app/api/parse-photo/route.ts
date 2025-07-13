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

    if (imageData.length > 10 * 1024 * 1024) { // 10MB limit
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

    const unitsInstruction = units === 'metric'
      ? 'Use metric units when possible (grams, ml, liters). For liquids like shots, use ml (e.g., 44ml for a shot of tequila). For plated meals with multiple components, use "plate" or "serving" as the unit.'
      : 'Use imperial units when appropriate (oz, lb, cups, tbsp, tsp). For liquids like shots, use oz (e.g., 1.5oz for a shot of tequila). For plated meals with multiple components, use "plate" or "serving" as the unit.';

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

    const prompt = `You are a nutrition expert analyzing a photo of food. Look at this image and provide accurate nutritional information.

IMPORTANT: The user prefers ${units} units. ${unitsInstruction}${additionalContext}

CRITICAL ANALYSIS RULES:
- Try to identify any food items in the image, even if partially visible
- If you can see what appears to be food but aren't 100% certain, make your best estimate
- Only refuse if the image clearly contains no food at all, or is completely unreadable
- For unclear portions, estimate based on what you can see and note uncertainty in your response
- IMPORTANT: If you see a bottle, jar, or package, estimate a TYPICAL SERVING SIZE, not the entire container

COOKING METHOD & CALORIE IMPACT:
- Identify cooking methods from visual cues (grilled marks, breading, oil sheen, etc.)
- Fried foods: add 20-50% more calories than baked/grilled equivalents
- Sauces and dressings: look for glossy appearance, estimate added fats
- Cheese melted on top: add calories for cheese layer
- Visible oils/butter: account for added fats in cooking
- Raw vs. cooked portions: cooked meat shrinks ~25%, vegetables vary

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

If you cannot see any food at all in the image, respond with:
{
  "error": "No food visible in this image"
}

PORTION SIZE ESTIMATION RULES:
- ALWAYS estimate realistic serving sizes, NOT the entire package/bottle
- For packaged foods: estimate typical serving size (e.g., 2 tbsp dressing, not whole bottle)
- For plated meals with multiple components: use "plate" or "serving" as unit, estimate total calories for the entire meal
- For single food items: use weight (grams/oz) or pieces as appropriate
- Be generous with calorie estimates for restaurant/prepared foods
- Consider ALL visible ingredients and components when calculating total nutrition

VISUAL SCALE ESTIMATION:
- Use visible reference objects for scale (utensils, hands, plates, cups, coins, etc.)
- Standard dinner plate ≈ 10-11 inches, salad plate ≈ 7-8 inches
- Standard fork ≈ 7 inches, spoon ≈ 6 inches
- Average adult hand span ≈ 7-9 inches
- Look for thickness/depth cues to estimate volume
- Consider food density (rice vs. lettuce vs. meat) when estimating weight

REALISTIC PORTION EXAMPLES:
  * Plate of chicken, rice, and vegetables → quantity: 1, unit: "plate", kcal: 500-700
  * Plate of pasta with sauce → quantity: 1, unit: "plate", kcal: 600-800
  * Bowl of rice with toppings → quantity: 1, unit: "bowl", kcal: 400-600
  * Mixed salad on plate → quantity: 1, unit: "plate", kcal: 200-400
  * Single apple → quantity: 1, unit: "piece", kcal: 80-100
  * Slice of pizza → quantity: 1, unit: "slice", kcal: 250-400
  * Sandwich → quantity: 1, unit: "piece", kcal: 300-600
  * Bowl of soup → quantity: 1, unit: "bowl", kcal: 150-300
  * Salad dressing → quantity: 2, unit: "tbsp", kcal: 100-150
  * Condiments/sauces → quantity: 1-2, unit: "tbsp", kcal: 20-100
  * Beverages → quantity: 1, unit: "cup" or "glass", kcal: varies
  * Snack foods → quantity: 1, unit: "serving" or typical portion, kcal: varies

Remember: Only proceed if you can clearly see and identify food. When in doubt, return an error.`;

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
    try {
      completion = await openai.chat.completions.create({
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
    } catch (openaiError: unknown) {
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
