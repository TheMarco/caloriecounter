// Per-device monthly spend cap. We bound how much OpenAI money any single device
// (≈ user — no accounts) can spend per calendar month. Each call's REAL cost is
// computed from the response's token `usage` and accumulated in Redis; once a
// device is at/over the cap, the proxy refuses further calls until next month.
//
// This is a soft cap with bounded overshoot: the call that crosses the line still
// completes (cost is only known after), so a device can exceed the cap by at most
// one call (a fraction of a cent for text, ~1–2¢ for a photo).
//
// ⚠️ PRICING BELOW IS A SAFETY INPUT, NOT BILLING. Verify the numbers against your
// current OpenAI pricing and adjust. Unknown models fall back to a deliberately
// HIGH price so we never under-count toward the cap.

import { kv } from "./redis";

// USD per 1,000,000 tokens, per model.
const PRICING: Record<string, { input: number; output: number }> = {
  "gpt-5.4-nano": { input: 0.10, output: 0.40 },
  "gpt-5-mini": { input: 0.25, output: 2.0 },
  "gpt-4o-mini": { input: 0.15, output: 0.6 },
  "gpt-4o": { input: 2.5, output: 10.0 },
  "gpt-4-turbo": { input: 10.0, output: 30.0 },
  "gpt-3.5-turbo": { input: 0.5, output: 1.5 },
};
const FALLBACK = { input: 5.0, output: 15.0 };

function priceFor(model: string): { input: number; output: number } {
  if (PRICING[model]) return PRICING[model];
  // Dated variants like "gpt-4o-mini-2024-07-18" → longest matching prefix.
  let best: { input: number; output: number } | null = null;
  let bestLen = 0;
  for (const key of Object.keys(PRICING)) {
    if (model.startsWith(key) && key.length > bestLen) {
      best = PRICING[key];
      bestLen = key.length;
    }
  }
  return best ?? FALLBACK;
}

type Usage = { prompt_tokens?: number; completion_tokens?: number } | null | undefined;

/** USD cost of one completion from its model + token usage. */
export function costOfUsage(model: string, usage: Usage): number {
  if (!usage) return 0;
  const p = priceFor(model || "");
  return ((usage.prompt_tokens ?? 0) * p.input + (usage.completion_tokens ?? 0) * p.output) / 1_000_000;
}

/** Per-device monthly budget in USD (default $2). Override with
 *  OPENAI_MONTHLY_BUDGET_PER_DEVICE. */
export const MONTHLY_CAP_USD = Number(process.env.OPENAI_MONTHLY_BUDGET_PER_DEVICE) || 2;

function monthKey(keyId: string): string {
  const month = new Date().toISOString().slice(0, 7); // YYYY-MM (UTC)
  return `attest:spend:${keyId}:${month}`;
}

export async function monthlySpendUSD(keyId: string): Promise<number> {
  const v = await kv.get<number | string>(monthKey(keyId));
  return v == null ? 0 : Number(v) || 0;
}

/** True once the device has spent at least its monthly budget. */
export async function overMonthlyCap(keyId: string): Promise<boolean> {
  return (await monthlySpendUSD(keyId)) >= MONTHLY_CAP_USD;
}

/** Add a completed call's actual cost to the device's running month total. */
export async function recordSpend(
  keyId: string,
  completion: { model?: string; usage?: Usage } | null | undefined,
): Promise<void> {
  if (!completion || !keyId) return;
  const cost = costOfUsage(completion.model ?? "", completion.usage);
  if (cost <= 0) return;
  await kv.incrByFloat(monthKey(keyId), cost, 60 * 60 * 24 * 33); // ~33-day TTL
}
