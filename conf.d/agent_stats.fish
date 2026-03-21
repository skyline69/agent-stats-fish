# agent-stats: Claude Code & Codex usage stats for Fish shell
status is-interactive; or exit

# Default universal variables (only set if not already defined)
if not set -q agent_stats_providers
    set -U agent_stats_providers
end
if not set -q agent_stats_cache_ttl
    set -U agent_stats_cache_ttl 300
end
if not set -q agent_stats_prompt_cache_ttl
    set -U agent_stats_prompt_cache_ttl 30
end
if not set -q agent_stats_cost_rates
    set -U agent_stats_cost_rates \
        claude:haiku-4:in=0.80 claude:haiku-4:out=4 claude:haiku-4:cache=0.08 \
        claude:sonnet-4:in=3 claude:sonnet-4:out=15 claude:sonnet-4:cache=0.30 \
        claude:opus-4:in=15 claude:opus-4:out=75 claude:opus-4:cache=1.50 \
        codex:gpt-5:in=2.50 codex:gpt-5:out=10 codex:gpt-5:cache=0.625 codex:gpt-5:think=10 \
        gemini:gemini-2:in=1.25 gemini:gemini-2:out=10 gemini:gemini-2:cache=0.31 gemini:gemini-2:think=10 \
        gemini:gemini-3:in=1.25 gemini:gemini-3:out=10 gemini:gemini-3:cache=0.31 gemini:gemini-3:think=10
end
if not set -q agent_stats_cost_currency
    set -U agent_stats_cost_currency USD
end
if not set -q agent_stats_icons
    set -U agent_stats_icons claude= codex=⬡ gemini=󰫣
end

# Check for jq dependency
if not command -q jq
    echo (set_color brred)"agent-stats"(set_color normal)": "(set_color --bold)"jq"(set_color normal)" is required but not found. Install it with your package manager." >&2
end

# Fisher install event
function _agent_stats_install --on-event agent_stats_install
    echo (set_color brgreen)"✓"(set_color normal)" "(set_color --bold)"agent-stats"(set_color normal)" installed! Enable providers with: "(set_color --underline)"agent-stats enable claude|codex|gemini"(set_color normal)
    echo "  Customize icons: "(set_color --dim)"set -U agent_stats_icons claude= codex=⬡ gemini=󰫣"(set_color normal)
    if command -q starship
        echo
        echo (set_color bryellow)"Starship detected"(set_color normal)" — if you use Starship, add agent-stats as a custom module."
        echo "  Add this to "(set_color --underline)"~/.config/starship.toml"(set_color normal)":"
        echo
        echo (set_color --dim)"  [custom.agent_stats]"
        echo "  command = \"fish -c '__agent_stats_prompt'\""
        echo "  when = \"fish -c 'test (count \$agent_stats_providers) -gt 0'\""
        echo "  format = \"\$output\""
        echo "  shell = [\"bash\"]"(set_color normal)
    end
end

# Fisher uninstall event
function _agent_stats_uninstall --on-event agent_stats_uninstall
    set -e agent_stats_providers
    set -e agent_stats_cache_ttl
    set -e agent_stats_prompt_cache_ttl
    set -e agent_stats_icons
    set -e agent_stats_cost_rates
    set -e agent_stats_cost_currency
    for f in /tmp/agent_stats_cache_*
        rm -f $f 2>/dev/null
    end
end
