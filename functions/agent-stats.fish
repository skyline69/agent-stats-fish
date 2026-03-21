function agent-stats --description "Display Claude Code, Codex & Gemini usage stats"
    # Parse flags first, before subcommand handling
    argparse h/help d/detailed -- $argv 2>/dev/null
    or begin
        echo (set_color brred)"error"(set_color normal)": invalid option. See "(set_color --underline)"agent-stats --help"(set_color normal) >&2
        return 1
    end

    if set -q _flag_help
        set_color --bold
        printf "Usage: "
        set_color normal
        printf "agent-stats "
        set_color --dim
        printf "[options] [command]"
        set_color normal
        echo
        echo

        set_color --bold --underline
        printf "Commands"
        set_color normal
        echo
        printf "  "
        set_color brgreen
        printf "enable"
        set_color normal
        set_color --dim
        printf " <provider>"
        set_color normal
        printf "   Enable a provider (claude, codex, gemini)\n"
        printf "  "
        set_color brgreen
        printf "disable"
        set_color normal
        set_color --dim
        printf " <provider>"
        set_color normal
        printf "  Disable a provider\n"
        printf "  "
        set_color brgreen
        printf "providers"
        set_color normal
        printf "             List enabled providers\n"
        printf "  "
        set_color brgreen
        printf "refresh"
        set_color normal
        printf "               Clear cache and re-display\n"
        printf "  "
        set_color brgreen
        printf "cost"
        set_color normal
        set_color --dim
        printf " [provider]"
        set_color normal
        printf "     Show estimated API costs\n"
        echo

        set_color --bold --underline
        printf "Options"
        set_color normal
        echo
        printf "  "
        set_color bryellow
        printf "-d"
        set_color normal
        printf ", "
        set_color bryellow
        printf "--detailed"
        set_color normal
        printf "      Show detailed stats with daily breakdown\n"
        printf "  "
        set_color bryellow
        printf "-h"
        set_color normal
        printf ", "
        set_color bryellow
        printf "--help"
        set_color normal
        printf "          Show this help\n"
        echo

        set_color --bold --underline
        printf "Configuration"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_providers"
        set_color normal
        printf "         Enabled providers (universal var)\n"
        printf "  "
        set_color brblue
        printf "agent_stats_cache_ttl"
        set_color normal
        printf "         Cache TTL in seconds "
        set_color --dim
        printf "(default: 300)"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_prompt_cache_ttl"
        set_color normal
        printf "   Prompt cache TTL "
        set_color --dim
        printf "(default: 30)"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_icons"
        set_color normal
        printf "             Provider icons "
        set_color --dim
        printf "(e.g. claude= codex=⬡ gemini=󰫣)"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_cost_rates"
        set_color normal
        printf "        Token rates per MTok "
        set_color --dim
        printf "(provider:model:type=rate)"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_cost_rates_custom"
        set_color normal
        printf "  Set to 'true' to keep custom rates "
        set_color --dim
        printf "(prevents override on update)"
        set_color normal
        echo
        printf "  "
        set_color brblue
        printf "agent_stats_cost_currency"
        set_color normal
        printf "     Currency code "
        set_color --dim
        printf "(default: USD)"
        set_color normal
        echo
        return 0
    end

    # Handle subcommands
    if set -q argv[1]
        switch $argv[1]
            case enable
                if test (count $argv) -lt 2
                    echo (set_color brred)"error"(set_color normal)": usage: "(set_color --dim)"agent-stats enable <claude|codex|gemini>"(set_color normal) >&2
                    return 1
                end
                if test (count $argv) -gt 2
                    echo (set_color brred)"error"(set_color normal)": too many arguments" >&2
                    return 1
                end
                set -l provider $argv[2]
                if not contains -- $provider claude codex gemini
                    echo (set_color brred)"error"(set_color normal)": unknown provider '"(set_color bryellow)$provider(set_color normal)"' (available: claude, codex, gemini)" >&2
                    return 1
                end
                if contains -- $provider $agent_stats_providers
                    echo (set_color bryellow)$provider(set_color normal)" is already enabled"
                    return 0
                end
                set -U agent_stats_providers $agent_stats_providers $provider
                echo (set_color brgreen)"✓"(set_color normal)" Enabled "(set_color --bold)$provider(set_color normal)
                return 0

            case disable
                if test (count $argv) -lt 2
                    echo (set_color brred)"error"(set_color normal)": usage: "(set_color --dim)"agent-stats disable <provider>"(set_color normal) >&2
                    return 1
                end
                if test (count $argv) -gt 2
                    echo (set_color brred)"error"(set_color normal)": too many arguments" >&2
                    return 1
                end
                set -l provider $argv[2]
                if not contains -- $provider claude codex gemini
                    echo (set_color brred)"error"(set_color normal)": unknown provider '"(set_color bryellow)$provider(set_color normal)"' (available: claude, codex, gemini)" >&2
                    return 1
                end
                if not contains -- $provider $agent_stats_providers
                    echo (set_color bryellow)$provider(set_color normal)" is not enabled"
                    return 0
                end
                set -l new_providers
                for p in $agent_stats_providers
                    if test "$p" != "$provider"
                        set -a new_providers $p
                    end
                end
                set -U agent_stats_providers $new_providers
                for f in /tmp/agent_stats_cache_{$provider}_*
                    rm -f $f 2>/dev/null
                end
                echo (set_color brred)"✗"(set_color normal)" Disabled "(set_color --bold)$provider(set_color normal)
                return 0

            case providers
                if test (count $argv) -gt 1
                    echo (set_color brred)"error"(set_color normal)": takes no arguments" >&2
                    return 1
                end
                if test (count $agent_stats_providers) -eq 0
                    echo "No providers enabled. Use: "(set_color --underline)"agent-stats enable <claude|codex|gemini>"(set_color normal)
                else
                    printf "Enabled: "
                    set -l colored
                    for p in $agent_stats_providers
                        set -a colored (set_color --bold)$p(set_color normal)
                    end
                    echo (string join ", " $colored)
                end
                return 0

            case refresh
                if test (count $argv) -gt 1
                    echo (set_color brred)"error"(set_color normal)": takes no arguments" >&2
                    return 1
                end
                for f in /tmp/agent_stats_cache_*
                    rm -f $f 2>/dev/null
                end
                set -e __agent_stats_auth_claude
                set -e __agent_stats_auth_codex
                set -e __agent_stats_auth_gemini
                # Fall through to display

            case cost
                if test (count $agent_stats_cost_rates) -eq 0
                    echo "No cost rates configured. Set rates with:" >&2
                    echo "  "(set_color --dim)"set -U agent_stats_cost_rates claude:sonnet-4:in=3 claude:sonnet-4:out=15 ..."(set_color normal) >&2
                    echo "See: "(set_color --underline)"agent-stats --help"(set_color normal) >&2
                    return 1
                end
                if test (count $agent_stats_providers) -eq 0
                    echo "No providers enabled. Use: "(set_color --underline)"agent-stats enable <claude|codex|gemini>"(set_color normal)
                    return 0
                end
                set -l cost_providers $agent_stats_providers
                if set -q argv[2]
                    if not contains -- $argv[2] claude codex gemini
                        echo (set_color brred)"error"(set_color normal)": unknown provider '"(set_color bryellow)$argv[2](set_color normal)"' (available: claude, codex, gemini)" >&2
                        return 1
                    end
                    set cost_providers $argv[2]
                end
                for provider in $cost_providers
                    __agent_stats_cache $provider cost
                    if test $status -eq 130
                        return 130
                    end
                end
                return 0

            case '-*'
                echo (set_color brred)"error"(set_color normal)": unknown option '"(set_color bryellow)$argv[1](set_color normal)"'. See "(set_color --underline)"agent-stats --help"(set_color normal) >&2
                return 1

            case '*'
                echo (set_color brred)"error"(set_color normal)": unknown command '"(set_color bryellow)$argv[1](set_color normal)"'. See "(set_color --underline)"agent-stats --help"(set_color normal) >&2
                return 1
        end
    end

    # Flags shouldn't be combined with subcommands (except refresh)
    if set -q _flag_detailed; and set -q argv[1]; and test "$argv[1]" != refresh
        echo (set_color brred)"error"(set_color normal)": --detailed cannot be used with subcommands" >&2
        return 1
    end

    # Check providers
    if test (count $agent_stats_providers) -eq 0
        echo "No providers enabled. Use: "(set_color --underline)"agent-stats enable <claude|codex|gemini>"(set_color normal)
        return 0
    end

    # Display stats
    set -l mode compact
    if set -q _flag_detailed
        set mode detailed
    end

    for provider in $agent_stats_providers
        __agent_stats_cache $provider $mode
        if test $status -eq 130
            return 130
        end
    end
end
