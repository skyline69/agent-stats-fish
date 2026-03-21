function __agent_stats_default_rates --description "Set default API pricing rates for agent-stats cost estimation"
    set -l rates_ver "2026-03-21-v1"

    # Skip if already up to date and rates exist
    if test "$__agent_stats_rates_version" = "$rates_ver"; and test (count $agent_stats_cost_rates) -gt 0
        return
    end

    # Skip if user has custom rates
    if test "$agent_stats_cost_rates_custom" = true
        return
    end

    # Rate format: provider:model_prefix:type=rate (USD per MTok)
    # Types: in=input, out=output, cache=cache read, think=thinking/reasoning
    # Ordering matters: broader prefixes MUST come before narrower ones (last match wins)

    set -U agent_stats_cost_rates \
        # --- Claude (platform.claude.com/docs/en/about-claude/pricing) ---
        claude:3-haiku:in=0.25 \
        claude:3-haiku:out=1.25 \
        claude:3-haiku:cache=0.03 \
        claude:3-5-haiku:in=0.8 \
        claude:3-5-haiku:out=4 \
        claude:3-5-haiku:cache=0.08 \
        claude:3-7-sonnet:in=3 \
        claude:3-7-sonnet:out=15 \
        claude:3-7-sonnet:cache=0.3 \
        claude:sonnet-4:in=3 \
        claude:sonnet-4:out=15 \
        claude:sonnet-4:cache=0.3 \
        claude:sonnet-4-5:in=3 \
        claude:sonnet-4-5:out=15 \
        claude:sonnet-4-5:cache=0.3 \
        claude:sonnet-4-6:in=3 \
        claude:sonnet-4-6:out=15 \
        claude:sonnet-4-6:cache=0.3 \
        claude:opus-4:in=15 \
        claude:opus-4:out=75 \
        claude:opus-4:cache=1.5 \
        claude:opus-4-1:in=15 \
        claude:opus-4-1:out=75 \
        claude:opus-4-1:cache=1.5 \
        claude:opus-4-5:in=5 \
        claude:opus-4-5:out=25 \
        claude:opus-4-5:cache=0.5 \
        claude:opus-4-6:in=5 \
        claude:opus-4-6:out=25 \
        claude:opus-4-6:cache=0.5 \
        claude:haiku-4-5:in=1 \
        claude:haiku-4-5:out=5 \
        claude:haiku-4-5:cache=0.1 \
        # --- Codex / OpenAI (openai.com/api/pricing) ---
        codex:o1:in=15 \
        codex:o1:out=60 \
        codex:o1:cache=7.5 \
        codex:o1-mini:in=1.1 \
        codex:o1-mini:out=4.4 \
        codex:o1-mini:cache=0.55 \
        codex:o1-pro:in=150 \
        codex:o1-pro:out=600 \
        codex:o3:in=2 \
        codex:o3:out=8 \
        codex:o3:cache=0.5 \
        codex:o3-mini:in=1.1 \
        codex:o3-mini:out=4.4 \
        codex:o3-mini:cache=0.55 \
        codex:o3-pro:in=20 \
        codex:o3-pro:out=80 \
        codex:o4-mini:in=1.1 \
        codex:o4-mini:out=4.4 \
        codex:o4-mini:cache=0.275 \
        codex:gpt-4o:in=2.5 \
        codex:gpt-4o:out=10 \
        codex:gpt-4o:cache=1.25 \
        codex:gpt-4o-mini:in=0.15 \
        codex:gpt-4o-mini:out=0.6 \
        codex:gpt-4o-mini:cache=0.075 \
        codex:gpt-4.1:in=2 \
        codex:gpt-4.1:out=8 \
        codex:gpt-4.1:cache=0.5 \
        codex:gpt-4.1-mini:in=0.4 \
        codex:gpt-4.1-mini:out=1.6 \
        codex:gpt-4.1-mini:cache=0.1 \
        codex:gpt-4.1-nano:in=0.1 \
        codex:gpt-4.1-nano:out=0.4 \
        codex:gpt-4.1-nano:cache=0.025 \
        codex:gpt-5:in=1.25 \
        codex:gpt-5:out=10 \
        codex:gpt-5:cache=0.125 \
        codex:gpt-5-codex:in=1.25 \
        codex:gpt-5-codex:out=10 \
        codex:gpt-5-codex:cache=0.125 \
        codex:gpt-5-mini:in=0.25 \
        codex:gpt-5-mini:out=2 \
        codex:gpt-5-mini:cache=0.025 \
        codex:gpt-5-nano:in=0.05 \
        codex:gpt-5-nano:out=0.4 \
        codex:gpt-5-nano:cache=0.005 \
        codex:gpt-5-pro:in=15 \
        codex:gpt-5-pro:out=120 \
        codex:gpt-5.1:in=1.25 \
        codex:gpt-5.1:out=10 \
        codex:gpt-5.1:cache=0.125 \
        codex:gpt-5.1-codex:in=1.25 \
        codex:gpt-5.1-codex:out=10 \
        codex:gpt-5.1-codex:cache=0.125 \
        codex:gpt-5.1-codex-max:in=1.25 \
        codex:gpt-5.1-codex-max:out=10 \
        codex:gpt-5.1-codex-max:cache=0.125 \
        codex:gpt-5.1-codex-mini:in=0.25 \
        codex:gpt-5.1-codex-mini:out=2 \
        codex:gpt-5.1-codex-mini:cache=0.025 \
        codex:gpt-5.2:in=1.75 \
        codex:gpt-5.2:out=14 \
        codex:gpt-5.2:cache=0.175 \
        codex:gpt-5.2-codex:in=1.75 \
        codex:gpt-5.2-codex:out=14 \
        codex:gpt-5.2-codex:cache=0.175 \
        codex:gpt-5.3-codex:in=1.75 \
        codex:gpt-5.3-codex:out=14 \
        codex:gpt-5.3-codex:cache=0.175 \
        codex:gpt-5.4:in=2.5 \
        codex:gpt-5.4:out=15 \
        codex:gpt-5.4:cache=0.25 \
        codex:gpt-5.4-mini:in=0.75 \
        codex:gpt-5.4-mini:out=4.5 \
        codex:gpt-5.4-mini:cache=0.075 \
        codex:gpt-5.4-nano:in=0.2 \
        codex:gpt-5.4-nano:out=1.25 \
        codex:gpt-5.4-nano:cache=0.02 \
        codex:gpt-5.4-pro:in=30 \
        codex:gpt-5.4-pro:out=180 \
        codex:codex-mini:in=1.5 \
        codex:codex-mini:out=6 \
        codex:codex-mini:cache=0.375 \
        # --- Gemini (cloud.google.com/vertex-ai/generative-ai/pricing, standard tier, <=200K) ---
        # Note: No think entries - Gemini thinking tokens are folded into output by provider functions
        gemini:gemini-2.0-flash:in=0.15 \
        gemini:gemini-2.0-flash:out=0.6 \
        gemini:gemini-2.0-flash-lite:in=0.075 \
        gemini:gemini-2.0-flash-lite:out=0.3 \
        gemini:gemini-2.5-flash:in=0.3 \
        gemini:gemini-2.5-flash:out=2.5 \
        gemini:gemini-2.5-flash:cache=0.03 \
        gemini:gemini-2.5-flash-lite:in=0.1 \
        gemini:gemini-2.5-flash-lite:out=0.4 \
        gemini:gemini-2.5-flash-lite:cache=0.01 \
        gemini:gemini-2.5-pro:in=1.25 \
        gemini:gemini-2.5-pro:out=10 \
        gemini:gemini-2.5-pro:cache=0.13 \
        gemini:gemini-3-flash:in=0.5 \
        gemini:gemini-3-flash:out=3 \
        gemini:gemini-3-flash:cache=0.05 \
        gemini:gemini-3-pro:in=2 \
        gemini:gemini-3-pro:out=12 \
        gemini:gemini-3-pro:cache=0.2 \
        gemini:gemini-3.1-flash-lite:in=0.25 \
        gemini:gemini-3.1-flash-lite:out=1.5 \
        gemini:gemini-3.1-flash-lite:cache=0.03 \
        gemini:gemini-3.1-pro:in=2 \
        gemini:gemini-3.1-pro:out=12 \
        gemini:gemini-3.1-pro:cache=0.2

    set -U __agent_stats_rates_version $rates_ver
end
