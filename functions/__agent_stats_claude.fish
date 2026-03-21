function __agent_stats_claude --description "Claude Code data provider for agent-stats"
    set -l mode $argv[1]
    test -z "$mode"; and set mode compact

    set -l usage_file ~/.claude/plugins/claude-hud/.usage-cache.json

    switch $mode
        case prompt
            __agent_stats_claude_prompt $usage_file
        case compact
            __agent_stats_claude_compact $usage_file
        case detailed
            __agent_stats_claude_detailed $usage_file
        case cost
            __agent_stats_claude_cost $usage_file
    end
end

# --- Usage data helpers ---

function __agent_stats_claude_usage --description "Read usage data from cache or API"
    set -l usage_file $argv[1]

    # If HUD cache exists, return it immediately and refresh via API in background
    if test -f $usage_file
        set -l data (jq -r '
            (.lastGoodData // .data) |
            "\(.planName // "Unknown") \(.fiveHour // 0) \(.sevenDay // 0) \(.fiveHourResetAt // "") \(.sevenDayResetAt // "")"
        ' $usage_file 2>/dev/null)
        if test -n "$data"
            # Background API refresh to keep HUD cache fresh
            __agent_stats_claude_api_refresh $usage_file &
            disown 2>/dev/null
            echo $data
            return 0
        end
    end

    # No HUD cache: try live API synchronously (first-run cost, short timeout)
    set -l api_result (__agent_stats_claude_api_fetch 2)
    if test -n "$api_result"
        echo $api_result
        return 0
    end

    echo "Unknown 0 0"
    return 1
end

function __agent_stats_claude_api_fetch --description "Fetch usage from OAuth API"
    set -l timeout $argv[1]
    test -z "$timeout"; and set timeout 5

    set -l creds_file ~/.claude/.credentials.json
    test -f $creds_file; or return 1

    set -l token (jq -r '.claudeAiOauth.accessToken // empty' $creds_file 2>/dev/null)
    test -n "$token"; or return 1

    set -l sub_type (jq -r '.claudeAiOauth.subscriptionType // ""' $creds_file 2>/dev/null)
    set -l plan_name (string replace -r '.*max.*' 'Max' -- $sub_type | string replace -r '.*pro.*' 'Pro' | string replace -r '.*team.*' 'Team')
    test -z "$plan_name"; and set plan_name "Unknown"

    set -l api_data (curl -s --max-time $timeout \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if test $status -eq 0 -a -n "$api_data"
        set -l five_hour (echo $api_data | jq -r '.five_hour.utilization // 0' 2>/dev/null | xargs printf "%.0f" 2>/dev/null)
        set -l seven_day (echo $api_data | jq -r '.seven_day.utilization // 0' 2>/dev/null | xargs printf "%.0f" 2>/dev/null)
        set -l five_reset (echo $api_data | jq -r '.five_hour.resets_at // ""' 2>/dev/null)
        set -l seven_reset (echo $api_data | jq -r '.seven_day.resets_at // ""' 2>/dev/null)
        echo "$plan_name $five_hour $seven_day $five_reset $seven_reset"
        return 0
    end

    return 1
end

function __agent_stats_claude_api_refresh --description "Background refresh: fetch API and update HUD cache"
    set -l usage_file $argv[1]
    set -l result (__agent_stats_claude_api_fetch 5)
    if test -n "$result"
        set -l parts (string split " " $result)
        # Update HUD cache file so next read gets fresh data
        printf '{"planName":"%s","fiveHour":%s,"sevenDay":%s,"fiveHourResetAt":"%s","sevenDayResetAt":"%s"}' \
            $parts[1] $parts[2] $parts[3] $parts[4] $parts[5] >$usage_file 2>/dev/null
    end
end

# --- Output modes ---

function __agent_stats_claude_prompt
    set -l usage_file $argv[1]

    if test (__agent_stats_auth claude) = apikey
        # API key user: return today's token count + message count
        set -l jsonl_files (find ~/.claude/projects -name '*.jsonl' 2>/dev/null)
        if test -z "$jsonl_files"
            echo "0 0 apikey"
            return
        end
        set -l today (date +%Y-%m-%d)
        set -l result (grep -h '"type":"assistant"' $jsonl_files 2>/dev/null | grep '"usage"' | jq -s -r --arg today $today '
            [.[] | select(.timestamp[:10] == $today)] |
            group_by(.message.id) | map(last) |
            {
                tokens: ([.[].message.usage | (.input_tokens + .output_tokens + (.cache_read_input_tokens // 0))] | add // 0),
                msgs: length
            } | "\(.tokens) \(.msgs)"
        ' 2>/dev/null)
        if test -n "$result"
            echo "$result apikey"
        else
            echo "0 0 apikey"
        end
        return
    end

    set -l usage (__agent_stats_claude_usage $usage_file)
    set -l parts (string split " " $usage)
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]
    set -l plan_name $parts[1]

    echo "$five_hour $seven_day $plan_name"
end

function __agent_stats_claude_compact
    set -l usage_file $argv[1]

    if test (__agent_stats_auth claude) = apikey
        # API key user: show today's tokens, messages, and cost
        set -l today (date +%Y-%m-%d)
        set -l jsonl_files (find ~/.claude/projects -name '*.jsonl' 2>/dev/null)

        set -l today_tokens 0
        set -l today_msgs 0
        set -l today_cost 0

        if test -n "$jsonl_files"
            # Get per-model token data for today (for cost calculation)
            set -l model_data (grep -h '"type":"assistant"' $jsonl_files 2>/dev/null | grep '"usage"' | jq -s -r --arg today $today '
                [.[] | select(.timestamp[:10] == $today)] |
                group_by(.message.id) | map(last) |
                group_by(.message.model) |
                map({
                    model: .[0].message.model,
                    input: ([.[].message.usage.input_tokens] | add),
                    output: ([.[].message.usage.output_tokens] | add),
                    cache: ([.[].message.usage.cache_read_input_tokens // 0] | add)
                }) | .[] | "\(.model) \(.input) \(.output) \(.cache)"
            ' 2>/dev/null)

            for line in $model_data
                set -l p (string split " " $line)
                set -l model_name (string replace "claude-" "" -- $p[1] | string replace -- "-thinking" "")
                set today_tokens (math "$today_tokens + $p[2] + $p[3] + $p[4]")
                set -l cost (__agent_stats_cost claude $model_name $p[2] $p[3] $p[4])
                if test $status -eq 0 -a -n "$cost"
                    set today_cost (math "$today_cost + $cost")
                end
            end

            set today_msgs (grep -h '"type":"user"' $jsonl_files 2>/dev/null | jq -s -r --arg today $today '
                [.[] | select(.timestamp[:10] == $today)] | length
            ' 2>/dev/null)
            test -z "$today_msgs"; and set today_msgs 0
        end

        set_color brblue
        printf "Claude"
        set_color normal
        printf " ("
        set_color bryellow
        printf "API"
        set_color normal
        printf ") "
        set_color bryellow
        printf "%s" (__agent_stats_format tokens $today_tokens)
        set_color normal
        set_color --dim
        printf " tokens"
        set_color normal
        printf ", "
        set_color bryellow
        printf "%s" $today_msgs
        set_color normal
        printf " msgs"
        if test "$today_cost" != 0
            printf " "
            set_color brgreen
            printf "~%s" (__agent_stats_format cost $today_cost)
            set_color normal
        end
        echo
        return
    end

    set -l usage (__agent_stats_claude_usage $usage_file)
    set -l parts (string split " " $usage)
    set -l plan_name $parts[1]
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]
    set -l five_reset $parts[4]
    set -l seven_reset $parts[5]

    # Single line: Claude (Max) ░░░░░░░░░░ 3%/5h ░░░░░░░░░░ 0%/7d
    set_color brblue
    printf "Claude"
    set_color normal
    printf " ("
    set_color bryellow
    printf "%s" $plan_name
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

    set -l reset_str (__agent_stats_reset_fmt $five_reset)
    if test -n "$reset_str"
        set_color --dim
        printf " (%s)" $reset_str
        set_color normal
    end

    # Only show 7d if non-zero or if it's notable
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

function __agent_stats_claude_detailed
    set -l usage_file $argv[1]

    set -l usage (__agent_stats_claude_usage $usage_file)
    set -l parts (string split " " $usage)
    set -l plan_name $parts[1]
    set -l five_hour $parts[2]
    set -l seven_day $parts[3]
    set -l five_reset $parts[4]
    set -l seven_reset $parts[5]

    # Header
    set_color brblue --bold
    printf "Claude Code"
    set_color normal
    printf " ("
    set_color bryellow
    printf "%s" $plan_name
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

    set -l reset_str (__agent_stats_reset_fmt $five_reset)
    if test -n "$reset_str"
        set_color --dim
        printf " (resets in %s)" $reset_str
        set_color normal
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

    set -l reset_str (__agent_stats_reset_fmt $seven_reset)
    if test -n "$reset_str"
        set_color --dim
        printf " (resets in %s)" $reset_str
        set_color normal
    end
    echo

    # Historical section from JSONL conversation logs
    set -l jsonl_files (find ~/.claude/projects -name '*.jsonl' 2>/dev/null)
    if test -z "$jsonl_files"
        return
    end

    set -l seven_days_ago (date -v-7d +%Y-%m-%d 2>/dev/null; or date -d "7 days ago" +%Y-%m-%d)
    set -l today (date +%Y-%m-%d)

    # Daily activity table (7 days) — assistant tokens
    set -l daily_tokens (grep -h '"type":"assistant"' $jsonl_files 2>/dev/null | grep '"usage"' | jq -s -r --arg since $seven_days_ago '
        [.[] | select(.timestamp[:10] >= $since)] |
        group_by(.message.id) | map(last) |
        group_by(.timestamp[:10]) |
        map({
            date: .[0].timestamp[:10],
            tokens: ([.[].message.usage | (.input_tokens + .output_tokens + (.cache_read_input_tokens // 0))] | add)
        }) | sort_by(.date) | .[] | "\(.date) \(.tokens)"
    ' 2>/dev/null)

    # Daily activity — user messages and sessions
    set -l daily_users (grep -h '"type":"user"' $jsonl_files 2>/dev/null | jq -s -r --arg since $seven_days_ago '
        [.[] | select(.timestamp != null and .timestamp[:10] >= $since)] |
        group_by(.timestamp[:10]) |
        map({
            date: .[0].timestamp[:10],
            messages: length,
            sessions: ([.[].sessionId] | unique | length)
        }) | sort_by(.date) | .[] | "\(.date) \(.messages) \(.sessions)"
    ' 2>/dev/null)

    echo

    if test -z "$daily_tokens" -a -z "$daily_users"
        set_color --dim
        printf "  No activity in the last 7 days\n"
        set_color normal
    else
        set_color --bold
        printf "  %-12s %8s %8s %10s\n" "Date" "Messages" "Sessions" "Tokens"
        set_color normal
        set_color --dim
        printf "  %-12s %8s %8s %10s\n" "────────────" "────────" "────────" "──────────"
        set_color normal

        set -l total_msgs 0
        set -l total_sess 0
        set -l total_tokens 0

        # Collect all dates from both sources
        set -l all_dates
        for line in $daily_users
            set -l p (string split " " $line)
            set -a all_dates $p[1]
        end
        for line in $daily_tokens
            set -l p (string split " " $line)
            set -a all_dates $p[1]
        end
        set -l dates (printf '%s\n' $all_dates | sort -u)

        for d in $dates
            set -l msgs 0
            set -l sess 0
            set -l tokens 0

            for line in $daily_users
                set -l p (string split " " $line)
                if test "$p[1]" = "$d"
                    set msgs $p[2]
                    set sess $p[3]
                    break
                end
            end

            for line in $daily_tokens
                set -l p (string split " " $line)
                if test "$p[1]" = "$d"
                    set tokens $p[2]
                    break
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

    # Per-model usage (all time)
    echo
    set_color normal
    set_color --bold
    printf "Model Usage (all time)\n"
    set_color normal

    set -l model_data (grep -h '"type":"assistant"' $jsonl_files 2>/dev/null | grep '"usage"' | jq -s -r '
        [.[] | select(.message.model | strings | startswith("claude-"))] |
        group_by(.message.id) | map(last) |
        group_by(.message.model) |
        map({
            model: .[0].message.model,
            input: ([.[].message.usage.input_tokens] | add),
            output: ([.[].message.usage.output_tokens] | add),
            cache: ([.[].message.usage.cache_read_input_tokens // 0] | add)
        }) | sort_by(.model) | .[] |
        "\(.model) \(.input) \(.output) \(.cache)"
    ' 2>/dev/null)

    for line in $model_data
        set -l p (string split " " $line)
        set -l model_name (string replace "claude-" "" -- $p[1] | string replace -- "-thinking" "")
        set -l input $p[2]
        set -l output $p[3]
        set -l cache $p[4]

        printf "  "
        set_color brblue
        printf "%-20s" $model_name
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
        printf "%7s" (__agent_stats_format tokens $cache)
        set_color normal
        echo
    end

    # All-time totals
    echo
    set -l all_msgs (grep -ch '"type":"user"' $jsonl_files 2>/dev/null | awk '{s+=$1} END {print s+0}')
    test -z "$all_msgs"; and set all_msgs 0
    set -l all_sess (grep -h '"type":"user"' $jsonl_files 2>/dev/null | jq -r '.sessionId' 2>/dev/null | sort -u | wc -l | string trim)
    test -z "$all_sess"; and set all_sess 0
    set_color --dim
    printf "  All time: %s messages, %s sessions\n" (__agent_stats_format number $all_msgs) (__agent_stats_format number $all_sess)
    set_color normal
end

function __agent_stats_claude_cost
    set -l usage_file $argv[1]

    set -l jsonl_files (find ~/.claude/projects -name '*.jsonl' 2>/dev/null)
    if test -z "$jsonl_files"
        set_color --dim
        printf "  No Claude data found\n"
        set_color normal
        return
    end

    # Header
    set_color brblue --bold
    printf "Claude"
    set_color normal
    set_color --dim
    printf " (all time)\n"
    set_color normal

    # Per-model token data (same query as detailed mode)
    set -l model_data (grep -h '"type":"assistant"' $jsonl_files 2>/dev/null | grep '"usage"' | jq -s -r '
        [.[] | select(.message.model | strings | startswith("claude-"))] |
        group_by(.message.id) | map(last) |
        group_by(.message.model) |
        map({
            model: .[0].message.model,
            input: ([.[].message.usage.input_tokens] | add),
            output: ([.[].message.usage.output_tokens] | add),
            cache: ([.[].message.usage.cache_read_input_tokens // 0] | add)
        }) | sort_by(.model) | .[] |
        "\(.model) \(.input) \(.output) \(.cache)"
    ' 2>/dev/null)

    set -l total_cost 0

    for line in $model_data
        set -l p (string split " " $line)
        set -l model_name (string replace "claude-" "" -- $p[1] | string replace -- "-thinking" "")
        set -l input $p[2]
        set -l output $p[3]
        set -l cache $p[4]

        set -l cost (__agent_stats_cost claude $model_name $input $output $cache)
        set -l cost_str "—"
        if test $status -eq 0 -a -n "$cost"
            set total_cost (math "$total_cost + $cost")
            set cost_str (printf "~%s" (__agent_stats_format cost $cost))
        end

        printf "  "
        set_color brblue
        printf "%-20s" $model_name
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
        printf "%7s" (__agent_stats_format tokens $cache)
        set_color normal
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
    printf "%-20s" "Total"
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
