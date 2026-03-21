function __agent_stats_codex --description "Codex data provider for agent-stats"
    set -l mode $argv[1]
    test -z "$mode"; and set mode compact

    set -l sessions_dir ~/.codex/sessions
    set -l history_file ~/.codex/history.jsonl

    if not test -d $sessions_dir
        switch $mode
            case prompt
                echo "0 0"
            case compact
                set_color brgreen
                printf "Codex"
                set_color normal
                set_color --dim
                printf ": no session data"
                set_color normal
                echo
            case detailed cost
                set_color brgreen --bold
                printf "Codex"
                set_color normal
                set_color --dim
                printf " (~/.codex/sessions not found)"
                set_color normal
                echo
        end
        return
    end

    switch $mode
        case prompt
            __agent_stats_codex_prompt $sessions_dir $history_file
        case compact
            __agent_stats_codex_compact $sessions_dir $history_file
        case detailed
            __agent_stats_codex_detailed $sessions_dir $history_file
        case cost
            __agent_stats_codex_cost $sessions_dir
    end
end

# --- Rate limit extraction ---

function __agent_stats_codex_rate_limits --description "Get rate limits from most recent session"
    set -l sessions_dir $argv[1]

    # Find most recent session file
    set -l latest (begin; find $sessions_dir -name '*.jsonl' -exec stat -f '%m %N' {} + 2>/dev/null; or find $sessions_dir -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null; end | sort -n | tail -1 | cut -d' ' -f2-)
    if test -z "$latest"
        echo "Unknown 0 0"
        return 1
    end

    # Get last token_count event with rate_limits
    set -l rate_data (grep '"token_count"' $latest 2>/dev/null | tail -1 | jq -r '
        .payload.rate_limits //empty |
        "\(.plan_type // "Unknown") \(.primary.used_percent // 0) \(.secondary.used_percent // 0) \(.primary.resets_at // "") \(.secondary.resets_at // "")"
    ' 2>/dev/null)

    if test -n "$rate_data"
        echo $rate_data
        return 0
    end

    echo "Unknown 0 0"
    return 1
end

# --- Output modes ---

function __agent_stats_codex_prompt
    set -l sessions_dir $argv[1]
    set -l history_file $argv[2]

    set -l rate (__agent_stats_codex_rate_limits $sessions_dir)
    set -l parts (string split " " $rate)
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]

    # Round to integers
    set five_hour (printf "%.0f" $five_hour 2>/dev/null; or echo 0)
    set seven_day (printf "%.0f" $seven_day 2>/dev/null; or echo 0)

    echo "$five_hour $seven_day"
end

function __agent_stats_codex_compact
    set -l sessions_dir $argv[1]
    set -l history_file $argv[2]

    set -l rate (__agent_stats_codex_rate_limits $sessions_dir)
    set -l parts (string split " " $rate)
    set -l plan_type $parts[1]
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]
    set -l five_reset $parts[4]
    set -l seven_reset $parts[5]

    # Round to integers for display
    set five_hour (printf "%.0f" $five_hour 2>/dev/null; or echo 0)
    set seven_day (printf "%.0f" $seven_day 2>/dev/null; or echo 0)

    # Format plan type for display
    set -l plan_display (string upper -- (string sub -l 1 -- $plan_type))(string sub -s 2 -- $plan_type)

    set_color brgreen
    printf "Codex"
    set_color normal
    printf " ("
    set_color bryellow
    printf "%s" $plan_display
    set_color normal
    printf ") "

    __agent_stats_bar $five_hour
    printf " "
    __agent_stats_usage_color $five_hour
    printf "%s%%" $five_hour
    set_color normal
    set_color --dim
    printf "/5h"
    set_color normal

    if test -n "$five_reset" -a "$five_reset" != ""
        set -l reset_str (__agent_stats_reset_fmt $five_reset)
        if test -n "$reset_str"
            set_color --dim
            printf " (%s)" $reset_str
            set_color normal
        end
    end

    # Only show 7d if non-zero
    if test "$seven_day" -gt 0 2>/dev/null
        printf " "
        __agent_stats_bar $seven_day
        printf " "
        __agent_stats_usage_color $seven_day
        printf "%s%%" $seven_day
        set_color normal
        set_color --dim
        printf "/7d"
        set_color normal
    end

    echo
end

function __agent_stats_codex_detailed
    set -l sessions_dir $argv[1]
    set -l history_file $argv[2]
    set -l today (date +%Y-%m-%d)

    # --- Header + rate limits ---
    set -l rate (__agent_stats_codex_rate_limits $sessions_dir)
    set -l parts (string split " " $rate)
    set -l plan_type $parts[1]
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]
    set -l five_reset $parts[4]
    set -l seven_reset $parts[5]

    set five_hour (printf "%.0f" $five_hour 2>/dev/null; or echo 0)
    set seven_day (printf "%.0f" $seven_day 2>/dev/null; or echo 0)

    set -l plan_display (string upper -- (string sub -l 1 -- $plan_type))(string sub -s 2 -- $plan_type)

    set_color brgreen --bold
    printf "Codex"
    set_color normal
    printf " ("
    set_color bryellow
    printf "%s" $plan_display
    set_color normal
    printf ")"
    echo

    # 5-hour usage bar
    set_color --bold
    printf "  5h  "
    set_color normal
    __agent_stats_bar $five_hour
    printf " "
    __agent_stats_usage_color $five_hour
    printf "%s%%" $five_hour
    set_color normal

    if test -n "$five_reset" -a "$five_reset" != ""
        set -l reset_str (__agent_stats_reset_fmt $five_reset)
        if test -n "$reset_str"
            set_color --dim
            printf " (resets in %s)" $reset_str
            set_color normal
        end
    end
    echo

    # 7-day usage bar
    set_color --bold
    printf "  7d  "
    set_color normal
    __agent_stats_bar $seven_day
    printf " "
    __agent_stats_usage_color $seven_day
    printf "%s%%" $seven_day
    set_color normal

    if test -n "$seven_reset" -a "$seven_reset" != ""
        set -l reset_str (__agent_stats_reset_fmt $seven_reset)
        if test -n "$reset_str"
            set_color --dim
            printf " (resets in %s)" $reset_str
            set_color normal
        end
    end
    echo

    # --- Daily breakdown (7 days) ---

    # Daily messages/sessions from history.jsonl
    set -l daily_hist
    if test -f $history_file
        set -l seven_days_ago_epoch (date -v-7d +%s 2>/dev/null; or date -d "7 days ago" +%s)
        set daily_hist (tail -2000 $history_file | jq -s -r --argjson since $seven_days_ago_epoch '
            [.[] | select(.ts >= $since)]
            | group_by(.ts | strftime("%Y-%m-%d"))
            | map({
                date: .[0].ts | strftime("%Y-%m-%d"),
                messages: length,
                sessions: ([.[].session_id] | unique | length)
            })
            | sort_by(.date)
            | .[]
            | "\(.date) \(.messages) \(.sessions)"
        ' 2>/dev/null)
    end

    # Daily tokens from session files (7 days)
    set -l daily_tokens
    set -l recent_files (find $sessions_dir -name '*.jsonl' -newermt "7 days ago" -exec grep -l '"token_count"' {} + 2>/dev/null)
    for f in $recent_files
        # Extract date from path: .../2026/03/21/... → 2026-03-21
        set -l date_match (string match -r '(\d{4})/(\d{2})/(\d{2})' $f)
        if test (count $date_match) -ge 4
            set -l date_str "$date_match[2]-$date_match[3]-$date_match[4]"
            set -l tok_line (grep '"token_count"' $f | tail -1 | jq -r '
                .payload.info.total_token_usage // empty |
                "\(.input_tokens // 0) \(.output_tokens // 0) \(.cached_input_tokens // 0) \(.reasoning_output_tokens // 0)"
            ' 2>/dev/null)
            if test -n "$tok_line"
                set -a daily_tokens "$date_str $tok_line"
            end
        end
    end

    echo

    # Merge daily data: collect all dates, combine messages/sessions/tokens
    set -l all_dates
    for line in $daily_hist
        set -l p (string split " " $line)
        set -a all_dates $p[1]
    end
    for line in $daily_tokens
        set -l p (string split " " $line)
        set -a all_dates $p[1]
    end

    if test -z "$all_dates"
        set_color --dim
        printf "  No activity in the last 7 days\n"
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
            set -l tokens 0

            for line in $daily_hist
                set -l p (string split " " $line)
                if test "$p[1]" = "$d"
                    set msgs $p[2]
                    set sess $p[3]
                    break
                end
            end

            # Sum tokens across all session files for this date
            for line in $daily_tokens
                set -l p (string split " " $line)
                if test "$p[1]" = "$d"
                    set -l line_total (math "$p[2] + $p[3]")
                    set tokens (math "$tokens + $line_total")
                end
            end

            if test "$d" = "$today"
                set_color --bold
            end
            printf "  %-12s " $d
            set_color bryellow
            printf "%8s %8s %10s" $msgs $sess (__agent_stats_format tokens $tokens)
            set_color normal
            echo

            set total_msgs (math "$total_msgs + $msgs")
            set total_sess (math "$total_sess + $sess")
            set total_tokens (math "$total_tokens + $tokens")
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

    # --- Model usage (all time, by turn count) ---
    echo
    set_color --bold
    printf "Model Usage (all time)\n"
    set_color normal

    set -l model_turns (find $sessions_dir -name '*.jsonl' -exec grep -h '"turn_context"' {} + 2>/dev/null | jq -r '.payload.model' 2>/dev/null | sort | uniq -c | sort -rn)

    for line in $model_turns
        # uniq -c output: "  12435 gpt-5.1-codex-max"
        set -l trimmed (string trim $line)
        set -l p (string split -m 1 " " $trimmed)
        set -l count $p[1]
        set -l model $p[2]
        if test -n "$model" -a -n "$count"
            printf "  "
            set_color brgreen
            printf "%-25s" $model
            set_color normal
            set_color bryellow
            printf "%s" (__agent_stats_format number $count)
            set_color normal
            set_color --dim
            if test "$count" = 1
                printf " turn"
            else
                printf " turns"
            end
            set_color normal
            echo
        end
    end

    # --- All-time totals ---
    echo
    set -l all_msgs 0
    set -l all_sess 0
    if test -f $history_file
        set all_msgs (wc -l < $history_file 2>/dev/null; or echo 0)
        set all_sess (jq -r '.session_id' $history_file 2>/dev/null | sort -u | wc -l; or echo 0)
    end
    set -l all_session_files (find $sessions_dir -name '*.jsonl' 2>/dev/null | wc -l)

    set_color --dim
    printf "  All time: %s messages, %s sessions\n" (__agent_stats_format number $all_msgs) (__agent_stats_format number $all_session_files)
    set_color normal
end

function __agent_stats_codex_cost
    set -l sessions_dir $argv[1]

    # Header
    set_color brgreen --bold
    printf "Codex"
    set_color normal
    set_color --dim
    printf " (7 day)\n"
    set_color normal

    # Extract model + tokens from recent session files
    set -l session_data
    set -l recent_files (find $sessions_dir -name '*.jsonl' -newermt "7 days ago" -exec grep -l '"token_count"' {} + 2>/dev/null)
    for f in $recent_files
        set -l tok_line (grep '"token_count"' $f | tail -1 | jq -r '
            .payload.info.total_token_usage // empty |
            "\(.input_tokens // 0) \(.output_tokens // 0) \(.cached_input_tokens // 0) \(.reasoning_output_tokens // 0)"
        ' 2>/dev/null)
        if test -n "$tok_line"
            set -l session_model (grep '"turn_context"' $f 2>/dev/null | tail -1 | jq -r '.payload.model // ""' 2>/dev/null)
            test -z "$session_model"; and set session_model unknown
            set -a session_data "$session_model $tok_line"
        end
    end

    if test -z "$session_data"
        set_color --dim
        printf "  No session data in the last 7 days\n"
        set_color normal
        return
    end

    # Group by model: aggregate input/output/cached/reasoning per model
    set -l models
    set -l model_in
    set -l model_out
    set -l model_cache
    set -l model_think

    for line in $session_data
        set -l p (string split " " $line)
        set -l m $p[1]
        set -l idx 0

        # Find existing model index
        for i in (seq (count $models))
            if test "$models[$i]" = "$m"
                set idx $i
                break
            end
        end

        if test $idx -eq 0
            set -a models $m
            set -a model_in $p[2]
            set -a model_out $p[3]
            set -a model_cache $p[4]
            set -a model_think $p[5]
        else
            set model_in[$idx] (math "$model_in[$idx] + $p[2]")
            set model_out[$idx] (math "$model_out[$idx] + $p[3]")
            set model_cache[$idx] (math "$model_cache[$idx] + $p[4]")
            set model_think[$idx] (math "$model_think[$idx] + $p[5]")
        end
    end

    set -l total_cost 0

    for i in (seq (count $models))
        set -l m $models[$i]
        set -l input $model_in[$i]
        set -l output $model_out[$i]
        set -l cached $model_cache[$i]
        set -l think $model_think[$i]

        set -l cost (__agent_stats_cost codex $m $input $output $cached $think)
        set -l cost_str "—"
        if test $status -eq 0 -a -n "$cost"
            set total_cost (math "$total_cost + $cost")
            set cost_str (printf "~%s" (__agent_stats_format cost $cost))
        end

        printf "  "
        set_color brgreen
        printf "%-25s" $m
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
        if test "$think" -gt 0 2>/dev/null
            set_color --dim
            printf " think:"
            set_color normal
            set_color bryellow
            printf "%7s" (__agent_stats_format tokens $think)
            set_color normal
        end
        printf "  "
        set_color brgreen
        printf "%9s" $cost_str
        set_color normal
        echo
    end

    set_color --dim
    printf "  ──────────────────────────────────────────────────────────────────\n"
    set_color normal
    printf "  "
    set_color --bold
    printf "%-25s" "Total"
    set_color normal
    printf "%33s  "
    set_color brgreen --bold
    if test "$total_cost" != 0
        printf "%9s" (printf "~%s" (__agent_stats_format cost $total_cost))
    else
        printf "%9s" "—"
    end
    set_color normal
    echo
end
