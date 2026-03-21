# Auth Detection & Built-in Default Pricing

## Problem

The plugin cannot distinguish API key users from account (subscription) users. This matters because:

1. **Account users** have rate limits (5h/7d utilization %) — the current display is built for them.
2. **API key users** pay per token with no rate limits — showing 0%/0% bars is useless. They need token counts and cost estimates.
3. The `cost` subcommand requires manual configuration of `$agent_stats_cost_rates`. Shipping built-in defaults removes this friction.

## Auth Detection

### New function: `__agent_stats_auth`

Lives in `functions/__agent_stats_auth.fish` (following the convention that file name matches function name).

```
Usage: __agent_stats_auth <provider>
Returns: "account", "apikey", or "unknown"
```

**Claude:**
- If `~/.claude/.credentials.json` exists and contains a non-empty `claudeAiOauth.accessToken` → `account`
- Else if `$ANTHROPIC_API_KEY` is set and non-empty → `apikey`
- Else → `unknown`

**Codex:**
- If `$OPENAI_API_KEY` is set and non-empty → `apikey`
- Else if `~/.codex/sessions` directory exists → `account` (OAuth-authenticated Codex CLI user)
- Else → `unknown`

Note: Codex session files may contain `rate_limits.plan_type`, but this field exists for both API key and account users, so it is not a reliable auth signal. The env var check is definitive: if `$OPENAI_API_KEY` is set, the user is paying per token; otherwise Codex CLI uses account-based auth.

**Gemini:**
- If `~/.gemini/tmp` directory exists with session files → `account` (Google OAuth, the standard Gemini CLI flow)
- Else if `$GEMINI_API_KEY` or `$GOOGLE_API_KEY` is set and non-empty → `apikey`
- Else → `unknown`

Note: `~/.gemini/tmp` with session files is checked first because many Google account users also have `$GOOGLE_API_KEY` set for other GCP services. The presence of Gemini CLI session data is a stronger signal of account usage.

### Caching

The result is cached in a global variable `__agent_stats_auth_{provider}` for the shell session to avoid repeated file/env checks. The `refresh` subcommand clears these cached values (forces re-detection).

**Known limitation:** If a user sets or unsets an API key env var mid-session, the cached auth type becomes stale until `agent-stats refresh` is run. This is acceptable because auth changes are infrequent, and the refresh subcommand provides a clear fix.

**Known limitation:** For Claude, a user could have stale credentials from a prior subscription plus a current API key. Credentials file wins because account detection is checked first. If the credentials are actually expired, the usage API call will fail and the display will show "Unknown 0 0" — functionally harmless.

## Display Changes

### Prompt mode — data contract between providers and `__agent_stats_prompt`

Auth detection happens **inside each provider's prompt function**, not in `__agent_stats_prompt.fish`. Each provider decides its output format based on auth type:

**Account users (no change):**
- Claude prompt returns: `"FIVE_HOUR SEVEN_DAY PLAN_NAME"` (existing format)
- Codex prompt returns: `"FIVE_HOUR SEVEN_DAY"` (existing format)
- Gemini prompt returns: `"TOKEN_COUNT MSG_COUNT"` (existing format)

**API key users (new format):**
- Claude prompt returns: `"TOKEN_COUNT MSG_COUNT apikey"` (third field = `apikey` sentinel)
- Codex prompt returns: `"TOKEN_COUNT MSG_COUNT apikey"` (third field = `apikey` sentinel)
- Gemini prompt returns: `"TOKEN_COUNT MSG_COUNT"` (unchanged — Gemini already shows tokens)

`__agent_stats_prompt.fish` detects the `apikey` sentinel in the third field for Claude/Codex and renders token counts instead of rate limit percentages. The sentinel approach keeps the change minimal — only 3 lines of conditional logic per provider in the prompt renderer.

### Prompt mode — display

| Provider | Auth type | Display |
|----------|-----------|---------|
| Claude | Account | ` 3%` (rate limit, colored by usage level) |
| Claude | API Key | ` 45.3K` (formatted token count, colored yellow) |
| Codex | Account | `⬡ 3%` (rate limit, colored by usage level) |
| Codex | API Key | `⬡ 45.3K` (formatted token count, colored yellow) |
| Gemini | Any | `󰫣 45.3K` (no change — already shows tokens) |

Token counts use `__agent_stats_format tokens $count` for consistent formatting.

### Compact mode

| Auth type | Current | New |
|-----------|---------|-----|
| Account | `Claude (Max) ░░░ 3%/5h ░░░ 0%/7d` | No change |
| API Key | `Claude (Unknown) ░░░ 0%/5h ░░░ 0%/7d` | `Claude (API) 45.3K tokens, 12 msgs ~$0.42` |
| Unknown | Shows "Unknown" plan | No change |

For API key compact mode, the format is:
```
{Provider} (API) {today_tokens} tokens, {today_msgs} msgs ~${today_cost}
```
All values (tokens, messages, cost) are **today only**. This requires a today-only cost calculation path in each provider's compact function — filter JSONL to today's date, extract per-model token breakdowns, sum costs via `__agent_stats_cost`. Cost is shown only if rates are available (built-in or user-configured); omitted otherwise.

### Detailed mode

No structural changes. The cost column (already implemented in `agent-stats cost`) is shown automatically for API key users in the per-model breakdown, using built-in rates as fallback.

### Cost subcommand

No changes to the `cost` subcommand itself. It already uses `$agent_stats_cost_rates`. The only change is that built-in defaults pre-populate these rates.

## Built-in Default Pricing

### Migration strategy

The existing hardcoded rates in `conf.d/agent_stats.fish` (lines 14-22) will be **replaced** by the new `__agent_stats_default_rates` function. The init block changes from:

```fish
if not set -q agent_stats_cost_rates
    set -U agent_stats_cost_rates claude:haiku-4:in=0.80 ...
end
```

to:

```fish
# Set defaults if empty; update if version changed
__agent_stats_default_rates
```

`__agent_stats_default_rates` uses a version stamp (`$__agent_stats_rates_version`) to detect when built-in rates have been updated across plugin releases. If the version changes, rates are refreshed. If the user has manually set `$agent_stats_cost_rates` (detected by a `$agent_stats_cost_rates_custom` flag), their overrides are preserved.

### Rate format

Same as existing: `provider:model_prefix:type=rate_per_mtok`

Model prefixes must match how provider functions pass model names to `__agent_stats_cost`:
- **Claude:** strips `claude-` prefix from JSONL model names (e.g. `claude-sonnet-4-20250514` → `sonnet-4-20250514`), so rate keys use `claude:sonnet-4` (prefix match)
- **Codex:** passes model names raw (e.g. `gpt-5.1-codex`), so rate keys use `codex:gpt-5.1-codex` (prefix match)
- **Gemini:** passes model names raw (e.g. `gemini-2.5-pro-preview-05-06`), so rate keys use `gemini:gemini-2.5-pro` (prefix match)

Types: `in` (input), `out` (output), `cache` (cache read), `think` (thinking/reasoning)

### Rate ordering

`__agent_stats_cost` iterates all entries and uses **last-match-wins** for each type. Therefore, **broader prefixes must come before narrower ones** in the array so that more-specific matches override general ones. For example:

```
claude:opus-4:in=15     # matches opus-4, opus-4-1, opus-4-5, opus-4-6
claude:opus-4-6:in=5    # overrides for opus-4-6 specifically
```

### Default rates (USD per MTok)

**Claude** (source: platform.claude.com/docs/en/about-claude/pricing)

Ordered broad→narrow so specific models override general ones:

| Rate key prefix | in | out | cache |
|---|---|---|---|
| `claude:3-haiku` | 0.25 | 1.25 | 0.03 |
| `claude:3-5-haiku` | 0.8 | 4 | 0.08 |
| `claude:3-7-sonnet` | 3 | 15 | 0.3 |
| `claude:sonnet-4` | 3 | 15 | 0.3 |
| `claude:sonnet-4-5` | 3 | 15 | 0.3 |
| `claude:sonnet-4-6` | 3 | 15 | 0.3 |
| `claude:opus-4` | 15 | 75 | 1.5 |
| `claude:opus-4-1` | 15 | 75 | 1.5 |
| `claude:opus-4-5` | 5 | 25 | 0.5 |
| `claude:opus-4-6` | 5 | 25 | 0.5 |
| `claude:haiku-4-5` | 1 | 5 | 0.1 |

**OpenAI / Codex** (source: openai.com/api/pricing)

| Rate key prefix | in | out | cache |
|---|---|---|---|
| `codex:o1` | 15 | 60 | 7.5 |
| `codex:o1-mini` | 1.1 | 4.4 | 0.55 |
| `codex:o1-pro` | 150 | 600 | — |
| `codex:o3` | 2 | 8 | 0.5 |
| `codex:o3-mini` | 1.1 | 4.4 | 0.55 |
| `codex:o3-pro` | 20 | 80 | — |
| `codex:o4-mini` | 1.1 | 4.4 | 0.275 |
| `codex:gpt-4o` | 2.5 | 10 | 1.25 |
| `codex:gpt-4o-mini` | 0.15 | 0.6 | 0.075 |
| `codex:gpt-4.1` | 2 | 8 | 0.5 |
| `codex:gpt-4.1-mini` | 0.4 | 1.6 | 0.1 |
| `codex:gpt-4.1-nano` | 0.1 | 0.4 | 0.025 |
| `codex:gpt-5` | 1.25 | 10 | 0.125 |
| `codex:gpt-5-codex` | 1.25 | 10 | 0.125 |
| `codex:gpt-5-mini` | 0.25 | 2 | 0.025 |
| `codex:gpt-5-nano` | 0.05 | 0.4 | 0.005 |
| `codex:gpt-5-pro` | 15 | 120 | — |
| `codex:gpt-5.1` | 1.25 | 10 | 0.125 |
| `codex:gpt-5.1-codex` | 1.25 | 10 | 0.125 |
| `codex:gpt-5.1-codex-max` | 1.25 | 10 | 0.125 |
| `codex:gpt-5.1-codex-mini` | 0.25 | 2 | 0.025 |
| `codex:gpt-5.2` | 1.75 | 14 | 0.175 |
| `codex:gpt-5.2-codex` | 1.75 | 14 | 0.175 |
| `codex:gpt-5.3-codex` | 1.75 | 14 | 0.175 |
| `codex:gpt-5.4` | 2.5 | 15 | 0.25 |
| `codex:gpt-5.4-mini` | 0.75 | 4.5 | 0.075 |
| `codex:gpt-5.4-nano` | 0.2 | 1.25 | 0.02 |
| `codex:gpt-5.4-pro` | 30 | 180 | — |
| `codex:codex-mini` | 1.5 | 6 | 0.375 |

**Gemini** (source: cloud.google.com/vertex-ai/generative-ai/pricing, standard tier, <=200K context)

| Rate key prefix | in | out | cache |
|---|---|---|---|
| `gemini:gemini-2.0-flash` | 0.15 | 0.6 | — |
| `gemini:gemini-2.0-flash-lite` | 0.075 | 0.3 | — |
| `gemini:gemini-2.5-flash` | 0.3 | 2.5 | 0.03 |
| `gemini:gemini-2.5-flash-lite` | 0.1 | 0.4 | 0.01 |
| `gemini:gemini-2.5-pro` | 1.25 | 10 | 0.13 |
| `gemini:gemini-3-flash` | 0.5 | 3 | 0.05 |
| `gemini:gemini-3-pro` | 2 | 12 | 0.2 |
| `gemini:gemini-3.1-flash-lite` | 0.25 | 1.5 | 0.03 |
| `gemini:gemini-3.1-pro` | 2 | 12 | 0.2 |

**Gemini thinking tokens:** Billed at the output rate by Google. The Gemini provider functions will fold thinking tokens into output tokens before calling `__agent_stats_cost`, keeping provider-specific billing logic inside the provider files. No `think` entries are needed in the Gemini rate table. The existing `gemini:gemini-2:think` and `gemini:gemini-3:think` entries in `conf.d/agent_stats.fish` will be removed as part of the migration.

## Files to modify

1. **New: `functions/__agent_stats_auth.fish`** — `__agent_stats_auth` function with per-provider detection + session caching
2. **New: `functions/__agent_stats_default_rates.fish`** — `__agent_stats_default_rates` function with versioned defaults
3. **Edit: `conf.d/agent_stats.fish`** — replace hardcoded rates block with `__agent_stats_default_rates` call; update uninstall handler to clean up new variables (`__agent_stats_rates_version`, `agent_stats_cost_rates_custom`, `__agent_stats_auth_*`)
4. **Edit: `functions/agent-stats.fish`** — `refresh` subcommand clears `__agent_stats_auth_*` cache globals
5. **Edit: `functions/__agent_stats_claude.fish`** — prompt function branches on `__agent_stats_auth claude`: API key users return `"TOKEN_COUNT MSG_COUNT apikey"` format; compact function shows token+cost display for API key users (today-only cost calculation)
6. **Edit: `functions/__agent_stats_codex.fish`** — same pattern as Claude: prompt returns sentinel format, compact shows tokens+cost
7. **Edit: `functions/__agent_stats_gemini.fish`** — compact function shows cost for API key users; fold thinking tokens into output before `__agent_stats_cost` calls; prompt already returns tokens so no format change needed
8. **Edit: `functions/__agent_stats_prompt.fish`** — detect `apikey` sentinel in third field for Claude/Codex, render formatted token count instead of rate limit percentage

## Non-goals

- Automatic rate refresh or pricing API calls — rates are hardcoded defaults updated with plugin releases.
- Detecting specific API key tiers or usage limits from the API providers.
- Changing the detailed mode layout — it already shows token breakdowns.
- `--on-variable` event handlers for env var changes — `refresh` subcommand is sufficient.
