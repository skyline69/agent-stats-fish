function __agent_stats_gemini --description "Gemini CLI data provider for agent-stats"
    set -l mode $argv[1]
    test -z "$mode"; and set mode compact

    set -l gemini_dir ~/.gemini/tmp

    if not test -d $gemini_dir
        switch $mode
            case prompt
                echo "0 0"
            case compact
                set_color af5fff
                printf "Gemini"
                set_color normal
                set_color --dim
                printf ": no data directory"
                set_color normal
                echo
            case detailed
                set_color af5fff --bold
                printf "Gemini"
                set_color normal
                set_color --dim
                printf " (~/.gemini/tmp not found)"
                set_color normal
                echo
        end
        return
    end

    set -l today (date +%Y-%m-%d)

    switch $mode
        case prompt
            __agent_stats_gemini_prompt $gemini_dir $today
        case compact
            __agent_stats_gemini_compact $gemini_dir $today
        case detailed
            __agent_stats_gemini_detailed $gemini_dir $today
    end
end

function __agent_stats_gemini_prompt
    set -l gemini_dir $argv[1]
    set -l today $argv[2]

    # Get today's token and message totals from session files
    set -l chat_files (find $gemini_dir -name 'session-*.json' 2>/dev/null)
    if test -z "$chat_files"
        echo "0 0"
        return
    end

    set -l result (cat $chat_files 2>/dev/null | jq -s -r --arg today $today '
        [.[] | select(.startTime[:10] == $today)] |
        {
            tokens: ([.[].messages[] | select(.tokens) | .tokens.total // 0] | add // 0),
            msgs: ([.[].messages[] | select(.type == "user")] | length)
        } | "\(.tokens) \(.msgs)"
    ' 2>/dev/null)

    if test -n "$result"
        echo $result
    else
        echo "0 0"
    end
end

function __agent_stats_gemini_compact
    set -l gemini_dir $argv[1]
    set -l today $argv[2]

    # Get today's token total from session files
    set -l chat_files (find $gemini_dir -name 'session-*.json' 2>/dev/null)
    set -l today_tokens 0
    set -l today_msgs 0
    set -l today_model ""

    if test -n "$chat_files"
        set -l compact_data (cat $chat_files 2>/dev/null | jq -s -r --arg today $today '
            [.[] | select(.startTime[:10] == $today)] |
            {
                tokens: ([.[].messages[] | select(.tokens) | .tokens.total // 0] | add // 0),
                msgs: ([.[].messages[] | select(.type == "user")] | length),
                model: ([.[].messages[] | select(.model) | .model] | last // "")
            } | "\(.tokens) \(.msgs) \(.model)"
        ' 2>/dev/null)
        if test -n "$compact_data"
            set -l p (string split " " $compact_data)
            set today_tokens $p[1]
            set today_msgs $p[2]
            if test (count $p) -ge 3
                set today_model $p[3]
            end
        end
    end

    set_color af5fff
    printf "Gemini"
    set_color normal

    if test "$today_msgs" = 0 -o "$today_msgs" = ""
        set_color --dim
        printf ": no activity today"
        set_color normal
    else
        printf ": "
        set_color bryellow
        printf "%s" (__agent_stats_format tokens $today_tokens)
        set_color normal
        set_color --dim
        printf " tokens"
        set_color normal
        printf " | "
        set_color bryellow
        printf "%s" $today_msgs
        set_color normal
        printf " msg"
        if test -n "$today_model" -a "$today_model" != ""
            set_color --dim
            printf " · %s" $today_model
            set_color normal
        end
    end
    echo
end

function __agent_stats_gemini_detailed
    set -l gemini_dir $argv[1]
    set -l today $argv[2]

    set_color af5fff --bold
    printf "Gemini"
    set_color normal
    echo

    set -l log_files $gemini_dir/*/logs.json
    set -l has_logs false
    if test -f $log_files[1] 2>/dev/null
        set has_logs true
    end

    set -l seven_days_ago (date -d "7 days ago" +%Y-%m-%d)

    # Get daily message/session data from logs.json
    set -l daily_data
    if test "$has_logs" = true
        set daily_data (cat $log_files 2>/dev/null | jq -s -r --arg since $seven_days_ago '
            add // [] |
            [.[] | select(.type == "user" and (.timestamp[:10] >= $since))] |
            group_by(.timestamp[:10]) |
            map({
                date: .[0].timestamp[:10],
                messages: length,
                sessions: ([.[].sessionId] | unique | length)
            }) |
            sort_by(.date) |
            .[] |
            "\(.date) \(.messages) \(.sessions)"
        ' 2>/dev/null)
    end

    # Get daily token data from chats/session-*.json
    set -l chat_files (find $gemini_dir -name 'session-*.json' 2>/dev/null)
    set -l daily_tokens
    if test -n "$chat_files"
        set daily_tokens (cat $chat_files 2>/dev/null | jq -s -r --arg since $seven_days_ago '
            [.[] | select(.startTime[:10] >= $since) |
                {date: .startTime[:10], tokens: [.messages[]? | select(.tokens) | .tokens.total // 0] | add // 0}
            ] |
            group_by(.date) |
            map({date: .[0].date, tokens: ([.[].tokens] | add // 0)}) |
            .[] |
            "\(.date) \(.tokens)"
        ' 2>/dev/null)
    end

    echo

    if test -z "$daily_data" -a -z "$daily_tokens"
        set_color --dim
        printf "  No recent activity (last 7 days)\n"
        set_color normal
    else
        # Collect all dates
        set -l all_dates
        for line in $daily_data
            set -l p (string split " " $line)
            set -a all_dates $p[1]
        end
        for line in $daily_tokens
            set -l p (string split " " $line)
            set -a all_dates $p[1]
        end

        if test -z "$all_dates"
            set_color --dim
            printf "  No recent activity (last 7 days)\n"
            set_color normal
        else
            set -l dates (printf '%s\n' $all_dates | sort -u)

            set_color --bold
            printf "  %-12s %8s %8s %10s\n" "Date" "Messages" "Sessions" "Tokens"
            set_color normal
            set_color --dim
            printf "  %-12s %8s %8s %10s\n" "────────────" "────────" "────────" "──────────"
            set_color normal

            set -l total_msgs 0
            set -l total_sess 0
            set -l total_tokens 0

            for d in $dates
                set -l msgs 0
                set -l sess 0
                set -l day_tokens 0

                for line in $daily_data
                    set -l p (string split " " $line)
                    if test "$p[1]" = "$d"
                        set msgs $p[2]
                        set sess $p[3]
                        break
                    end
                end

                for tline in $daily_tokens
                    set -l tp (string split " " $tline)
                    if test "$tp[1]" = "$d"
                        set day_tokens $tp[2]
                        break
                    end
                end

                if test "$d" = "$today"
                    set_color --bold
                end
                printf "  %-12s " $d
                set_color bryellow
                printf "%8s %8s %10s" $msgs $sess (__agent_stats_format tokens $day_tokens)
                set_color normal
                echo

                set total_msgs (math "$total_msgs + $msgs")
                set total_sess (math "$total_sess + $sess")
                set total_tokens (math "$total_tokens + $day_tokens")
            end

            set_color --dim
            printf "  %-12s %8s %8s %10s\n" "────────────" "────────" "────────" "──────────"
            set_color normal
            set_color --bold
            printf "  %-12s " "Total"
            set_color bryellow
            printf "%8s %8s %10s" $total_msgs $total_sess (__agent_stats_format tokens $total_tokens)
            set_color normal
            echo
        end
    end

    # Per-model usage (all time) — from session files
    if test -n "$chat_files"
        echo
        set_color --bold
        printf "Model Usage (all time)\n"
        set_color normal

        set -l model_data (cat $chat_files 2>/dev/null | jq -s -r '
            [.[] | .messages[] | select(.tokens and .model)] |
            group_by(.model) |
            map({
                model: .[0].model,
                input: ([.[].tokens.input // 0] | add),
                output: ([.[].tokens.output // 0] | add),
                cached: ([.[].tokens.cached // 0] | add),
                thoughts: ([.[].tokens.thoughts // 0] | add)
            }) | sort_by(.model) | .[] |
            "\(.model) \(.input) \(.output) \(.cached) \(.thoughts)"
        ' 2>/dev/null)

        for line in $model_data
            set -l p (string split " " $line)
            set -l model $p[1]
            set -l input $p[2]
            set -l output $p[3]
            set -l cached $p[4]
            set -l thoughts $p[5]

            printf "  "
            set_color af5fff
            printf "%-25s" $model
            set_color normal
            set_color --dim
            printf " in:"
            set_color normal
            set_color bryellow
            printf "%7s" (__agent_stats_format tokens $input)
            set_color normal
            set_color --dim
            printf " out:"
            set_color normal
            set_color bryellow
            printf "%7s" (__agent_stats_format tokens $output)
            set_color normal
            set_color --dim
            printf " cache:"
            set_color normal
            set_color bryellow
            printf "%7s" (__agent_stats_format tokens $cached)
            set_color normal
            if test "$thoughts" -gt 0 2>/dev/null
                set_color --dim
                printf " think:"
                set_color normal
                set_color bryellow
                printf "%7s" (__agent_stats_format tokens $thoughts)
                set_color normal
            end
            echo
        end
    end

    # All-time totals
    echo
    set -l all_msgs 0
    set -l all_sess 0
    if test "$has_logs" = true
        set -l all_stats (cat $log_files 2>/dev/null | jq -s -r '
            add // [] |
            [.[] | select(.type == "user")] |
            "\(length) \([.[].sessionId] | unique | length)"
        ' 2>/dev/null)
        if test -n "$all_stats"
            set -l ap (string split " " $all_stats)
            set all_msgs $ap[1]
            set all_sess $ap[2]
        end
    end
    set_color --dim
    printf "  All time: %s messages, %s sessions\n" (__agent_stats_format number $all_msgs) (__agent_stats_format number $all_sess)
    set_color normal
end
