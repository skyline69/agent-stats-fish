function __agent_stats_cache --description "Cache layer for agent-stats providers"
    if test (count $argv) -lt 2
        echo "agent-stats: cache requires provider and mode" >&2
        return 1
    end

    set -l provider $argv[1]
    set -l mode $argv[2]
    set -l ttl $argv[3]

    if test -z "$ttl"
        set ttl (set -q agent_stats_cache_ttl; and echo $agent_stats_cache_ttl; or echo 300)
    end

    set -l cache_file /tmp/agent_stats_cache_{$provider}_{$mode}

    # Check if cache exists
    if test -f $cache_file
        set -l now (date +%s)
        set -l mtime (stat -f %m $cache_file 2>/dev/null; or stat -c %Y $cache_file 2>/dev/null)
        if test -n "$mtime"
            set -l age (math "$now - $mtime")

            # Fresh cache — return immediately
            if test "$age" -lt "$ttl"
                cat $cache_file
                return 0
            end

            # Stale cache — return stale data, refresh in background
            cat $cache_file
            __agent_stats_cache_refresh $provider $mode $cache_file &
            disown 2>/dev/null
            return 0
        end
    end

    # No cache at all — synchronous fetch (first run)
    # Show a loading message for non-prompt modes
    set -l show_loading false
    if test "$mode" != prompt; and isatty stderr
        set show_loading true
        function __agent_stats_cleanup --on-signal INT
            set -g __agent_stats_interrupted
            printf '\r\033[2K' >&2
            functions -e __agent_stats_cleanup
        end
        set -l provider_label (string sub -l 1 -- $provider | string upper)(string sub -s 2 -- $provider)
        printf '\r\033[2K  %sFetching %s data...%s' \
            (set_color --dim) $provider_label (set_color normal) >&2
    end

    set -l data
    switch $provider
        case claude
            set data (__agent_stats_claude $mode)
        case codex
            set data (__agent_stats_codex $mode)
        case gemini
            set data (__agent_stats_gemini $mode)
        case '*'
            if test "$show_loading" = true
                printf '\r\033[2K' >&2
                functions -e __agent_stats_cleanup
            end
            echo "agent-stats: unknown provider '$provider'" >&2
            return 1
    end

    if set -q __agent_stats_interrupted
        set -e __agent_stats_interrupted
        functions -e __agent_stats_cleanup
        return 130
    end

    if test "$show_loading" = true
        printf '\r\033[2K' >&2
        functions -e __agent_stats_cleanup
    end

    if test -n "$data"
        printf '%s\n' $data >$cache_file 2>/dev/null
    end
    printf '%s\n' $data
end
