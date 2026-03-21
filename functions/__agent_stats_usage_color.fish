function __agent_stats_usage_color --description "Set color based on usage percent"
    set -l percent $argv[1]
    if test "$percent" -ge 80 2>/dev/null
        set_color brred
    else if test "$percent" -ge 50 2>/dev/null
        set_color bryellow
    else
        set_color green
    end
end
