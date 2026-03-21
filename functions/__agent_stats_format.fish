function __agent_stats_format --description "Formatting utilities for agent-stats"
    switch $argv[1]
        case tokens
            __agent_stats_format_tokens $argv[2]
        case number
            __agent_stats_format_number $argv[2]
        case cost
            __agent_stats_format_cost $argv[2]
    end
end

function __agent_stats_format_tokens --description "Format token count to human-readable (2.1M, 45.3K, 892)"
    set -l n $argv[1]
    if test -z "$n"; or test "$n" = null
        echo "0"
        return
    end

    if test $n -ge 1000000
        set -l major (math "floor($n / 1000000)")
        set -l minor (math "floor(($n % 1000000) / 100000)")
        if test $minor -gt 0
            echo {$major}.{$minor}M
        else
            echo {$major}M
        end
    else if test $n -ge 1000
        set -l major (math "floor($n / 1000)")
        set -l minor (math "floor(($n % 1000) / 100)")
        if test $minor -gt 0
            echo {$major}.{$minor}K
        else
            echo {$major}K
        end
    else
        echo $n
    end
end

function __agent_stats_format_number --description "Add comma separators to numbers"
    set -l n $argv[1]
    if test -z "$n"; or test "$n" = null
        echo "0"
        return
    end
    printf "%'d\n" $n 2>/dev/null; or echo $n
end

function __agent_stats_format_cost --description "Format cost with currency symbol ($4.27, <$0.01, $847)"
    set -l cost $argv[1]
    if test -z "$cost" -o "$cost" = "0"
        return
    end

    # Map currency code to symbol
    set -l symbol
    switch "$agent_stats_cost_currency"
        case USD
            set symbol '$'
        case EUR
            set symbol '€'
        case GBP
            set symbol '£'
        case JPY
            set symbol '¥'
        case '*'
            set symbol "$agent_stats_cost_currency "
    end

    # Check if cost rounds to zero at two decimals
    set -l rounded (printf "%.2f" $cost)
    if test "$rounded" = "0.00" -a "$cost" != "0"
        printf "<%s0.01" $symbol
        return
    end

    if test (printf "%.0f" $cost) -ge 100
        printf "%s%s" $symbol (printf "%.0f" $cost)
    else
        printf "%s%s" $symbol (printf "%.2f" $cost)
    end
end
