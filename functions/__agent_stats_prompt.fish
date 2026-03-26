function __agent_stats_prompt --description "Right-prompt helper for agent-stats"
    # Bail early if no providers
    test (count $agent_stats_providers) -eq 0; and return

    set -l parts

    # Cache parsed icons — only re-parse when agent_stats_icons changes
    if test "$__agent_stats_icons_src" != "$agent_stats_icons"
        set -g __agent_stats_icons_src $agent_stats_icons
        set -g __agent_stats_icon_claude C
        set -g __agent_stats_icon_codex X
        set -g __agent_stats_icon_gemini G
        # Normalize: handle both list ("a=1" "b=2") and single-string ("a=1 b=2") formats
        set -l entries
        for entry in $agent_stats_icons
            for sub in (string split " " $entry)
                test -n "$sub"; and set -a entries $sub
            end
        end
        for entry in $entries
            set -l kv (string split -m 1 "=" $entry)
            if test (count $kv) -eq 2; and test -n "$kv[2]"
                switch $kv[1]
                    case claude
                        set -g __agent_stats_icon_claude $kv[2]
                    case codex
                        set -g __agent_stats_icon_codex $kv[2]
                    case gemini
                        set -g __agent_stats_icon_gemini $kv[2]
                end
            end
        end
    end

    for provider in $agent_stats_providers
        set -l data

        # Claude HUD fast path: read the claude-hud cache directly (~1ms) to
        # bypass the cache layer entirely.  Only jq-parse when the file changes
        # (mtime-based check using builtins — zero forks on cache hit).
        # Falls through to the normal cache/API path if HUD cache is stale (> 60s).
        if test "$provider" = claude
            set -l hud_cache ~/.claude/plugins/claude-hud/.usage-cache.json
            if test -f $hud_cache
                set -l hud_mtime (path mtime -- $hud_cache 2>/dev/null)
                if test -n "$hud_mtime"
                    set -l hud_age (math "$EPOCHSECONDS - $hud_mtime")
                    if test "$hud_age" -lt 60
                        if test "$hud_mtime" != "$__agent_stats_hud_mtime"
                            set -g __agent_stats_hud_mtime $hud_mtime
                            set -g __agent_stats_hud_data (jq -r '
                                (.lastGoodData // .data) |
                                "\(.fiveHour // 0 | round) \(.sevenDay // 0 | round) \(.planName // "Unknown")"
                            ' $hud_cache 2>/dev/null)
                        end
                        if test -n "$__agent_stats_hud_data"
                            set data $__agent_stats_hud_data
                        end
                    end
                end
            end
        end

        # Fall back to cache layer if no fast-path data available
        if test -z "$data"
            set data (__agent_stats_cache $provider prompt $agent_stats_prompt_cache_ttl)
        end

        switch $provider
            case claude
                # data format: "FIVE_HOUR SEVEN_DAY PLAN_NAME" or "TOKEN_COUNT MSG_COUNT apikey"
                set -l fields (string split " " $data)

                set -l segment
                if test "$fields[3]" = apikey
                    set -l tokens $fields[1]
                    if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                        set segment (set_color e8590c)$__agent_stats_icon_claude(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                    end
                else
                    set -l five_hour $fields[1]
                    set -l alert (set -q agent_stats_alert_threshold; and echo $agent_stats_alert_threshold; or echo 80)
                    set -l warn ""
                    if test "$five_hour" -ge "$alert" 2>/dev/null
                        set warn (set_color brred --bold)"⚠ "(set_color normal)
                        set segment $warn(set_color e8590c)$__agent_stats_icon_claude(set_color normal)" "(set_color brred --bold)$five_hour"%"(set_color normal)
                    else if test "$five_hour" -ge 50 2>/dev/null
                        set segment (set_color e8590c)$__agent_stats_icon_claude(set_color normal)" "(set_color bryellow)$five_hour"%"(set_color normal)
                    else
                        set segment (set_color e8590c)$__agent_stats_icon_claude(set_color normal)" "(set_color green)$five_hour"%"(set_color normal)
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
                    set -l tokens $fields[1]
                    if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                        set segment (set_color brblue)$__agent_stats_icon_codex(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                    end
                else
                    set -l five_hour $fields[1]
                    set -l alert (set -q agent_stats_alert_threshold; and echo $agent_stats_alert_threshold; or echo 80)
                    if test "$five_hour" -ge "$alert" 2>/dev/null
                        set segment (set_color brred --bold)"⚠ "(set_color normal)(set_color brblue)$__agent_stats_icon_codex(set_color normal)" "(set_color brred --bold)$five_hour"%"(set_color normal)
                    else if test "$five_hour" -ge 50 2>/dev/null
                        set segment (set_color brblue)$__agent_stats_icon_codex(set_color normal)" "(set_color bryellow)$five_hour"%"(set_color normal)
                    else
                        set segment (set_color brblue)$__agent_stats_icon_codex(set_color normal)" "(set_color green)$five_hour"%"(set_color normal)
                    end
                end

                if test -n "$segment"
                    set -a parts $segment
                end

            case gemini
                set -l fields (string split " " $data)
                set -l tokens $fields[1]

                if test "$tokens" != "0" 2>/dev/null; and test "$tokens" -gt 0 2>/dev/null
                    set -a parts (set_color af5fff)$__agent_stats_icon_gemini(set_color normal)" "(set_color bryellow)(__agent_stats_format tokens $tokens)(set_color normal)
                end
        end
    end

    if test (count $parts) -gt 0
        printf "%s" (string join " " $parts)
    end
end
