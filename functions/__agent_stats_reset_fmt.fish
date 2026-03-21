function __agent_stats_reset_fmt --description "Format reset time as relative duration"
    set -l reset_at $argv[1]
    if test -z "$reset_at" -o "$reset_at" = "null" -o "$reset_at" = ""
        return
    end

    # Support both Unix epoch (pure digits) and ISO date strings
    set -l reset_epoch
    if string match -qr '^\d+$' -- "$reset_at"
        set reset_epoch $reset_at
    else
        set reset_epoch (date -d "$reset_at" +%s 2>/dev/null)
    end
    if test -z "$reset_epoch"
        return
    end

    set -l now (date +%s)
    set -l diff (math "$reset_epoch - $now")
    if test $diff -le 0
        return
    end

    set -l mins (math "ceil($diff / 60)")
    if test $mins -lt 60
        printf "%dm" $mins
    else
        set -l hours (math "floor($mins / 60)")
        set -l rem_mins (math "$mins % 60")
        if test $hours -ge 24
            set -l days (math "floor($hours / 24)")
            set -l rem_hours (math "$hours % 24")
            if test $rem_hours -gt 0
                printf "%dd %dh" $days $rem_hours
            else
                printf "%dd" $days
            end
        else
            if test $rem_mins -gt 0
                printf "%dh %dm" $hours $rem_mins
            else
                printf "%dh" $hours
            end
        end
    end
end
