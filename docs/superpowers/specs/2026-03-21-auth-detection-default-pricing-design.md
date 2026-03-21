# Auth Detection & Built-in Default Pricing

## Problem

The plugin cannot distinguish API key users from account (subscription) users. This matters because:

1. **Account users** have rate limits (5h/7d utilization %) — the current display is built for them.
2. **API key users** pay per token with no rate limits — showing 0%/0% bars is useless. They need token counts and cost estimates.
3. The `cost` subcommand requires manual configuration of `$agent_stats_cost_rates`. Shipping built-in defaults removes this friction.

## Auth Detection

### New function: `__agent_stats_auth_type`

```
Usage: __agent_stats_auth_type <provider>
Returns: "account", "apikey", or "unknown"
```

**Claude:**
- If `~/.claude/.credentials.json` exists and contains a non-empty `claudeAiOauth.accessToken` → `account`
- Else if `$ANTHROPIC_API_KEY` is set and non-empty → `apikey`
- Else → `unknown`

**Codex:**
- If the most recent session JSONL contains a `token_count` event with `rate_limits.plan_type` → `account`
- Else if `$OPENAI_API_KEY` is set and non-empty → `apikey`
- Else → `unknown`

**Gemini:**
- If `$GEMINI_API_KEY` or `$GOOGLE_API_KEY` is set and non-empty → `apikey`
- Else if `~/.gemini` directory exists → `account` (Google OAuth)
- Else → `unknown`

The result is cached in a global variable `__agent_stats_auth_{provider}` for the shell session to avoid repeated file/env checks.

## Display Changes

### Prompt mode (right prompt)

| Auth type | Current | New |
|-----------|---------|-----|
| Account | `5h% 7d%` | No change |
| API Key | `0 0` (useless) | `{token_count}` (today's tokens) |
| Unknown | `0 0` | No change (treat as account with no data) |

### Compact mode

| Auth type | Current | New |
|-----------|---------|-----|
| Account | `Claude (Max) ░░░ 3%/5h ░░░ 0%/7d` | No change |
| API Key | `Claude (Unknown) ░░░ 0%/5h ░░░ 0%/7d` | `Claude (API) 45.3K tokens, 12 msgs ~$0.42` |
| Unknown | Shows "Unknown" plan | No change |

For API key compact mode, the format is:
```
{Provider} (API) {today_tokens} tokens, {today_msgs} msgs ~${cost}
```
Cost is shown only if rates are available (built-in or user-configured). Token and message counts come from the same local JSONL parsing already used by detailed mode.

### Detailed mode

No structural changes. The cost column (already implemented in `agent-stats cost`) is shown automatically for API key users in the per-model breakdown, using built-in rates as fallback.

### Cost subcommand

No changes to the `cost` subcommand itself. It already uses `$agent_stats_cost_rates`. The only change is that `__agent_stats_default_rates` pre-populates these rates if the user hasn't configured any.

## Built-in Default Pricing

### New function: `__agent_stats_default_rates`

Called from `conf.d/agent_stats.fish` during init. Sets `$agent_stats_cost_rates` only if it is empty (user overrides take precedence).

### Rate format

Same as existing: `provider:model_prefix:type=rate_per_mtok`

Types: `in` (input), `out` (output), `cache` (cache read), `think` (thinking/reasoning)

### Default rates (USD per MTok)

**Claude** (source: platform.claude.com/docs/en/about-claude/pricing)

| Model prefix | in | out | cache |
|---|---|---|---|
| `claude:claude-opus-4` | 15 | 75 | 1.5 |
| `claude:claude-4.6-opus` | 5 | 25 | 0.5 |
| `claude:claude-4.5-opus` | 5 | 25 | 0.5 |
| `claude:claude-4.6-sonnet` | 3 | 15 | 0.3 |
| `claude:claude-4.5-sonnet` | 3 | 15 | 0.3 |
| `claude:claude-sonnet-4` | 3 | 15 | 0.3 |
| `claude:claude-3.7-sonnet` | 3 | 15 | 0.3 |
| `claude:claude-haiku-4.5` | 1 | 5 | 0.1 |
| `claude:claude-3.5-haiku` | 0.8 | 4 | 0.08 |
| `claude:claude-3-haiku` | 0.25 | 1.25 | 0.03 |

**OpenAI / Codex** (source: openai.com/api/pricing)

| Model prefix | in | out | cache |
|---|---|---|---|
| `codex:gpt-5.4-mini` | 0.75 | 4.5 | 0.075 |
| `codex:gpt-5.4-nano` | 0.2 | 1.25 | 0.02 |
| `codex:gpt-5.4` | 2.5 | 15 | 0.25 |
| `codex:gpt-5.3-codex` | 1.75 | 14 | 0.175 |
| `codex:gpt-5.2-codex` | 1.75 | 14 | 0.175 |
| `codex:gpt-5.1-codex-max` | 1.25 | 10 | 0.125 |
| `codex:gpt-5.1-codex-mini` | 0.25 | 2 | 0.025 |
| `codex:gpt-5.1-codex` | 1.25 | 10 | 0.125 |
| `codex:gpt-5-codex` | 1.25 | 10 | 0.125 |
| `codex:codex-mini` | 1.5 | 6 | 0.375 |
| `codex:o4-mini` | 1.1 | 4.4 | 0.275 |
| `codex:o3` | 2 | 8 | 0.5 |
| `codex:o3-mini` | 1.1 | 4.4 | 0.55 |
| `codex:gpt-4.1` | 2 | 8 | 0.5 |
| `codex:gpt-4.1-mini` | 0.4 | 1.6 | 0.1 |
| `codex:gpt-4.1-nano` | 0.1 | 0.4 | 0.025 |
| `codex:gpt-4o` | 2.5 | 10 | 1.25 |
| `codex:gpt-4o-mini` | 0.15 | 0.6 | 0.075 |

**Gemini** (source: cloud.google.com/vertex-ai/generative-ai/pricing, standard tier)

| Model prefix | in | out | cache | think |
|---|---|---|---|---|
| `gemini:gemini-2.5-pro` | 1.25 | 10 | 0.13 | 10 |
| `gemini:gemini-2.5-flash` | 0.3 | 2.5 | 0.03 | 2.5 |
| `gemini:gemini-2.5-flash-lite` | 0.1 | 0.4 | 0.01 | 0.4 |
| `gemini:gemini-2.0-flash` | 0.15 | 0.6 | — | — |
| `gemini:gemini-2.0-flash-lite` | 0.075 | 0.3 | — | — |
| `gemini:gemini-3-pro` | 2 | 12 | 0.2 | 12 |
| `gemini:gemini-3-flash` | 0.5 | 3 | 0.05 | 3 |
| `gemini:gemini-3.1-pro` | 2 | 12 | 0.2 | 12 |
| `gemini:gemini-3.1-flash-lite` | 0.25 | 1.5 | 0.03 | 1.5 |

Note: Gemini thinking tokens use the same rate as output tokens (thinking is billed as output by Google).

## Files to modify

1. **New: `functions/__agent_stats_auth.fish`** — `__agent_stats_auth_type` function
2. **New: `functions/__agent_stats_default_rates.fish`** — default pricing rates
3. **Edit: `conf.d/agent_stats.fish`** — call `__agent_stats_default_rates` on init
4. **Edit: `functions/__agent_stats_claude.fish`** — branch on auth type in prompt/compact modes
5. **Edit: `functions/__agent_stats_codex.fish`** — branch on auth type in prompt/compact modes
6. **Edit: `functions/__agent_stats_gemini.fish`** — branch on auth type in prompt/compact modes
7. **Edit: `functions/__agent_stats_prompt.fish`** — handle token-count format from API key providers

## Non-goals

- Automatic rate refresh or pricing API calls — rates are hardcoded defaults updated with plugin releases.
- Detecting specific API key tiers or usage limits from the API providers.
- Changing the detailed mode layout — it already shows token breakdowns.
