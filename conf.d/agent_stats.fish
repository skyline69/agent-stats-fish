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
    set -U agent_stats_prompt_cache_ttl 10
end
__agent_stats_default_rates
if not set -q agent_stats_cost_currency
    set -U agent_stats_cost_currency USD
end
if not set -q agent_stats_alert_threshold
    set -U agent_stats_alert_threshold 80
end
if not set -q agent_stats_icons
    set -U agent_stats_icons claude= codex=⬡ gemini=󰫣
end

# Check for jq dependency
if not command -q jq
    echo (set_color brred)"agent-stats"(set_color normal)": "(set_color --bold)"jq"(set_color normal)" is required but not found. Install it with your package manager." >&2
end

# Register as a Tide right-prompt item when Tide is active.
# Tide's fish_prompt.fish rewrites fish_right_prompt at startup via eval, so
# the functions/fish_right_prompt.fish file is never called in interactive
# shells that use Tide. The correct integration is to register a
# _tide_item_agent_stats function and add it to tide_right_prompt_items.
if functions -q _tide_print_item
    # Set Tide color variables for the item (transparent background, normal color
    # baseline — __agent_stats_prompt embeds its own ANSI color codes).
    set -q tide_agent_stats_bg_color; or set -U tide_agent_stats_bg_color normal
    set -q tide_agent_stats_color; or set -U tide_agent_stats_color normal
    # Ensure same-color items are separated by a space (tide's default is empty,
    # which causes adjacent items like node version and time to concatenate).
    if test -z "$tide_right_prompt_separator_same_color"
        set -U tide_right_prompt_separator_same_color ' '
    end
    if not contains agent_stats $tide_right_prompt_items
        set -U tide_right_prompt_items $tide_right_prompt_items agent_stats
        functions -q tide; and tide reload 2>/dev/null
    end
end

# Fisher install event
function _agent_stats_install --on-event agent_stats_install
    echo (set_color brgreen)"✓"(set_color normal)" "(set_color --bold)"agent-stats"(set_color normal)" installed! Enable providers with: "(set_color --underline)"agent-stats enable claude|codex|gemini"(set_color normal)
    echo "  Customize icons: "(set_color --dim)"set -U agent_stats_icons claude= codex=⬡ gemini=󰫣"(set_color normal)
    if functions -q _tide_print_item
        echo
        echo (set_color brgreen)"Tide detected"(set_color normal)" — agent-stats added to tide_right_prompt_items automatically."
    else if command -q starship
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
    # Remove from Tide items list and clean up Tide color variables
    if set -q tide_right_prompt_items
        set -U tide_right_prompt_items (string match -v agent_stats $tide_right_prompt_items)
    end
    set -eU tide_agent_stats_bg_color 2>/dev/null
    set -eU tide_agent_stats_color 2>/dev/null
    set -e agent_stats_providers
    set -e agent_stats_cache_ttl
    set -e agent_stats_prompt_cache_ttl
    set -e agent_stats_icons
    set -e agent_stats_cost_rates
    set -e agent_stats_cost_rates_custom
    set -e agent_stats_cost_currency
    set -e agent_stats_alert_threshold
    set -e __agent_stats_rates_version
    set -e __agent_stats_auth_claude
    set -e __agent_stats_auth_codex
    set -e __agent_stats_auth_gemini
    for f in /tmp/agent_stats_cache_* /tmp/agent_stats_refreshing_*
        rm -f $f 2>/dev/null
    end
end

# Proactive cache pre-warming: refresh stale prompt caches after each command
# so data is fresh by the next prompt render. Must be defined here (not in
# functions/) because fish only autoloads functions called by name — event
# handlers need explicit registration at startup.
function __agent_stats_postexec --on-event fish_postexec
    test (count $agent_stats_providers) -eq 0; and return

    set -l ttl (set -q agent_stats_prompt_cache_ttl; and echo $agent_stats_prompt_cache_ttl; or echo 10)

    for provider in $agent_stats_providers
        set -l cache_file /tmp/agent_stats_cache_{$provider}_prompt

        # Skip if a refresh is already running for this provider
        set -l lock /tmp/agent_stats_refreshing_{$provider}
        if test -f $lock
            set -l lock_pid (cat $lock 2>/dev/null)
            if test -n "$lock_pid"; and kill -0 $lock_pid 2>/dev/null
                continue
            end
            rm -f $lock 2>/dev/null
        end

        # Skip if cache is fresh enough (more than 5s of TTL remaining)
        if test -f $cache_file
            set -l mtime (path mtime -- $cache_file 2>/dev/null)
            if test -n "$mtime"
                set -l age (math "$EPOCHSECONDS - $mtime")
                test "$age" -lt (math "$ttl - 5"); and continue
            end
        end

        # Background refresh with PID lock
        fish -c "
            echo %self > /tmp/agent_stats_refreshing_$provider
            __agent_stats_cache_refresh $provider prompt /tmp/agent_stats_cache_{$provider}_prompt
            rm -f /tmp/agent_stats_refreshing_$provider 2>/dev/null
        " &
        disown 2>/dev/null
    end
end
