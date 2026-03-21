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
end

# Fisher uninstall event
function _agent_stats_uninstall --on-event agent_stats_uninstall
    set -e agent_stats_providers
    set -e agent_stats_cache_ttl
    set -e agent_stats_prompt_cache_ttl
    set -e agent_stats_icons
    for f in /tmp/agent_stats_cache_*
        rm -f $f 2>/dev/null
    end
end
