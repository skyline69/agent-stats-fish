function __agent_stats_cache_refresh --description "Background cache refresh for agent-stats"
    set -l provider $argv[1]
    set -l mode $argv[2]
    set -l cache_file $argv[3]

    # PID lockfile: only one refresh per provider+mode at a time
    set -l lock_file /tmp/agent_stats_lock_{$provider}_{$mode}
    if test -f $lock_file
        set -l lock_pid (cat $lock_file 2>/dev/null)
        # If the locked process is still running, skip this refresh
        if test -n "$lock_pid"; and kill -0 $lock_pid 2>/dev/null
            return 0
        end
        # Stale lock from a dead process — clean up
        rm -f $lock_file
    end
    echo %self >$lock_file 2>/dev/null

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
        set -l tmp (mktemp $cache_file.XXXXXX 2>/dev/null)
        and printf '%s\n' $data >$tmp 2>/dev/null
        and command mv -f $tmp $cache_file 2>/dev/null
        or rm -f $tmp 2>/dev/null
    end

    rm -f $lock_file
end
