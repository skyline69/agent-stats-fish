function __agent_stats_bar --description "Render a 10-char progress bar with color"
    set -l percent $argv[1]
    set -l width 10

    test -z "$percent" -o "$percent" = null; and set percent 0

    set -l filled (math "round($percent * $width / 100)")
    set -l empty (math "$width - $filled")

    __agent_stats_usage_color $percent

    set -l bar ""
    if test $filled -gt 0
        for i in (seq 1 $filled)
            set bar $bar"█"
        end
    end
    if test $empty -gt 0
        for i in (seq 1 $empty)
            set bar $bar"░"
        end
    end
    printf "%s" $bar
    set_color normal
end
