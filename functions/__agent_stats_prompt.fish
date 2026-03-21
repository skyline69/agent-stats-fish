function __agent_stats_prompt --description "Right-prompt helper for agent-stats"
    # Bail early if no providers
    test (count $agent_stats_providers) -eq 0; and return

    set -l parts

    # Set default icons (first letter uppercase), then override from agent_stats_icons
    set -l icon_claude C
    set -l icon_codex X
    set -l icon_gemini G
    for entry in $agent_stats_icons
        set -l kv (string split "=" $entry)
        if test (count $kv) -eq 2
            switch $kv[1]
                case claude
                    set icon_claude $kv[2]
                case codex
                    set icon_codex $kv[2]
                case gemini
                    set icon_gemini $kv[2]
            end
        end
    end

    for provider in $agent_stats_providers
        set -l data (__agent_stats_cache $provider prompt $agent_stats_prompt_cache_ttl)

        switch $provider
            case claude
                # data format: "FIVE_HOUR SEVEN_DAY PLAN_NAME" or "TOKEN_COUNT MSG_COUNT apikey"
                set -l fields (string split " " $data)

                set -l segment
                if test "$fields[3]" = apikey
                    # API key user: show token count
                    set -l tokens $fields[1]
                    if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                        set segment (set_color e8590c)$icon_claude(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                    end
                else
                    # Account user: show rate limit percentage
                    set -l five_hour $fields[1]
                    if test "$five_hour" -ge 80 2>/dev/null
                        set segment (set_color e8590c)$icon_claude(set_color normal)" "(set_color brred)$five_hour"%"(set_color normal)
                    else if test "$five_hour" -ge 50 2>/dev/null
                        set segment (set_color e8590c)$icon_claude(set_color normal)" "(set_color bryellow)$five_hour"%"(set_color normal)
                    else
                        set segment (set_color e8590c)$icon_claude(set_color normal)" "(set_color green)$five_hour"%"(set_color normal)
                    end
                end

                if test -n "$segment"
                    set -a parts $segment
                end

            case codex
                # data format: "FIVE_HOUR SEVEN_DAY" or "TOKEN_COUNT MSG_COUNT apikey"
                set -l fields (string split " " $data)

                set -l segment
                if test "$fields[3]" = apikey
                    # API key user: show token count
                    set -l tokens $fields[1]
                    if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                        set segment (set_color brblue)$icon_codex(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                    end
                else
                    # Account user: show rate limit percentage
                    set -l five_hour $fields[1]
                    if test "$five_hour" -ge 80 2>/dev/null
                        set segment (set_color brblue)$icon_codex(set_color normal)" "(set_color brred)$five_hour"%"(set_color normal)
                    else if test "$five_hour" -ge 50 2>/dev/null
                        set segment (set_color brblue)$icon_codex(set_color normal)" "(set_color bryellow)$five_hour"%"(set_color normal)
                    else
                        set segment (set_color brblue)$icon_codex(set_color normal)" "(set_color green)$five_hour"%"(set_color normal)
                    end
                end

                if test -n "$segment"
                    set -a parts $segment
                end

            case gemini
                # data format: "TOKEN_COUNT MSG_COUNT"
                set -l fields (string split " " $data)
                set -l tokens $fields[1]

                if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                    set -a parts (set_color af5fff)$icon_gemini(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                end
        end
    end

    if test (count $parts) -gt 0
        printf "%s" (string join " " $parts)
    end
end
