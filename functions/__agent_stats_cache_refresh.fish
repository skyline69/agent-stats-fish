function __agent_stats_cache_refresh --description "Background cache refresh for agent-stats"
    set -l provider $argv[1]
    set -l mode $argv[2]
    set -l cache_file $argv[3]

    set -l data
    switch $provider
        case claude
            set data (__agent_stats_claude $mode)
        case codex
            set data (__agent_stats_codex $mode)
        case gemini
            set data (__agent_stats_gemini $mode)
    end

    if test -n "$data"
        printf '%s\n' $data >$cache_file 2>/dev/null
    end
end
