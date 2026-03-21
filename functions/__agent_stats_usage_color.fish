function __agent_stats_usage_color --description "Set color based on usage percent"
    set -l percent $argv[1]
    set -l threshold (set -q agent_stats_alert_threshold; and echo $agent_stats_alert_threshold; or echo 80)
    if test "$percent" -ge "$threshold" 2>/dev/null
        set_color brred
    else if test "$percent" -ge 50 2>/dev/null
        set_color bryellow
    else
        set_color green
    end
end
